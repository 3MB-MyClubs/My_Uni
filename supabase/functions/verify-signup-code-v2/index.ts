import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import {
  capabilityHash,
  challengeCodeHash,
  generateCapability,
  getServiceRoleKey,
  isKuEmail,
  normalizeEmail,
} from "../_shared/auth_challenge.ts";
import {
  enforceEdgeRateLimit,
  rateLimitResponse,
  RateLimitUnavailableError,
} from "../_shared/rate_limit.ts";

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
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const payload = await req.json();
    const email = normalizeEmail(payload?.email);
    const code = typeof payload?.code === "string" ? payload.code.trim() : "";
    if (!email || !isKuEmail(email)) {
      return json({ error: "Only @ku.edu.tr emails are allowed." }, 400);
    }
    if (!/^\d{6}$/.test(code)) {
      return json({ error: "Enter a valid 6-digit code." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();
    const pepper = Deno.env.get("SIGNUP_CODE_PEPPER");
    if (!supabaseUrl || !serviceRoleKey || !pepper) {
      return json({ error: "Server configuration is missing." }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const limited = await enforceEdgeRateLimit(
      supabase,
      req,
      "auth_signup_verify",
      email,
    );
    if (limited) return rateLimitResponse(limited, corsHeaders);

    const capability = generateCapability();
    const [codeHash, storedCapabilityHash] = await Promise.all([
      challengeCodeHash("signup", email, code, pepper),
      capabilityHash("signup", email, capability, pepper),
    ]);
    const { data: status, error } = await supabase.rpc(
      "verify_signup_challenge_v2",
      {
        p_email: email,
        p_code_hash: codeHash,
        p_capability_hash: storedCapabilityHash,
      },
    );
    if (error) {
      console.error("signup challenge verification failed", error);
      return json({ error: "Could not verify code." }, 500);
    }
    if (status === "expired") {
      return json({ error: "Verification code expired. Request a new code." }, 410);
    }
    if (status === "locked") {
      return new Response(
        JSON.stringify({
          error: "rate_limit_exceeded",
          message: "Too many attempts. Request a new code.",
          retry_after_seconds: 60,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Access-Control-Expose-Headers": "Retry-After",
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
            "Retry-After": "60",
          },
        },
      );
    }
    if (status !== "ok") return json({ error: "Invalid verification code." }, 400);

    return json({ success: true, capability });
  } catch (error) {
    if (error instanceof RateLimitUnavailableError) {
      return json({ error: "Service temporarily unavailable." }, 503);
    }
    console.error("verify-signup-code failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
