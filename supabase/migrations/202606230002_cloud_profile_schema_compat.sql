alter table public.cloud_profiles
  add column if not exists display_name text,
  add column if not exists age integer not null default 25,
  add column if not exists height_cm numeric not null default 170,
  add column if not exists weight_kg numeric not null default 65,
  add column if not exists body_fat_percent numeric,
  add column if not exists waist_cm numeric,
  add column if not exists sex_for_formula text not null default 'prefer_not_to_say',
  add column if not exists diet_goal_phase text not null default 'cutting',
  add column if not exists diet_calculation_mode text not null default 'energy_ratio',
  add column if not exists daily_energy_goal_kcal integer not null default 300,
  add column if not exists protein_ratio_percent integer not null default 30,
  add column if not exists carbs_ratio_percent integer not null default 40,
  add column if not exists fat_ratio_percent integer not null default 30,
  add column if not exists training_frequency_per_week integer not null default 3,
  add column if not exists diet_plan_strategy text not null default 'none',
  add column if not exists carb_cycle_pattern_json jsonb,
  add column if not exists carb_cycle_high_multiplier numeric not null default 1.15,
  add column if not exists carb_cycle_medium_multiplier numeric not null default 1.0,
  add column if not exists carb_cycle_low_multiplier numeric not null default 0.85,
  add column if not exists carb_taper_review_period_days integer not null default 14,
  add column if not exists carb_taper_target_loss_pct_per_week numeric not null default 0.5,
  add column if not exists carb_taper_step_g numeric not null default 20,
  add column if not exists carb_taper_current_delta_g numeric not null default 0,
  add column if not exists macro_self_check_period_days integer not null default 28,
  add column if not exists macro_self_check_enabled boolean not null default true,
  add column if not exists profile_version integer not null default 1,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.cloud_profiles
  drop constraint if exists cloud_profiles_phase_check,
  drop constraint if exists cloud_profiles_mode_check,
  drop constraint if exists cloud_profiles_strategy_check,
  drop constraint if exists cloud_profiles_sex_check,
  drop constraint if exists cloud_profiles_ratio_check;

alter table public.cloud_profiles
  add constraint cloud_profiles_phase_check
    check (diet_goal_phase in ('cutting', 'bulking')),
  add constraint cloud_profiles_mode_check
    check (diet_calculation_mode in ('energy_ratio', 'gram_per_kg')),
  add constraint cloud_profiles_strategy_check
    check (diet_plan_strategy in ('none', 'carb_cycling', 'carb_tapering')),
  add constraint cloud_profiles_sex_check
    check (sex_for_formula in ('male', 'female', 'prefer_not_to_say')),
  add constraint cloud_profiles_ratio_check
    check (
      protein_ratio_percent >= 0
      and carbs_ratio_percent >= 0
      and fat_ratio_percent >= 0
      and protein_ratio_percent + carbs_ratio_percent + fat_ratio_percent = 100
    );

alter table public.cloud_profiles enable row level security;

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
