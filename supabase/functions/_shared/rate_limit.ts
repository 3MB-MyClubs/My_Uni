interface RpcError {
  message?: string;
  code?: string;
}

interface RateLimitRpcClient {
  rpc(
    fn: "consume_edge_rate_limit",
    args: { p_action: string; p_scope: string },
  ): PromiseLike<{ data: unknown; error: RpcError | null }>;
}

interface RateLimitRow {
  allowed: boolean;
  retry_after_seconds: number;
  limiting_window: "burst" | "sustained" | "both" | null;
}

export interface EdgeRateLimitDecision extends RateLimitRow {
  action: string;
}

export class RateLimitUnavailableError extends Error {
  constructor(message = "Rate-limit enforcement unavailable") {
    super(message);
    this.name = "RateLimitUnavailableError";
  }
}

function normalizedAddress(value: string | null): string | null {
  const candidate = value?.split(",", 1)[0]?.trim() ?? "";
  if (!candidate || candidate.length > 64) return null;

  // Supabase's gateway supplies these headers. Accept only address characters,
  // never arbitrary forwarded text, and hash the value inside Postgres.
  return /^[0-9a-f:.]+$/i.test(candidate) ? candidate.toLowerCase() : null;
}

export function edgeClientAddress(request: Request): string | null {
  return normalizedAddress(request.headers.get("cf-connecting-ip")) ??
    normalizedAddress(request.headers.get("x-real-ip")) ??
    normalizedAddress(request.headers.get("x-forwarded-for"));
}

function rowFrom(data: unknown): RateLimitRow {
  const value = Array.isArray(data) ? data[0] : data;
  if (!value || typeof value !== "object") {
    throw new Error("Rate-limit RPC returned no decision");
  }

  const row = value as Record<string, unknown>;
  if (typeof row.allowed !== "boolean") {
    throw new Error("Rate-limit RPC returned an invalid decision");
  }
  return {
    allowed: row.allowed,
    retry_after_seconds: Math.max(
      0,
      Number.isFinite(Number(row.retry_after_seconds))
        ? Math.ceil(Number(row.retry_after_seconds))
        : 0,
    ),
    limiting_window:
      row.limiting_window === "burst" ||
        row.limiting_window === "sustained" ||
        row.limiting_window === "both"
        ? row.limiting_window
        : null,
  };
}

async function consume(
  client: RateLimitRpcClient,
  action: string,
  scope: string,
): Promise<EdgeRateLimitDecision> {
  const { data, error } = await client.rpc("consume_edge_rate_limit", {
    p_action: action,
    p_scope: scope,
  });
  if (error) {
    console.error("rate-limit enforcement unavailable", {
      action,
      code: error.code ?? "unknown",
    });
    throw new RateLimitUnavailableError(
      error.message ?? "Rate-limit enforcement unavailable",
    );
  }
  try {
    return { action, ...rowFrom(data) };
  } catch {
    console.error("rate-limit enforcement returned an invalid decision", {
      action,
    });
    throw new RateLimitUnavailableError();
  }
}

/**
 * Enforces an IP bucket plus a tighter IP+identity/resource bucket.
 *
 * `identity` must already be normalized by the caller. Raw scope material is
 * sent only over the service-role database connection and is SHA-256 hashed
 * before persistence. No caller-supplied actor id is accepted.
 */
export async function enforceEdgeRateLimit(
  client: RateLimitRpcClient,
  request: Request,
  actionBase: string,
  identity: string,
  identityDimension: "identity" | "resource" = "identity",
): Promise<EdgeRateLimitDecision | null> {
  const address = edgeClientAddress(request);

  // Avoid a shared "unknown IP" bucket if a local/dev gateway provides no
  // network header. The identity bucket remains enforced in that environment.
  if (address) {
    const ipDecision = await consume(client, `${actionBase}:ip`, `ip=${address}`);
    if (!ipDecision.allowed) return ipDecision;
  }

  const scopedDecision = await consume(
    client,
    `${actionBase}:${identityDimension}`,
    `ip=${address ?? "unavailable"}|${identityDimension}=${identity}`,
  );
  return scopedDecision.allowed ? null : scopedDecision;
}

export function rateLimitResponse(
  decision: EdgeRateLimitDecision,
  corsHeaders: Record<string, string>,
): Response {
  const retryAfter = Math.max(1, decision.retry_after_seconds);
  return new Response(
    JSON.stringify({
      error: "rate_limit_exceeded",
      message: "Too many requests. Try again later.",
      retry_after_seconds: retryAfter,
    }),
    {
      status: 429,
      headers: {
        ...corsHeaders,
        "Access-Control-Expose-Headers": "Retry-After",
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
        "Retry-After": String(retryAfter),
      },
    },
  );
}
