-- Email OTP codes used during signup verification.
-- Written/read by the Edge Functions (send-email-otp, verify-email-otp) using
-- the service role. RLS is ON with NO policies so the client has zero access.
create table if not exists public.email_otps (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  code_hash   text not null,
  expires_at  timestamptz not null,
  consumed_at timestamptz,
  attempts    int not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists email_otps_email_idx
  on public.email_otps (email, created_at desc);

alter table public.email_otps enable row level security;
-- Intentionally no policies: only the service role (Edge Functions) may access.
