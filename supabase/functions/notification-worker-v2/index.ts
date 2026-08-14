import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";
import { importPKCS8, SignJWT } from "npm:jose@6.2.8";
import { classifyFcmFailure, type DeliveryOutcome } from "./delivery.ts";

type ServiceAccount = { project_id: string; client_email: string; private_key: string };
type OutboxClaim = { id: string; lease_token: string };
type Delivery = {
  delivery_id: string; lease_token: string; notification_id: string;
  device_id: string; fcm_token: string; locale: string;
  notification_type: string; title: string; body: string;
  target_type: string; target_id: string; actor_user_id?: string;
  localization_args: Record<string, unknown>; notification_group_key?: string;
  message_count: number; attempt_count: number;
};
type Outcome = DeliveryOutcome;

const RECIPIENT_BATCH_SIZE = 250;
const DELIVERY_BATCH_SIZE = 250;
const MAX_OUTBOX_BATCHES_PER_RUN = 8;
const SEND_CONCURRENCY = 20;
const MAX_ATTEMPTS = 8;
let cachedAccessToken: { value: string; expiresAt: number } | undefined;

const json = (body: unknown, status = 200) => Response.json(body, {
  status,
  headers: { "Cache-Control": "no-store" },
});

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT is not configured");
  const value = JSON.parse(raw) as Partial<ServiceAccount>;
  if (!value.project_id || !value.client_email || !value.private_key) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is missing required fields");
  }
  return value as ServiceAccount;
}

async function googleAccessToken(account: ServiceAccount): Promise<string> {
  const nowMs = Date.now();
  if (cachedAccessToken && cachedAccessToken.expiresAt - nowMs > 5 * 60_000) {
    return cachedAccessToken.value;
  }
  const key = await importPKCS8(account.private_key, "RS256");
  const now = Math.floor(nowMs / 1000);
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now).setExpirationTime(now + 3600).sign(key);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json() as { access_token?: string; expires_in?: number };
  if (!response.ok || !result.access_token) throw new Error(`Google OAuth failed (${response.status})`);
  cachedAccessToken = {
    value: result.access_token,
    expiresAt: nowMs + Math.max(300, result.expires_in ?? 3600) * 1000,
  };
  return result.access_token;
}

function localizedCopy(delivery: Delivery): { title: string; body: string } {
  const args = delivery.localization_args ?? {};
  const value = (key: string, fallback: string) =>
    typeof args[key] === "string" && String(args[key]).trim() ? String(args[key]).trim() : fallback;
  const tr = delivery.locale === "tr";
  const actor = value("actorName", tr ? "Birisi" : "Someone");
  const club = value("clubName", tr ? "Bir kulüp" : "A club");
  const group = value("groupName", tr ? "Grup sohbeti" : "Group chat");
  const content = value("content", tr ? "Mesaj" : "Message");
  const eventTitle = value("eventTitle", tr ? "etkinliğin" : "your event");
  const postPreview = value("postPreview", tr ? "son gönderin" : "your latest post");
  const comment = value("comment", "");
  if (tr) {
    switch (delivery.notification_type) {
      case "direct_message": return { title: actor, body: `${actor}: ${content}` };
      case "group_message": return { title: group, body: `${actor}: ${content}` };
      case "club_channel_message": return { title: club, body: `${club}: ${content}` };
      case "club_inbox_message": return { title: delivery.title, body: `${actor}: ${content}` };
      case "club_post": return { title: `${club} yeni bir gönderi paylaştı`, body: `${club} yeni bir gönderi paylaştı: “${content}” Gönderiyi görmek için dokun.` };
      case "club_event": return { title: `${club} yeni bir etkinlik duyurdu`, body: `${club}, “${eventTitle}” etkinliğini duyurdu. Ayrıntılar için dokun.` };
      case "post_like": return { title: `${actor} gönderini beğendi`, body: `${actor}, “${postPreview}” gönderini beğendi.` };
      case "post_comment": return { title: `${actor} gönderine yorum yaptı`, body: `${actor}: “${comment}” Yanıtlamak için dokun.` };
      case "event_rsvp": return { title: `${actor} etkinliğine katılıyor`, body: `${actor}, “${eventTitle}” etkinliğine katılıyor.` };
      case "profile_follow": return { title: `${actor} seni takip etmeye başladı`, body: `${actor} seni takip etmeye başladı.` };
    }
  }
  switch (delivery.notification_type) {
    case "direct_message": return { title: actor, body: `${actor}: ${content}` };
    case "group_message": return { title: group, body: `${actor}: ${content}` };
    case "club_channel_message": return { title: club, body: `${club}: ${content}` };
    case "club_inbox_message": return { title: delivery.title, body: `${actor}: ${content}` };
    case "club_post": return { title: `${club} posted something new`, body: `${club} shared “${content}”. Tap to view the post.` };
    case "club_event": return { title: `New event from ${club}`, body: `${club} announced “${eventTitle}”. Tap for details and RSVP.` };
    case "post_like": return { title: `${actor} liked your post`, body: `${actor} liked your post “${postPreview}”.` };
    case "post_comment": return { title: `${actor} commented on your post`, body: `${actor} commented: “${comment}”. Tap to reply.` };
    case "event_rsvp": return { title: `${actor} is going to your event`, body: `${actor} is going to “${eventTitle}”.` };
    case "profile_follow": return { title: `${actor} followed you`, body: `${actor} started following you.` };
  }
  return { title: delivery.title, body: delivery.body };
}

