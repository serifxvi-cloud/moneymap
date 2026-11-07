-- MoneyMap per-user cloud storage
-- Run once in the Supabase SQL Editor for project dmapwfwltcfsmqgrvrxq.
create table if not exists public.moneymap_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.moneymap_profiles enable row level security;

drop policy if exists "Users can read their own MoneyMap data" on public.moneymap_profiles;
create policy "Users can read their own MoneyMap data"
  on public.moneymap_profiles for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own MoneyMap data" on public.moneymap_profiles;
create policy "Users can create their own MoneyMap data"
  on public.moneymap_profiles for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own MoneyMap data" on public.moneymap_profiles;
create policy "Users can update their own MoneyMap data"
  on public.moneymap_profiles for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update on public.moneymap_profiles to authenticated;
