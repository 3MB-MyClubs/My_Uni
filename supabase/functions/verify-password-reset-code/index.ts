import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ReqPayload {
  email: string;
  code: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function sha256Hex(value: string) {
  const data = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function getServiceRoleKey() {
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return null;
  try {
    return JSON.parse(raw)["default"] ?? null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const { email, code }: ReqPayload = await req.json();
    const normalizedEmail = email?.trim().toLowerCase();
    const normalizedCode = code?.trim();
    if (!normalizedEmail || !isValidEmail(normalizedEmail)) {
      return json({ error: "Enter a valid email address." }, 400);
    }
    if (!normalizedCode || !/^\d{6}$/.test(normalizedCode)) {
      return json({ error: "Enter a valid 6-digit code." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();
    const pepper = Deno.env.get("SIGNUP_CODE_PEPPER");
    if (!supabaseUrl || !serviceRoleKey || !pepper) {
      return json({ error: "Server configuration is missing." }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { data: pending, error: pendingError } = await supabase
      .from("pending_password_resets")
      .select("code_hash, expires_at")
      .eq("email", normalizedEmail)
      .maybeSingle();
    if (pendingError) return json({ error: "Could not verify code." }, 500);
    if (!pending) return json({ error: "No reset code found. Please request a new code." }, 404);
    if (new Date(pending.expires_at).getTime() < Date.now()) {
      return json({ error: "Reset code expired. Please request a new code." }, 410);
    }

    const expectedHash = await sha256Hex(
      `${normalizedEmail}:${normalizedCode}:${pepper}`,
    );
    if (expectedHash !== pending.code_hash) {
      return json({ error: "Invalid reset code." }, 400);
    }

    const { error: updateError } = await supabase
      .from("pending_password_resets")
      .update({ verified: true })
      .eq("email", normalizedEmail);
    if (updateError) return json({ error: "Could not mark reset code as verified." }, 500);
    return json({ success: true, message: "Reset code verified." });
  } catch (error) {
    console.error("verify-password-reset-code failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
