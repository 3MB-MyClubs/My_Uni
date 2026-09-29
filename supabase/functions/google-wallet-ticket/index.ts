import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const noStore = { "Cache-Control": "no-store" };
const json = (error: string, status: number) =>
  Response.json({ error }, { status, headers: noStore });

function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(name + " is not configured");
  return value;
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

const encode = (value: unknown) => base64url(new TextEncoder().encode(JSON.stringify(value)));

async function signPass(ticket: { id: string; token: string; display_code: string; event_id: string },
  event: { title: string; location: string | null; starts_at: string; ends_at: string | null },
  holder: string): Promise<string> {
  const issuerId = required("GOOGLE_WALLET_ISSUER_ID");
  if (!/^\d+$/.test(issuerId)) throw new Error("Invalid Google Wallet issuer ID");
  const email = required("GOOGLE_WALLET_SERVICE_ACCOUNT_EMAIL");
  const pem = required("GOOGLE_WALLET_PRIVATE_KEY").replaceAll("\\n", "\n");
  const keyBytes = Uint8Array.from(
    atob(pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "")),
    (char) => char.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8", keyBytes, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const classId = issuerId + ".event_" + ticket.event_id.replaceAll("-", "_");
  const objectId = issuerId + ".ticket_" + ticket.id.replaceAll("-", "_");
  const claims = {
    iss: email,
    aud: "google",
    typ: "savetowallet",
    iat: Math.floor(Date.now() / 1000),
    origins: [],
    payload: {
      eventTicketClasses: [{
        id: classId,
        eventId: classId,
        issuerName: "ClupUp",
        eventName: { defaultValue: { language: "en-US", value: event.title } },
        logo: { sourceUri: { uri: "https://3mb-myclubs.github.io/My_Uni/assets/app-icon.png" } },
        hexBackgroundColor: "#242e4d",
        multipleDevicesAndHoldersAllowedStatus: "ONE_USER_ALL_DEVICES",
        dateTime: { start: event.starts_at, ...(event.ends_at ? { end: event.ends_at } : {}) },
        ...(event.location ? {
          venue: {
            name: { defaultValue: { language: "en-US", value: event.location } },
            address: { defaultValue: { language: "en-US", value: event.location } },
          },
        } : {}),
        reviewStatus: "UNDER_REVIEW",
      }],
      eventTicketObjects: [{
        id: objectId,
        classId,
        state: "ACTIVE",
        ticketHolderName: holder,
        ticketNumber: ticket.display_code,
        barcode: {
          type: "QR_CODE",
          value: "clubup-ticket:v1:" + ticket.token,
          alternateText: ticket.display_code,
        },
      }],
    },
  };
  const unsigned = encode({ alg: "RS256", typ: "JWT" }) + "." + encode(claims);
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key,
    new TextEncoder().encode(unsigned)));
  return unsigned + "." + base64url(signature);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json("Method not allowed", 405);
  const auth = request.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return json("Authentication required", 401);
  let ticketId: unknown;
  try {
    ticketId = (await request.json()).ticketId;
  } catch {
    return json("Invalid request", 400);
  }
  if (typeof ticketId !== "string" || !uuid.test(ticketId)) return json("Invalid ticket ID", 400);

  try {
    const client = createClient(required("SUPABASE_URL"), required("SUPABASE_ANON_KEY"),
      { global: { headers: { Authorization: auth } } });
    const { data: userData, error: userError } = await client.auth.getUser(auth.slice(7));
    if (userError || !userData.user) return json("Authentication required", 401);

    // Staff can read tickets through RLS; only the holder can export one.
    const { data: ticket, error: ticketError } = await client.from("event_tickets")
      .select("id,token,display_code,event_id,profile_id")
      .eq("id", ticketId).eq("profile_id", userData.user.id)
      .is("revoked_at", null).is("used_at", null).maybeSingle();
    if (ticketError) throw ticketError;
    if (!ticket) return json("Active ticket not found", 404);

    const { data: event, error: eventError } = await client.from("events")
      .select("title,location,starts_at,ends_at,is_ticketed")
      .eq("id", ticket.event_id).maybeSingle();
    if (eventError) throw eventError;
    if (!event?.is_ticketed) return json("Active ticket not found", 404);

    const { data: profile, error: profileError } = await client.from("profiles")
      .select("full_name").eq("id", userData.user.id).maybeSingle();
    if (profileError) throw profileError;
    const jwt = await signPass(ticket, event, profile?.full_name?.trim() || "Attendee");
    return Response.json({ jwt }, { headers: noStore });
  } catch (error) {
    console.error("Google Wallet ticket generation failed", error);
    return json("Could not create Google Wallet ticket", 500);
  }
});
