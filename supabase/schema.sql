-- Ghiza-o-Sehat — Step 21 Supabase Schema (Auth + Profiles + Foods + Meal Logs)
-- Applied to Supabase project: ctidcjhbjrzqibcynbqo

-- 1. PROFILES TABLE (linked 1-to-1 with Supabase auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 120),
  preferred_language text not null default 'en' check (preferred_language in ('en', 'ur', 'roman_ur')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view their own profile"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "Users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Trigger function to automatically create a profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  v_lang text;
begin
  v_lang := coalesce(nullif(trim(new.raw_user_meta_data ->> 'preferred_language'), ''), 'en');
  if v_lang not in ('en', 'ur', 'roman_ur') then
    v_lang := 'en';
  end if;

  insert into public.profiles (id, display_name, preferred_language)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1)),
    v_lang
  )
  on conflict (id) do update
    set display_name = excluded.display_name,
        preferred_language = excluded.preferred_language;
  return new;
end;
$$;

-- Lock down SECURITY DEFINER trigger function from direct RPC invocation
revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. FOODS TABLE (curated nutrition records; seeded with FAO Pakistan Chapati record)
create table if not exists public.foods (
  id uuid primary key default gen_random_uuid(),
  canonical_name text unique not null,
  visual_class text not null,
  display_name_en text not null,
  display_name_ur text not null,
  aliases jsonb not null default '[]'::jsonb,
  kcal_per_100g numeric not null check (kcal_per_100g > 0),
  source_name text not null,
  source_reference text not null,
  notes jsonb not null default '[]'::jsonb,
  active boolean not null default true
);

alter table public.foods enable row level security;

create policy "Authenticated users can read active foods"
  on public.foods for select
  to authenticated
  using (active = true);

insert into public.foods (
  canonical_name,
  visual_class,
  display_name_en,
  display_name_ur,
  aliases,
  kcal_per_100g,
  source_name,
  source_reference,
  notes,
  active
)
values (
  'chapati',
  'chapati',
  'Wheat Bread (Chapati)',
  'چپاتی',
  '["roti", "phulka", "wheat chapati"]'::jsonb,
  259,
  'Food Composition Table for Pakistan (FAO)',
  'Section A: Cereal and cereal products, Row 19 (Wheat Bread / Chapati), printed page 8 / PDF page 15 — 259 kcal per 100 g edible portion',
  '["Applies to plain cooked wheat chapati without added ghee, butter, or oil.", "Calculated deterministically from user-supplied cooked weight in grams."]'::jsonb,
  true
)
on conflict (canonical_name) do nothing;

-- 3. MEAL LOGS TABLE (grams-based contract per Master Handoff)
create table if not exists public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  predicted_class text not null,
  prediction_confidence numeric not null,
  top3 jsonb not null default '[]'::jsonb,
  confirmed_food_id uuid references public.foods (id) on delete set null,
  confirmed_food text not null,
  portion_grams numeric not null check (portion_grams > 0),
  calories numeric not null check (calories >= 0),
  preparation_context jsonb not null default '{}'::jsonb,
  image_path text
);

-- Index foreign keys and RLS lookup columns
create index if not exists meal_logs_user_id_created_at_idx
  on public.meal_logs (user_id, created_at desc);

create index if not exists meal_logs_confirmed_food_id_idx
  on public.meal_logs (confirmed_food_id);

alter table public.meal_logs enable row level security;

create policy "Users can view their own meal logs"
  on public.meal_logs for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert their own meal logs"
  on public.meal_logs for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own meal logs"
  on public.meal_logs for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own meal logs"
  on public.meal_logs for delete
  to authenticated
  using ((select auth.uid()) = user_id);
