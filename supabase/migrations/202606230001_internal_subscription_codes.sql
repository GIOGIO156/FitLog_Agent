create extension if not exists pgcrypto;

create table if not exists public.internal_subscription_codes (
  id uuid primary key default gen_random_uuid(),
  label text not null unique,
  code_hash text not null,
  status text not null default 'active',
  plan_id text not null default 'fitlog_ai_dev',
  duration_days integer not null default 30,
  max_redemptions integer not null default 1,
  redeemed_count integer not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint internal_subscription_codes_status_check
    check (status in ('active', 'revoked')),
  constraint internal_subscription_codes_count_check
    check (max_redemptions > 0 and redeemed_count >= 0)
);

create table if not exists public.internal_subscription_redemptions (
  id uuid primary key default gen_random_uuid(),
  code_id uuid not null references public.internal_subscription_codes(id) on delete cascade,
  account_id uuid not null references auth.users(id) on delete cascade,
  redeemed_at timestamptz not null default timezone('utc', now()),
  unique (code_id, account_id)
);

alter table public.internal_subscription_codes enable row level security;
alter table public.internal_subscription_redemptions enable row level security;

create or replace function public.redeem_internal_subscription_code(input_code text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_account_id uuid := auth.uid();
  v_code public.internal_subscription_codes%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_period_end timestamptz;
begin
  if v_account_id is null then
    return jsonb_build_object('ok', false, 'code', 'auth_required');
  end if;

  select *
  into v_code
  from public.internal_subscription_codes
  where status = 'active'
    and (expires_at is null or expires_at > v_now)
    and code_hash = crypt(trim(input_code), code_hash)
  order by created_at asc
  limit 1
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'invalid_or_expired_code');
  end if;

  if exists (
    select 1
    from public.internal_subscription_redemptions
    where code_id = v_code.id
      and account_id = v_account_id
  ) then
    return jsonb_build_object('ok', false, 'code', 'code_already_redeemed');
  end if;

  if v_code.redeemed_count >= v_code.max_redemptions then
    return jsonb_build_object('ok', false, 'code', 'invalid_or_expired_code');
  end if;

  insert into public.internal_subscription_redemptions (code_id, account_id)
  values (v_code.id, v_account_id);

  update public.internal_subscription_codes
  set
    redeemed_count = redeemed_count + 1,
    updated_at = v_now
  where id = v_code.id;

  v_period_end := v_now + make_interval(days => v_code.duration_days);

  insert into public.subscriptions (
    account_id,
    status,
    plan_id,
    provider,
    current_period_end,
    updated_at
  )
  values (
    v_account_id,
    'active',
    v_code.plan_id,
    'internal_redeem_code',
    v_period_end,
    v_now
  )
  on conflict (account_id) do update set
    status = excluded.status,
    plan_id = excluded.plan_id,
    provider = excluded.provider,
    current_period_end = excluded.current_period_end,
    updated_at = excluded.updated_at;

  return jsonb_build_object(
    'ok', true,
    'code', 'redeemed',
    'plan_id', v_code.plan_id,
    'current_period_end', v_period_end
  );
end;
$$;

revoke all on function public.redeem_internal_subscription_code(text) from public;
grant execute on function public.redeem_internal_subscription_code(text) to authenticated;
