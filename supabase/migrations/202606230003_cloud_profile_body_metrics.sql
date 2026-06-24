alter table public.cloud_profiles
  add column if not exists body_fat_percent numeric,
  add column if not exists waist_cm numeric;
