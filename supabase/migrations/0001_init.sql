-- PaisaTrack — initial schema
-- Postgres / Supabase. Every table is owned by a user and protected by
-- row-level security so a client (using the anon key) can only ever read or
-- write its own rows.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type txn_type as enum ('debit', 'credit');
create type txn_source as enum ('sms', 'manual');

-- ---------------------------------------------------------------------------
-- Categories
-- A fixed catalogue of built-in categories is shipped in the app, but we also
-- allow user-defined categories here for future extensibility.
-- ---------------------------------------------------------------------------
create table if not exists public.categories (
  id          text primary key,
  user_id     uuid references auth.users (id) on delete cascade,
  name        text not null,
  icon        text,
  color       text,
  is_builtin  boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Accounts (bank / wallet the money moves through)
-- ---------------------------------------------------------------------------
create table if not exists public.accounts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  last4       text,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Transactions (the core table)
-- ---------------------------------------------------------------------------
create table if not exists public.transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  title        text not null,
  amount       numeric(14, 2) not null check (amount > 0),
  type         txn_type not null,
  category_id  text not null,
  date         timestamptz not null default now(),
  source       txn_source not null default 'manual',
  account      text,
  raw_sms      text,
  note         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists transactions_user_date_idx
  on public.transactions (user_id, date desc);

-- Prevent importing the same bank SMS twice per user.
create unique index if not exists transactions_user_rawsms_uidx
  on public.transactions (user_id, raw_sms)
  where raw_sms is not null;

-- ---------------------------------------------------------------------------
-- Budgets (per-category monthly limits, powers the alerts feature)
-- ---------------------------------------------------------------------------
create table if not exists public.budgets (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  category_id  text not null,
  monthly_limit numeric(14, 2) not null check (monthly_limit >= 0),
  created_at   timestamptz not null default now(),
  unique (user_id, category_id)
);

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger transactions_set_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table public.categories   enable row level security;
alter table public.accounts     enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets      enable row level security;

-- Transactions: owner-only full access.
create policy "transactions_select_own" on public.transactions
  for select using (auth.uid() = user_id);
create policy "transactions_insert_own" on public.transactions
  for insert with check (auth.uid() = user_id);
create policy "transactions_update_own" on public.transactions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "transactions_delete_own" on public.transactions
  for delete using (auth.uid() = user_id);

-- Accounts: owner-only full access.
create policy "accounts_all_own" on public.accounts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Budgets: owner-only full access.
create policy "budgets_all_own" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Categories: a row is readable if it's a built-in (user_id is null) OR owned
-- by the caller; writes are restricted to the caller's own rows.
create policy "categories_select_visible" on public.categories
  for select using (user_id is null or auth.uid() = user_id);
create policy "categories_insert_own" on public.categories
  for insert with check (auth.uid() = user_id);
create policy "categories_update_own" on public.categories
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "categories_delete_own" on public.categories
  for delete using (auth.uid() = user_id);
