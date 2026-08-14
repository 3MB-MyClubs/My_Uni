import {
  capabilityHash,
  challengeCodeHash,
  generateCapability,
  generateSixDigitCode,
  normalizeEmail,
} from "./auth_challenge.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("six-digit codes stay within the supported unbiased range", () => {
  for (let index = 0; index < 2_000; index++) {
    assert(/^\d{6}$/.test(generateSixDigitCode()), "code must contain six digits");
  }
});

Deno.test("capabilities contain 256 bits encoded as unpadded base64url", () => {
  const first = generateCapability();
  const second = generateCapability();
  assert(/^[A-Za-z0-9_-]{43}$/.test(first), "capability format is invalid");
  assert(first !== second, "independent capabilities must differ");
});

Deno.test("hashes are bound to operation and normalized account", async () => {
  const email = normalizeEmail(" Student@KU.EDU.TR ");
  const signup = await challengeCodeHash("signup", email, "123456", "pepper");
  const reset = await challengeCodeHash(
    "password-reset",
    email,
    "123456",
    "pepper",
  );
  const capability = await capabilityHash(
    "signup",
    email,
    "one-time-secret",
    "pepper",
  );

  assert(email === "student@ku.edu.tr", "email must be normalized");
  assert(signup.length === 64, "SHA-256 hashes must be hexadecimal");
  assert(signup !== reset, "operation prefixes must create distinct hashes");
  assert(signup !== capability, "code and capability inputs must be distinct");
});
