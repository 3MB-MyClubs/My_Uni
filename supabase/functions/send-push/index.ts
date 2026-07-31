import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@6";

type WebhookPayload = {
  type?: string;
  table?: string;
  record?: { id?: string };
  notification_id?: string;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type NotificationCopy = { title: string; body: string };

function localizedCopy(
  type: string,
  args: Record<string, unknown>,
  locale: string,
  fallback: NotificationCopy,
): NotificationCopy {
  const value = (key: string, defaultValue: string) => {
    const candidate = args[key];
    return typeof candidate === "string" && candidate.trim()
      ? candidate.trim()
      : defaultValue;
  };
  const tr = locale === "tr";
  const actor = value("actorName", tr ? "Birisi" : "Someone");
  const club = value("clubName", tr ? "Bir kulüp" : "A club");
  const group = value("groupName", tr ? "Grup sohbeti" : "Group chat");
  const content = value("content", "");
  const eventTitle = value("eventTitle", tr ? "etkinliğin" : "your event");
  const postPreview = value("postPreview", tr ? "son gönderin" : "your latest post");
  const comment = value("comment", "");

  if (tr) {
    switch (type) {
      case "direct_message": return { title: actor, body: `${actor}: ${content}` };
      case "group_message": return { title: group, body: `${actor}: ${content}` };
      case "club_channel_message": return { title: club, body: `${club}: ${content}` };
      case "club_inbox_message": return { title: actor, body: `${actor}: ${content}` };
      case "club_post": return {
        title: `${club} yeni bir gönderi paylaştı`,
        body: `${club} yeni bir gönderi paylaştı: “${content}” Gönderiyi görmek için dokun.`,
      };
      case "club_event": return {
        title: `${club} yeni bir etkinlik duyurdu`,
        body: `${club}, “${eventTitle}” etkinliğini duyurdu. Ayrıntıları görmek ve katılmak için dokun.`,
      };
      case "post_like": return {
        title: `${actor} gönderini beğendi`,
        body: `${actor}, “${postPreview}” gönderini beğendi.`,
      };
      case "post_comment": return {
        title: `${actor} gönderine yorum yaptı`,
        body: `${actor}: “${comment}” Yanıtlamak için dokun.`,
      };
      case "event_rsvp": return {
        title: `${actor} etkinliğine katılıyor`,
        body: `${actor}, “${eventTitle}” etkinliğine katılıyor. Misafir listen büyüyor!`,
      };
      case "profile_follow": return {
        title: `${actor} seni takip etmeye başladı`,
        body: `${actor} seni takip etmeye başladı. Profilini görmek için dokun.`,
      };
      default: return fallback;
    }
  }

  switch (type) {
    case "direct_message": return { title: actor, body: `${actor}: ${content}` };
    case "group_message": return { title: group, body: `${actor}: ${content}` };
    case "club_channel_message": return { title: club, body: `${club}: ${content}` };
    case "club_inbox_message": return { title: actor, body: `${actor}: ${content}` };
    case "club_post": return {
      title: `${club} posted something new`,
      body: `${club} shared “${content}”. Tap to view the post.`,
    };
    case "club_event": return {
      title: `New event from ${club}`,
      body: `${club} announced “${eventTitle}”. Tap for details and RSVP.`,
    };
    case "post_like": return {
      title: `${actor} liked your post`,
      body: `${actor} liked your post “${postPreview}”.`,
    };
    case "post_comment": return {
      title: `${actor} commented on your post`,
      body: `${actor} commented: “${comment}”. Tap to reply.`,
    };
    case "event_rsvp": return {
      title: `${actor} is going to your event`,
      body: `${actor} is going to “${eventTitle}”. Your guest list is growing!`,
    };
    case "profile_follow": return {
      title: `${actor} followed you`,
      body: `${actor} started following you. Tap to view their profile.`,
    };
    default: return fallback;
  }
}

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });

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
  const key = await importPKCS8(account.private_key, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    throw new Error(`Google OAuth failed (${response.status})`);
  }
  return result.access_token;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Supabase runtime is not configured" }, 500);
  }

  let notificationId: string | undefined;
  try {
    const payload = (await request.json()) as WebhookPayload;
    notificationId = payload.record?.id ?? payload.notification_id;
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  if (!notificationId || !/^[0-9a-f-]{36}$/i.test(notificationId)) {
    return json({ error: "Invalid notification id" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const startedAt = new Date().toISOString();
  const { data: notification, error: claimError } = await admin
    .from("notifications")
    .update({ push_started_at: startedAt, push_error: null })
    .eq("id", notificationId)
    .is("push_started_at", null)
    .is("push_sent_at", null)
    .select("id,user_id,title,body,type,target_type,target_id,localization_args")
    .maybeSingle();

  if (claimError) return json({ error: "Could not claim notification" }, 500);
  if (!notification) return json({ ok: true, skipped: true });

  try {
    const { data: devices, error: deviceError } = await admin
      .from("push_devices")
      .select("id,fcm_token,locale")
      .eq("user_id", notification.user_id)
      .eq("notifications_enabled", true);
    if (deviceError) throw deviceError;

    if (!devices?.length) {
      await admin.from("notifications").update({
        push_sent_at: new Date().toISOString(),
        push_error: "No registered devices",
      }).eq("id", notification.id);
      return json({ ok: true, sent: 0 });
    }

    const account = serviceAccount();
    const accessToken = await googleAccessToken(account);
    let sent = 0;
    const failures: string[] = [];

    for (const device of devices) {
      const copy = localizedCopy(
        notification.type,
        notification.localization_args ?? {},
        device.locale === "tr" ? "tr" : "en",
        { title: notification.title, body: notification.body },
      );
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: device.fcm_token,
              notification: copy,
              data: {
                notification_id: notification.id,
                type: notification.type,
                target_type: notification.target_type,
                target_id: notification.target_id,
              },
              android: {
                priority: "high",
                notification: { channel_id: "clubup_notifications", sound: "default" },
              },
              apns: { payload: { aps: { sound: "default", "content-available": 1 } } },
            },
          }),
        },
      );
      if (response.ok) {
        sent++;
        continue;
      }

      const errorText = await response.text();
      failures.push(`${response.status}:${errorText.slice(0, 180)}`);
      if (response.status === 404 || errorText.includes("UNREGISTERED")) {
        await admin.from("push_devices").delete().eq("id", device.id);
      }
    }

    await admin.from("notifications").update({
      push_sent_at: sent > 0 ? new Date().toISOString() : null,
      push_error: failures.length ? failures.join(" | ").slice(0, 1000) : null,
    }).eq("id", notification.id);

    return json({ ok: failures.length === 0, sent, failed: failures.length });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown push error";
    await admin.from("notifications").update({
      push_started_at: null,
      push_error: message.slice(0, 1000),
    }).eq("id", notification.id);
    return json({ error: "Push delivery failed" }, 500);
  }
});
