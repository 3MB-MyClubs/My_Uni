// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ReqPayload {
  email: string;
  password: string;
  full_name: string;
  major_id: string;
  academic_year_id: string;
  interest_ids: string[];
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

function isKuEmail(email: string) {
  return /^[a-zA-Z0-9._%+-]+@ku\.edu\.tr$/.test(email);
}

function isValidPassword(password: string) {
  return /^\d{6,}$/.test(password);
}

function getServiceRoleKey() {
  const secretKeysRaw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!secretKeysRaw) return null;

  try {
    const secretKeys = JSON.parse(secretKeysRaw);
    return secretKeys["default"] ?? null;
  } catch (_error) {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: { ...corsHeaders, "Cache-Control": "no-store" },
    });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    const payload: ReqPayload = await req.json();

    const email = payload.email?.trim().toLowerCase();
    const password = payload.password?.trim();
    const fullName = payload.full_name?.trim();
    const majorId = payload.major_id?.trim();
    const academicYearId = payload.academic_year_id?.trim();
    const interestIds = Array.isArray(payload.interest_ids)
      ? [
          ...new Set(
            payload.interest_ids
              .filter((id): id is string => typeof id === "string")
              .map((id) => id.trim())
              .filter((id) => id.length > 0),
          ),
        ]
      : [];

    if (!email || !isKuEmail(email)) {
      return json({ error: "Only @ku.edu.tr emails are allowed." }, 400);
    }

    if (!password || !isValidPassword(password)) {
      return json({ error: "Password must be at least 6 numbers." }, 400);
    }

    if (!fullName) {
      return json({ error: "Full name is required." }, 400);
    }

    if (!majorId) {
      return json({ error: "Major is required." }, 400);
    }

    if (!academicYearId) {
      return json({ error: "Academic year is required." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = getServiceRoleKey();

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Server configuration is missing." }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const { data: pending, error: pendingError } = await supabase
      .from("pending_signups")
      .select("email, verified, expires_at")
      .eq("email", email)
      .maybeSingle();

    if (pendingError) {
      console.error("pending signup lookup failed", pendingError);
      return json(
        {
          error: "Could not check verification status.",
          details: pendingError.message,
          code: pendingError.code,
        },
        500,
      );
    }

    if (!pending || !pending.verified) {
      return json({ error: "Email has not been verified." }, 403);
    }

    if (new Date(pending.expires_at).getTime() < Date.now()) {
      return json(
        { error: "Verification expired. Please request a new code." },
        410,
      );
    }

    const { data: existingProfile, error: existingProfileError } =
      await supabase
        .from("profiles")
        .select("id")
        .eq("email", email)
        .maybeSingle();

    if (existingProfileError) {
      console.error("profile lookup failed", existingProfileError);
      return json(
        {
          error: "Could not check account status.",
          details: existingProfileError.message,
          code: existingProfileError.code,
        },
        500,
      );
    }

    if (existingProfile) {
      return json({ error: "An account with this email already exists." }, 409);
    }

    const { data: major, error: majorError } = await supabase
      .from("majors")
      .select("id, name")
      .eq("id", majorId)
      .eq("is_active", true)
      .maybeSingle();

    if (majorError) {
      console.error("major lookup failed", majorError);
      return json({ error: "Could not validate major." }, 500);
    }

    if (!major) {
      return json({ error: "Selected major is invalid." }, 400);
    }

    const { data: academicYear, error: academicYearError } = await supabase
      .from("academic_years")
      .select("id, name")
      .eq("id", academicYearId)
      .eq("is_active", true)
      .maybeSingle();

    if (academicYearError) {
      console.error("academic year lookup failed", academicYearError);
      return json({ error: "Could not validate academic year." }, 500);
    }

    if (!academicYear) {
      return json({ error: "Selected academic year is invalid." }, 400);
    }

    if (interestIds.length > 0) {
      const { data: validInterests, error: interestsError } = await supabase
        .from("interests")
        .select("id")
        .in("id", interestIds);

      if (interestsError) {
        console.error("interests lookup failed", interestsError);
        return json(
          {
            error: "Could not validate interests.",
            details: interestsError.message,
            code: interestsError.code,
          },
          500,
        );
      }

      if (!validInterests || validInterests.length !== interestIds.length) {
        return json(
          { error: "One or more selected interests are invalid." },
          400,
        );
      }
    }

    const { data: createdUser, error: createUserError } =
      await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: fullName,
          major_id: majorId,
          academic_year_id: academicYearId,
          role: "student",
        },
      });

    if (createUserError || !createdUser.user) {
      console.error("auth user creation failed", createUserError);
      return json(
        {
          error: "Could not create user.",
          details: createUserError?.message,
        },
        500,
      );
    }

    const userId = createdUser.user.id;

    const { error: profileInsertError } = await supabase
      .from("profiles")
      .insert({
        id: userId,
        email,
        full_name: fullName,
        major_id: majorId,
        academic_year_id: academicYearId,
        role: "student",
      });

    if (profileInsertError) {
      console.error("profile insert failed", profileInsertError);

      await supabase.auth.admin.deleteUser(userId);

      return json(
        {
          error: "Could not create profile.",
          details: profileInsertError.message,
          code: profileInsertError.code,
        },
        500,
      );
    }

    if (interestIds.length > 0) {
      const interestRows = interestIds.map((interestId) => ({
        user_id: userId,
        interest_id: interestId,
      }));

      const { error: interestsInsertError } = await supabase
        .from("student_interests")
        .insert(interestRows);

      if (interestsInsertError) {
        console.error("student interests insert failed", interestsInsertError);
        await supabase.auth.admin.deleteUser(userId);
        return json(
          {
            error: "Could not save interests.",
            details: interestsInsertError.message,
            code: interestsInsertError.code,
          },
          500,
        );
      }
    }

    const { error: cleanupError } = await supabase
      .from("pending_signups")
      .delete()
      .eq("email", email);

    if (cleanupError) {
      console.error("pending signup cleanup failed", cleanupError);
    }

    return json({
      success: true,
      message: "Signup completed.",
    });
  } catch (error) {
    console.error("complete-signup failed", error);
    return json({ error: "Invalid request." }, 400);
  }
});
