const configurationError = () =>
  new Error(
    "GOOGLE_WALLET_PRIVATE_KEY must contain a valid PKCS#8 PEM private key, " +
      "a JSON-quoted private_key value, or a service-account JSON object",
  );

/** Accept the formats commonly copied from Google's downloaded JSON key. */
export async function importWalletPrivateKey(
  value: string,
): Promise<CryptoKey> {
  try {
    let pem = value.trim();
    if (pem.startsWith('"') || pem.startsWith("{")) {
      const parsed: unknown = JSON.parse(pem);
      const key = typeof parsed === "string"
        ? parsed
        : parsed && typeof parsed === "object" && "private_key" in parsed
        ? parsed.private_key
        : undefined;
      if (typeof key !== "string") throw configurationError();
      pem = key.trim();
    }
    pem = pem.replaceAll("\\r", "\r").replaceAll("\\n", "\n").trim();
    const match =
      /^-----BEGIN PRIVATE KEY-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END PRIVATE KEY-----$/
        .exec(pem);
    if (!match) throw configurationError();
    const bytes = Uint8Array.from(
      atob(match[1].replace(/\s/g, "")),
      (char) => char.charCodeAt(0),
    );
    return await crypto.subtle.importKey(
      "pkcs8",
      bytes,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
  } catch {
    // Never include the supplied secret or a JSON parser excerpt in logs.
    throw configurationError();
  }
}
