-- Drop old table and trigger if they exist
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.profiles;

-- Profiles table (name/role nullable — filled in by onboarding screen)
create table profiles (
  id uuid references auth.users on delete cascade not null primary key,
  name text,
  role text check (role in ('caregiver', 'older_adult')),
  updated_at timestamptz default now()
);

-- RLS
alter table profiles enable row level security;

create policy "Users can view own profile." on profiles
  for select using ((select auth.uid()) = id);

create policy "Users can insert own profile." on profiles
  for insert with check ((select auth.uid()) = id);

create policy "Users can update own profile." on profiles
  for update using ((select auth.uid()) = id);

-- Auto-create a profile row on signup (name/role filled in by onboarding)
create function public.handle_new_user()
returns trigger
set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Keep updated_at current on every edit
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on profiles
  for each row execute function update_updated_at();