async function expandOutbox(admin: SupabaseClient, workerId: string) {
  let batches = 0;
  let recipients = 0;
  for (; batches < MAX_OUTBOX_BATCHES_PER_RUN; batches++) {
    const { data: rawClaim, error: claimError } = await admin.rpc("claim_notification_outbox_v2", {
      p_worker: workerId, p_lease_seconds: 90, p_max_attempts: MAX_ATTEMPTS,
    });
    if (claimError) throw claimError;
    const claim = rawClaim as OutboxClaim | null;
    if (!claim) break;
    try {
      const { data, error } = await admin.rpc("expand_notification_outbox_v2", {
        p_outbox_id: claim.id,
        p_lease_token: claim.lease_token,
        p_batch_size: RECIPIENT_BATCH_SIZE,
      });
      if (error) throw error;
      recipients += Number((data as { recipients?: number } | null)?.recipients ?? 0);
    } catch (error) {
      await admin.rpc("fail_notification_outbox_v2", {
        p_outbox_id: claim.id,
        p_lease_token: claim.lease_token,
        p_error_code: "expansion_failed",
        p_error: error instanceof Error ? error.message.slice(0, 1000) : "Unknown expansion error",
        p_retryable: true,
        p_max_attempts: MAX_ATTEMPTS,
      });
    }
  }
  return { batches, recipients };
}

async function complete(admin: SupabaseClient, delivery: Delivery, result: {
  outcome: Outcome; status?: number; code?: string; error?: string; providerId?: string;
}) {
  const { error } = await admin.rpc("complete_notification_delivery_v2", {
    p_delivery_id: delivery.delivery_id,
    p_lease_token: delivery.lease_token,
    p_outcome: result.outcome,
    p_http_status: result.status ?? null,
    p_error_code: result.code ?? null,
    p_error: result.error?.slice(0, 1000) ?? null,
    p_provider_message_id: result.providerId ?? null,
    p_max_attempts: MAX_ATTEMPTS,
  });
  if (error) throw error;
}

async function sendOne(admin: SupabaseClient, account: ServiceAccount, token: string, delivery: Delivery) {
  try {
    const copy = localizedCopy(delivery);
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ message: {
          token: delivery.fcm_token,
          notification: copy,
          data: {
            notification_id: delivery.notification_id,
            type: delivery.notification_type,
            target_type: delivery.target_type,
            target_id: delivery.target_id,
            ...(delivery.actor_user_id ? { actor_user_id: delivery.actor_user_id } : {}),
            ...(delivery.notification_group_key
              ? { notification_group_key: delivery.notification_group_key }
              : {}),
            message_count: String(delivery.message_count ?? 1),
          },
          android: { collapse_key: delivery.notification_group_key ?? delivery.notification_id,
            priority: "high", notification: { channel_id: "clubup_notifications", sound: "default" } },
          apns: { headers: { "apns-collapse-id": delivery.notification_group_key ?? delivery.notification_id },
            payload: { aps: { sound: "default", "content-available": 1 } } },
        } }),
      },
    );
    const body = await response.text();
    if (response.ok) {
      let providerId: string | undefined;
      try { providerId = (JSON.parse(body) as { name?: string }).name; } catch { /* no provider id */ }
      await complete(admin, delivery, { outcome: "delivered", status: response.status, providerId });
      return "delivered";
    }
    const classified = classifyFcmFailure(response.status, body);
    if (classified.code === "provider_auth") cachedAccessToken = undefined;
    if (classified.invalidateToken) {
      await admin.from("push_devices").delete().eq("id", delivery.device_id);
    }
    await complete(admin, delivery, {
      outcome: classified.outcome, status: response.status,
      code: classified.code, error: body.slice(0, 1000),
    });
    return classified.outcome;
  } catch (error) {
    await complete(admin, delivery, {
      outcome: "retryable", code: "network_error",
      error: error instanceof Error ? error.message : "Unknown network error",
    });
    return "retryable";
  }
}

async function deliver(admin: SupabaseClient, workerId: string) {
  const { data, error } = await admin.rpc("claim_notification_deliveries_v2", {
    p_worker: workerId, p_batch_size: DELIVERY_BATCH_SIZE,
    p_lease_seconds: 90, p_max_attempts: MAX_ATTEMPTS,
  });
  if (error) throw error;
  const deliveries = (data ?? []) as Delivery[];
  if (!deliveries.length) return { claimed: 0, delivered: 0, retryable: 0, terminal: 0 };
  const account = serviceAccount();
  const token = await googleAccessToken(account);
  const outcomes: string[] = [];
  for (let index = 0; index < deliveries.length; index += SEND_CONCURRENCY) {
    outcomes.push(...await Promise.all(
      deliveries.slice(index, index + SEND_CONCURRENCY).map((item) => sendOne(admin, account, token, item)),
    ));
  }
  return {
    claimed: deliveries.length,
    delivered: outcomes.filter((value) => value === "delivered").length,
    retryable: outcomes.filter((value) => value === "retryable").length,
    terminal: outcomes.filter((value) => value === "terminal").length,
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const expectedSecret = Deno.env.get("NOTIFICATION_WORKER_SECRET");
  if (!expectedSecret || request.headers.get("x-worker-secret") !== expectedSecret) {
    return json({ error: "Unauthorized" }, 401);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json({ error: "Runtime is not configured" }, 500);
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const workerId = `edge:${crypto.randomUUID()}`;
  try {
    const expansion = await expandOutbox(admin, workerId);
    const delivery = await deliver(admin, workerId);
    console.log(JSON.stringify({ event: "notification_v2_run", ...expansion, ...delivery }));
    return json({ ok: true, expansion, delivery });
  } catch (error) {
    console.error(JSON.stringify({ event: "notification_v2_failed",
      error: error instanceof Error ? error.message : "Unknown worker error" }));
    return json({ error: "Worker run failed" }, 500);
  }
});
