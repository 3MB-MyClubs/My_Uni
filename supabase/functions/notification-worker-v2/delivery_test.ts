import { classifyFcmFailure } from "./delivery.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

Deno.test("classifies invalid tokens as terminal and removable", () => {
  assertEquals(classifyFcmFailure(404, '{"error":{"status":"UNREGISTERED"}}'), {
    outcome: "terminal", code: "invalid_token", invalidateToken: true,
  });
});

Deno.test("classifies transient provider failures as retryable", () => {
  assertEquals(classifyFcmFailure(503, "unavailable"), {
    outcome: "retryable", code: "fcm_503", invalidateToken: false,
  });
  assertEquals(classifyFcmFailure(429, "quota"), {
    outcome: "retryable", code: "fcm_429", invalidateToken: false,
  });
});

Deno.test("classifies malformed payloads as terminal without deleting token", () => {
  assertEquals(classifyFcmFailure(400, "INVALID_ARGUMENT"), {
    outcome: "terminal", code: "invalid_payload", invalidateToken: false,
  });
});
