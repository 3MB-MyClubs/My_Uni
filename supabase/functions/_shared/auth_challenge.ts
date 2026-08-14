export const challengeLifetimeMs = 10 * 60 * 1000;

export function normalizeEmail(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function isKuEmail(email: string): boolean {
  return /^[a-z0-9._%+-]+@ku\.edu\.tr$/i.test(email);
}

export function generateSixDigitCode(): string {
  // Rejection sampling avoids modulo bias while retaining the existing
  // six-digit UX. 4,294,800,000 is the largest multiple of 900,000 below 2^32.
  const cutoff = 4_294_800_000;
  const random = new Uint32Array(1);
  do crypto.getRandomValues(random); while (random[0] >= cutoff);
  return (100_000 + (random[0] % 900_000)).toString();
}

export function generateCapability(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const binary = Array.from(bytes, (byte) => String.fromCharCode(byte)).join("");
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

export async function sha256Hex(value: string): Promise<string> {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

// TEMPORARY LEGACY COMPATIBILITY — remove after minimum supported app version
// advances. Keeping the released hash domain lets codes issued immediately
// before a rolling Edge Function update remain verifiable by the new v1 code.
export function legacyChallengeCodeHash(
  email: string,
  code: string,
  pepper: string,
): Promise<string> {
  return sha256Hex(`${email}:${code}:${pepper}`);
}

export function challengeCodeHash(
  operation: "signup" | "password-reset",
  email: string,
  code: string,
  pepper: string,
): Promise<string> {
  return sha256Hex(`${operation}:${email}:${code}:${pepper}`);
}

export function capabilityHash(
  operation: "signup" | "password-reset",
  email: string,
  capability: string,
  pepper: string,
): Promise<string> {
  return sha256Hex(`${operation}:${email}:${capability}:${pepper}`);
}

export function getServiceRoleKey(): string | null {
  const direct = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (direct) return direct;

  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return null;
  try {
    return JSON.parse(raw)["default"] ?? null;
  } catch {
    return null;
  }
}
