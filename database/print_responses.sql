create table print_responses (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  user_id uuid references auth.users(id) on delete cascade not null,
  original_print_id uuid references prints(id) on delete set null,
  image_url text not null
);
