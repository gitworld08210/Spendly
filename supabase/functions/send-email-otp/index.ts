// Spendly — send-email-otp
//
// Generates a 6-digit OTP, stores only its hash in `email_otps`, and emails the
// code to the user via Azure Communication Services (ACS) Email.
//
// Called during SIGNUP to verify the user owns the email address. The actual
// auth user is NOT created here — that happens in verify-email-otp once the
// code is confirmed (so no half-created/unverified accounts exist).
//
// Secrets (set via `supabase secrets set` or the dashboard):
//   ACS_CONNECTION_STRING   e.g. endpoint=https://<res>.communication.azure.com/;accesskey=<key>
//   ACS_SENDER_ADDRESS      e.g. DoNotReply@<verified-domain>
//   SUPABASE_URL            (auto-provided)
//   SUPABASE_SERVICE_ROLE_KEY (auto-provided)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { sendAcsEmail } from "../_shared/acs_email.ts";

const OTP_TTL_MINUTES = 10;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sixDigitCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const { email: rawEmail } = await req.json().catch(() => ({}));
    const email = typeof rawEmail === "string" ? rawEmail.trim().toLowerCase() : "";
    if (!isValidEmail(email)) {
      return json({ error: "A valid email is required." }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // If a confirmed user already exists, tell the client to log in instead.
    const { data: existing } = await supabase.auth.admin.listUsers();
    const already = existing?.users?.some(
      (u) => u.email?.toLowerCase() === email && u.email_confirmed_at,
    );
    if (already) {
      return json(
        { error: "An account with this email already exists. Please log in." },
        409,
      );
    }

    const code = sixDigitCode();
    const codeHash = await sha256Hex(`${email}:${code}`);
    const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60_000);

    const { error: insertErr } = await supabase.from("email_otps").insert({
      email,
      code_hash: codeHash,
      expires_at: expiresAt.toISOString(),
    });
    if (insertErr) {
      console.error("email_otps insert failed:", insertErr);
      return json({ error: "Could not create verification code." }, 500);
    }

    await sendAcsEmail({
      to: email,
      subject: "Your Spendly verification code",
      plainText:
        `Your Spendly verification code is ${code}. ` +
        `It expires in ${OTP_TTL_MINUTES} minutes. ` +
        `If you didn't request this, you can ignore this email.`,
      html: otpEmailHtml(code, OTP_TTL_MINUTES),
    });

    return json({ ok: true, message: "Verification code sent." });
  } catch (err) {
    console.error("send-email-otp error:", err);
    return json({ error: "Unexpected error sending the code." }, 500);
  }
});

function otpEmailHtml(code: string, ttl: number): string {
  return `<!doctype html>
<html>
  <body style="margin:0;background:#f4f4f6;font-family:Segoe UI,Roboto,Arial,sans-serif;">
    <div style="max-width:480px;margin:32px auto;background:#ffffff;border-radius:20px;overflow:hidden;">
      <div style="background:linear-gradient(90deg,#FF8A34,#F5432C);padding:24px 28px;">
        <h1 style="margin:0;color:#fff;font-size:22px;">Spendly</h1>
        <p style="margin:4px 0 0;color:#ffe9dd;font-size:13px;">Spend smarter. Live better.</p>
      </div>
      <div style="padding:28px;">
        <p style="color:#16171a;font-size:15px;margin:0 0 16px;">Use this code to verify your email:</p>
        <div style="font-size:34px;font-weight:800;letter-spacing:8px;color:#16171a;text-align:center;padding:16px 0;">${code}</div>
        <p style="color:#8a8d96;font-size:13px;margin:16px 0 0;">This code expires in ${ttl} minutes. If you didn't request it, ignore this email.</p>
      </div>
    </div>
  </body>
</html>`;
}
