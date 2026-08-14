import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

// TEMPORARY LEGACY COMPATIBILITY — remove after minimum supported app version advances.

import {
  getServiceRoleKey,
  isValidEmail,
  normalizeEmail,
} from "../_shared/auth_challenge.ts";
import {
  enforceEdgeRateLimit,
  RateLimitUnavailableError,
} from "../_shared/rate_limit.ts";

interface ReqPayload {
  email: string;
  password: string;
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
    const { email, password }: ReqPayload = await req.json();
    const normalizedEmail = normalizeEmail(email);
    const normalizedPassword = password?.trim();
    if (!normalizedEmail || !isValidEmail(normalizedEmail)) {
      return json({ error: "Enter a valid email address." }, 400);
    }
    if (!normalizedPassword || !/^\d{6,}$/.test(normalizedPassword)) {
      return json({ error: "Password must be at least 6 numbers." }, 400);
    }
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Server configuration is missing." }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const limited = await enforceEdgeRateLimit(
      supabase,
      req,
      "auth_password_reset_complete",
      normalizedEmail,
    );
    // TEMPORARY V1 COMPATIBILITY: preserve the released unverified response.
    if (limited) {
      return json({ error: "Reset code has not been verified." }, 403);
    }

    const [{ data: profile, error: profileError }, { data: appAdmin, error: adminError }] =
      await Promise.all([
        supabase.from("profiles").select("id").eq("email", normalizedEmail).maybeSingle(),
        supabase
          .from("app_admins")
          .select("auth_user_id")
          .eq("email", normalizedEmail)
          .maybeSingle(),
      ]);
    if (profileError || adminError) return json({ error: "Could not find account." }, 500);
    const userId = profile?.id ?? appAdmin?.auth_user_id;
    if (!userId) return json({ error: "No account found for this email." }, 404);

    const { data: consumeStatus, error: consumeError } = await supabase.rpc(
      "consume_password_reset_verification_legacy",
      {
        p_email: normalizedEmail,
      },
    );
    if (consumeError) {
      console.error("legacy password reset verification consumption failed", consumeError);
      return json({ error: "Could not validate reset verification." }, 500);
    }
    if (consumeStatus === "expired") {
      return json(
        { error: "Reset code expired. Please request a new code." },
        410,
      );
    }
    if (consumeStatus !== "ok") {
      return json({ error: "Reset code has not been verified." }, 403);
    }

    const { error: revokeError } = await supabase.rpc("revoke_user_sessions", {
      p_user_id: userId,
    });
    if (revokeError) {
      console.error("password reset session revocation failed", revokeError);
      return json({ error: "Could not revoke existing sessions." }, 500);
    }

    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userId,
      { password: normalizedPassword },
    );
    if (updateError) return json({ error: "Could not update password." }, 500);

    const { error: cleanupError } = await supabase
      .from("pending_password_resets")
      .delete()
      .eq("email", normalizedEmail);
    if (cleanupError) console.error("password reset cleanup failed", cleanupError);
    return json({ success: true, message: "Password updated." });
  } catch (error) {
    if (error instanceof RateLimitUnavailableError) {
      return json({ error: "Service temporarily unavailable." }, 503);
    }
    console.error("complete-password-reset failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
