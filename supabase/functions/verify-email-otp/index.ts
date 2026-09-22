// Spendly — verify-email-otp
//
// Verifies the 6-digit OTP for an email and, on success, CREATES the Supabase
// auth user with the provided password and email_confirm=true — all in one
// step, so no half-created/unverified accounts ever exist.
//
// After this returns ok, the client logs in normally with email + password
// (login itself never uses OTP).
//
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-provided).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const MAX_ATTEMPTS = 5;

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

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const payload = await req.json().catch(() => ({}));
    const email = typeof payload.email === "string"
      ? payload.email.trim().toLowerCase()
      : "";
    const code = typeof payload.code === "string" ? payload.code.trim() : "";
    const password = typeof payload.password === "string" ? payload.password : "";
    const fullName = typeof payload.name === "string" ? payload.name.trim() : "";

    if (!email || !/^\d{6}$/.test(code) || password.length < 6) {
      return json(
        { error: "Email, a 6-digit code, and a password (6+ chars) are required." },
        400,
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Latest un-consumed code for this email.
    const { data: rows, error: selErr } = await supabase
      .from("email_otps")
      .select("*")
      .eq("email", email)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1);

    if (selErr) {
      console.error("email_otps select failed:", selErr);
      return json({ error: "Could not verify the code." }, 500);
    }
    const otp = rows?.[0];
    if (!otp) {
      return json({ error: "No active code. Please request a new one." }, 400);
    }
    if (new Date(otp.expires_at).getTime() < Date.now()) {
      return json({ error: "Code expired. Please request a new one." }, 400);
    }
    if (otp.attempts >= MAX_ATTEMPTS) {
      return json({ error: "Too many attempts. Request a new code." }, 429);
    }

    const expected = await sha256Hex(`${email}:${code}`);
    if (expected !== otp.code_hash) {
      await supabase
        .from("email_otps")
        .update({ attempts: otp.attempts + 1 })
        .eq("id", otp.id);
      return json({ error: "Incorrect code. Please try again." }, 400);
    }

    // Correct code → create the auth user with the password, pre-confirmed.
    const { data: created, error: createErr } = await supabase.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName || null },
      });

    if (createErr) {
      // If the user was created in a prior partial attempt, treat as success-ish.
      const msg = createErr.message?.toLowerCase() ?? "";
      if (msg.includes("already") || msg.includes("registered")) {
        await supabase.from("email_otps").update({
          consumed_at: new Date().toISOString(),
        }).eq("id", otp.id);
        return json({ ok: true, message: "Email verified." });
      }
      console.error("createUser failed:", createErr);
      return json({ error: "Could not create your account." }, 500);
    }

    await supabase
      .from("email_otps")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", otp.id);

    return json({
      ok: true,
      message: "Email verified and account created.",
      user_id: created.user?.id,
    });
  } catch (err) {
    console.error("verify-email-otp error:", err);
    return json({ error: "Unexpected error verifying the code." }, 500);
  }
});
