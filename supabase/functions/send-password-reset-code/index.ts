import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
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
    const { email }: ReqPayload = await req.json();
    const normalizedEmail = email?.trim().toLowerCase();
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

    const code = generateCode();
    const codeHash = await sha256Hex(`${normalizedEmail}:${code}:${pepper}`);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    const { error: resetError } = await supabase
      .from("pending_password_resets")
      .upsert({
        email: normalizedEmail,
        code_hash: codeHash,
        verified: false,
        expires_at: expiresAt,
        created_at: new Date().toISOString(),
      });
    if (resetError) {
      console.error("password reset upsert failed", resetError);
      return json({ error: "Could not create reset code." }, 500);
    }

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
      return json({ error: "Could not send reset email." }, 500);
    }

    return json({ success: true, message: "Password reset code sent." });
  } catch (error) {
    console.error("send-password-reset-code failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
