import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

// TEMPORARY LEGACY COMPATIBILITY — remove after minimum supported app version advances.

import {
  getServiceRoleKey,
  isValidEmail,
  legacyChallengeCodeHash,
  normalizeEmail,
} from "../_shared/auth_challenge.ts";
import {
  enforceEdgeRateLimit,
  RateLimitUnavailableError,
} from "../_shared/rate_limit.ts";

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
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: { ...corsHeaders, "Cache-Control": "no-store" },
    });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const { email, code }: ReqPayload = await req.json();
    const normalizedEmail = normalizeEmail(email);
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
    const limited = await enforceEdgeRateLimit(
      supabase,
      req,
      "auth_password_reset_verify",
      normalizedEmail,
    );
    // TEMPORARY V1 COMPATIBILITY: preserve the released invalid-code shape.
    if (limited) return json({ error: "Invalid reset code." }, 400);

    const expectedHash = await legacyChallengeCodeHash(
      normalizedEmail,
      normalizedCode,
      pepper,
    );
    const { data: status, error: verifyError } = await supabase.rpc(
      "verify_password_reset_challenge_legacy",
      {
        p_email: normalizedEmail,
        p_code_hash: expectedHash,
      },
    );
    if (verifyError) return json({ error: "Could not verify code." }, 500);
    if (status === "missing") {
      return json(
        { error: "No reset code found. Please request a new code." },
        404,
      );
    }
    if (status === "expired") {
      return json(
        { error: "Reset code expired. Please request a new code." },
        410,
      );
    }
    if (status === "locked") {
      return json({ error: "Invalid reset code." }, 400);
    }
    if (status !== "ok") return json({ error: "Invalid reset code." }, 400);

    return json({ success: true, message: "Reset code verified." });
  } catch (error) {
    if (error instanceof RateLimitUnavailableError) {
      return json({ error: "Service temporarily unavailable." }, 503);
    }
    console.error("verify-password-reset-code failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
