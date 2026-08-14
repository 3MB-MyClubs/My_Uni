export type DeliveryOutcome = "delivered" | "retryable" | "terminal";

export function classifyFcmFailure(status: number, body: string): {
  outcome: DeliveryOutcome; code: string; invalidateToken: boolean;
} {
  const upper = body.toUpperCase();
  if (status === 404 || upper.includes("UNREGISTERED") || upper.includes("NOT_FOUND")) {
    return { outcome: "terminal", code: "invalid_token", invalidateToken: true };
  }
  if (status === 400 || upper.includes("INVALID_ARGUMENT")) {
    return { outcome: "terminal", code: "invalid_payload", invalidateToken: false };
  }
  if (status === 401 || status === 403) {
    return { outcome: "retryable", code: "provider_auth", invalidateToken: false };
  }
  if (status === 408 || status === 429 || status >= 500) {
    return { outcome: "retryable", code: `fcm_${status}`, invalidateToken: false };
  }
  return { outcome: "terminal", code: `fcm_${status}`, invalidateToken: false };
}
