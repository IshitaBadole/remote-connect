create table prints (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  user_id uuid references auth.users(id) on delete cascade not null,
  template_id text not null,
  to_name text,
  from_name text,
  image_url text
);

alter table prints enable row level security;

-- Users can only read/write their own prints
create policy "owner access" on prints
  for all using (auth.uid() = user_id);

-- Storage: allow authenticated users to upload to the prints bucket
create policy "authenticated upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'prints');