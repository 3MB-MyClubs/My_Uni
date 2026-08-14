import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

// TEMPORARY LEGACY COMPATIBILITY — remove after minimum supported app version advances.

import {
  challengeLifetimeMs,
  generateSixDigitCode,
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

const legacySuccessResponse = {
  success: true,
  message: "Password reset code sent.",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: { ...corsHeaders, "Cache-Control": "no-store" },
    });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const { email }: ReqPayload = await req.json();
    const normalizedEmail = normalizeEmail(email);
    if (!normalizedEmail || !isValidEmail(normalizedEmail)) {
      return json({ error: "Enter a valid email address." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const pepper = Deno.env.get("SIGNUP_CODE_PEPPER");
    if (!supabaseUrl || !serviceRoleKey || !resendApiKey || !pepper) {
      return json({ error: "Server configuration is missing." }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const limited = await enforceEdgeRateLimit(
      supabase,
      req,
      "auth_password_reset_request",
      normalizedEmail,
    );
    // TEMPORARY V1 COMPATIBILITY: suppress delivery but keep the released
    // success-shaped response instead of requiring HTTP 429 handling.
    if (limited) return json(legacySuccessResponse);

    const [{ data: profile, error: profileError }, { data: appAdmin, error: adminError }] =
      await Promise.all([
        supabase.from("profiles").select("id").eq("email", normalizedEmail).maybeSingle(),
        supabase
          .from("app_admins")
          .select("auth_user_id")
          .eq("email", normalizedEmail)
          .maybeSingle(),
      ]);
    if (profileError || adminError) {
      console.error("account lookup failed", profileError ?? adminError);
      return json({ error: "Could not check account status." }, 500);
    }
    if (!profile && !appAdmin) {
      return json({ error: "No account found for this email." }, 404);
    }

    const code = generateSixDigitCode();
    const codeHash = await legacyChallengeCodeHash(
      normalizedEmail,
      code,
      pepper,
    );
    const expiresAt = new Date(Date.now() + challengeLifetimeMs).toISOString();
    const { data: issueStatus, error: resetError } = await supabase.rpc(
      "issue_password_reset_challenge_legacy",
      {
        p_email: normalizedEmail,
        p_code_hash: codeHash,
        p_expires_at: expiresAt,
      },
    );
    if (resetError) {
      console.error("password reset upsert failed", resetError);
      return json({ error: "Could not create reset code." }, 500);
    }
    if (issueStatus !== "issued") return json(legacySuccessResponse);

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "ClubUp <noreply@myclub.bar>",
        to: normalizedEmail,
        subject: "Your ClubUp password reset code",
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.5;">
            <h2>Your password reset code</h2>
            <p>Use this code to set your ClubUp passcode:</p>
            <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px;">${code}</p>
            <p>This code expires in 10 minutes.</p>
          </div>
        `,
      }),
    });
    if (!emailResponse.ok) {
      console.error("resend failed", await emailResponse.text());
      await supabase
        .from("pending_password_resets")
        .delete()
        .eq("email", normalizedEmail)
        .eq("code_hash", codeHash);
      return json({ error: "Could not send reset email." }, 500);
    }

    return json(legacySuccessResponse);
  } catch (error) {
    if (error instanceof RateLimitUnavailableError) {
      return json({ error: "Service temporarily unavailable." }, 503);
    }
    console.error("send-password-reset-code failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
