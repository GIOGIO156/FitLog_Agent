create table if not exists public.cloud_profiles (
  account_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  age integer not null default 25,
  height_cm numeric not null default 170,
  weight_kg numeric not null default 65,
  body_fat_percent numeric,
  waist_cm numeric,
  sex_for_formula text not null default 'prefer_not_to_say',
  diet_goal_phase text not null default 'cutting',
  diet_calculation_mode text not null default 'energy_ratio',
  daily_energy_goal_kcal integer not null default 300,
  protein_ratio_percent integer not null default 30,
  carbs_ratio_percent integer not null default 40,
  fat_ratio_percent integer not null default 30,
  training_frequency_per_week integer not null default 3,
  diet_plan_strategy text not null default 'none',
  carb_cycle_pattern_json jsonb,
  carb_cycle_high_multiplier numeric not null default 1.15,
  carb_cycle_medium_multiplier numeric not null default 1.0,
  carb_cycle_low_multiplier numeric not null default 0.85,
  carb_taper_review_period_days integer not null default 14,
  carb_taper_target_loss_pct_per_week numeric not null default 0.5,
  carb_taper_step_g numeric not null default 20,
  carb_taper_current_delta_g numeric not null default 0,
  macro_self_check_period_days integer not null default 28,
  macro_self_check_enabled boolean not null default true,
  profile_version integer not null default 1,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint cloud_profiles_phase_check check (diet_goal_phase in ('cutting', 'bulking')),
  constraint cloud_profiles_mode_check check (diet_calculation_mode in ('energy_ratio', 'gram_per_kg')),
  constraint cloud_profiles_strategy_check check (diet_plan_strategy in ('none', 'carb_cycling', 'carb_tapering')),
  constraint cloud_profiles_sex_check check (sex_for_formula in ('male', 'female', 'prefer_not_to_say')),
  constraint cloud_profiles_ratio_check check (
    protein_ratio_percent >= 0
    and carbs_ratio_percent >= 0
    and fat_ratio_percent >= 0
    and protein_ratio_percent + carbs_ratio_percent + fat_ratio_percent = 100
  )
);

create table if not exists public.subscriptions (
  account_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'inactive',
  plan_id text,
  provider text not null default 'internal_dev_entitlement',
  current_period_end timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint subscriptions_status_check check (
    status in ('active', 'inactive', 'trialing', 'past_due', 'canceled')
  )
);

alter table public.cloud_profiles enable row level security;
alter table public.subscriptions enable row level security;

drop policy if exists "cloud_profiles_select_own" on public.cloud_profiles;
create policy "cloud_profiles_select_own"
on public.cloud_profiles
for select
using (auth.uid() = account_id);

drop policy if exists "cloud_profiles_insert_own" on public.cloud_profiles;
create policy "cloud_profiles_insert_own"
on public.cloud_profiles
for insert
with check (auth.uid() = account_id);

drop policy if exists "cloud_profiles_update_own" on public.cloud_profiles;
create policy "cloud_profiles_update_own"
on public.cloud_profiles
for update
using (auth.uid() = account_id)
with check (auth.uid() = account_id);

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own"
on public.subscriptions
for select
using (auth.uid() = account_id);

-- Entitlements are maintained by seed/service-role tooling only.
drop policy if exists "subscriptions_no_client_insert" on public.subscriptions;
create policy "subscriptions_no_client_insert"
on public.subscriptions
for insert
with check (false);

drop policy if exists "subscriptions_no_client_update" on public.subscriptions;
create policy "subscriptions_no_client_update"
on public.subscriptions
for update
using (false)
with check (false);
