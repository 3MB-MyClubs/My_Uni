import "jsr:@supabase/functions-js@2.112.3/edge-runtime.d.ts";
import { Buffer } from "node:buffer";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { PKPass } from "npm:passkit-generator@3.6.0";
import { iconPng, icon2xPng, icon3xPng } from "./icons.ts";
import { wwdrPem } from "./wwdr.ts";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const noStore = { "Cache-Control": "no-store" };
const json = (error: string, status: number) =>
  Response.json({ error }, { status, headers: noStore });

function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function certificate(name: string): Buffer {
  return Buffer.from(required(name), "base64");
}

type TicketRow = {
  id: string;
  token: string;
  display_code: string;
  event_id: string;
  profile_id: string;
};

type EventRow = {
  title: string;
  location: string | null;
  starts_at: string;
  ends_at: string | null;
  is_ticketed: boolean;
};

function createPass(ticket: TicketRow, event: EventRow, holder: string): Buffer {
  const passJson = {
    formatVersion: 1,
    passTypeIdentifier: required("APPLE_WALLET_PASS_TYPE_ID"),
    teamIdentifier: required("APPLE_WALLET_TEAM_ID"),
    organizationName: "ClupUp",
    description: `${event.title} admission ticket`,
    serialNumber: ticket.id,
    sharingProhibited: true,
    logoText: "ClupUp",
    foregroundColor: "rgb(255, 255, 255)",
    backgroundColor: "rgb(36, 46, 77)",
    relevantDate: event.starts_at,
    expirationDate: event.ends_at ?? undefined,
    eventTicket: {
      primaryFields: [{ key: "event", label: "EVENT", value: event.title }],
      secondaryFields: [
        { key: "holder", label: "ATTENDEE", value: holder },
        { key: "ticketCode", label: "TICKET CODE", value: ticket.display_code },
      ],
      auxiliaryFields: event.location
        ? [{ key: "location", label: "LOCATION", value: event.location }]
        : [],
      backFields: [{
        key: "admission",
        label: "ADMISSION",
        value: "Show this ticket at entry. A revoked or used ticket cannot be admitted.",
      }],
    },
    barcodes: [{
      format: "PKBarcodeFormatQR",
      message: `clubup-ticket:v1:${ticket.token}`,
      messageEncoding: "iso-8859-1",
      altText: ticket.display_code,
    }],
  };
  const pass = new PKPass(
    {
      "pass.json": Buffer.from(JSON.stringify(passJson)),
      "icon.png": Buffer.from(iconPng, "base64"),
      "icon@2x.png": Buffer.from(icon2xPng, "base64"),
      "icon@3x.png": Buffer.from(icon3xPng, "base64"),
    },
    {
      wwdr: wwdrPem,
      signerCert: certificate("APPLE_WALLET_SIGNER_CERT_B64"),
      signerKey: certificate("APPLE_WALLET_SIGNER_KEY_B64"),
      signerKeyPassphrase: Deno.env.get("APPLE_WALLET_KEY_PASSPHRASE") ?? undefined,
    },
  );
  return pass.getAsBuffer();
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
  if (typeof ticketId !== "string" || !uuid.test(ticketId)) {
    return json("Invalid ticket ID", 400);
  }

  try {
    const client = createClient(
      required("SUPABASE_URL"),
      required("SUPABASE_ANON_KEY"),
      { global: { headers: { Authorization: auth } } },
    );
    const { data: userData, error: userError } = await client.auth.getUser(
      auth.slice("Bearer ".length),
    );
    if (userError || !userData.user) return json("Authentication required", 401);

    // RLS also lets staff read tickets. The explicit owner predicate prevents
    // staff from exporting another person's bearer credential to Wallet.
    const { data: ticket, error: ticketError } = await client
      .from("event_tickets")
      .select("id,token,display_code,event_id,profile_id")
      .eq("id", ticketId)
      .eq("profile_id", userData.user.id)
      .is("revoked_at", null)
      .is("used_at", null)
      .maybeSingle();
    if (ticketError) throw ticketError;
    if (!ticket) return json("Active ticket not found", 404);

    const { data: event, error: eventError } = await client
      .from("events")
      .select("title,location,starts_at,ends_at,is_ticketed")
      .eq("id", ticket.event_id)
      .maybeSingle();
    if (eventError) throw eventError;
    if (!event?.is_ticketed) return json("Active ticket not found", 404);

    const { data: profile, error: profileError } = await client
      .from("profiles")
      .select("full_name")
      .eq("id", userData.user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    const pass = createPass(
      ticket as TicketRow,
      event as EventRow,
      profile?.full_name?.trim() || "Attendee",
    );
    return new Response(new Uint8Array(pass), {
      status: 200,
      headers: {
        ...noStore,
        "Content-Type": "application/octet-stream",
        "Content-Disposition": 'attachment; filename="clupup-event-ticket.pkpass"',
      },
    });
  } catch (error) {
    // Signing errors and secrets must never be returned to the caller.
    console.error("Apple Wallet ticket generation failed", error);
    return json("Could not create Apple Wallet ticket", 500);
  }
});
