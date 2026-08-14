import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import {
  challengeCodeHash,
  challengeLifetimeMs,
  generateSixDigitCode,
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
const genericResponse = {
  success: true,
  message: "If this address can be registered, a verification code has been sent.",
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
    if (!email || !isKuEmail(email)) {
      return json({ error: "Only @ku.edu.tr emails are allowed." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const pepper = Deno.env.get("SIGNUP_CODE_PEPPER");
    if (!supabaseUrl || !serviceRoleKey || !resendApiKey || !pepper) {
      return json({ error: "Server configuration is missing." }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const limited = await enforceEdgeRateLimit(
      supabase,
      req,
      "auth_signup_request",
      email,
    );
    if (limited) return rateLimitResponse(limited, corsHeaders);

    const { data: existing, error: lookupError } = await supabase
      .from("profiles")
      .select("id")
      .eq("email", email)
      .maybeSingle();
    if (lookupError) {
      console.error("signup account lookup failed", lookupError);
      return json({ error: "Could not send verification code." }, 500);
    }
    if (existing) return json(genericResponse);

    const code = generateSixDigitCode();
    const codeHash = await challengeCodeHash("signup", email, code, pepper);
    const expiresAt = new Date(Date.now() + challengeLifetimeMs).toISOString();
    const { data: issueStatus, error: issueError } = await supabase.rpc(
      "issue_signup_challenge_v2",
      { p_email: email, p_code_hash: codeHash, p_expires_at: expiresAt },
    );
    if (issueError) {
      console.error("signup challenge issue failed", issueError);
      return json({ error: "Could not send verification code." }, 500);
    }
    if (issueStatus !== "issued") return json(genericResponse);

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "ClubUp <noreply@myclub.bar>",
        to: email,
        subject: "Your ClubUp verification code",
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.5;">
            <h2>Your verification code</h2>
            <p>Use this code to finish creating your ClubUp account:</p>
            <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px;">${code}</p>
            <p>This code expires in 10 minutes.</p>
          </div>
        `,
      }),
    });
    if (!emailResponse.ok) {
      console.error("signup email delivery failed", await emailResponse.text());
      await supabase.rpc("cancel_signup_challenge_v2", {
        p_email: email,
        p_code_hash: codeHash,
      });
      return json({ error: "Could not send verification code." }, 500);
    }

    return json(genericResponse);
  } catch (error) {
    if (error instanceof RateLimitUnavailableError) {
      return json({ error: "Service temporarily unavailable." }, 503);
    }
    console.error("send-signup-code failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
