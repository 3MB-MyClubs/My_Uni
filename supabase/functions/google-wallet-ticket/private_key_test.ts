import { importWalletPrivateKey } from "./private_key.ts";

Deno.test("Wallet keys copied from Google JSON produce valid RSA signatures", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  const base64 = btoa(String.fromCharCode(...der));
  const pem = "-----BEGIN PRIVATE KEY-----\n" +
    base64.match(/.{1,64}/g)!.join("\n") +
    "\n-----END PRIVATE KEY-----\n";
  const formats = [
    pem,
    " \n" + pem + " \n",
    pem.replaceAll("\n", "\r\n"),
    pem.replaceAll("\n", "\\n"),
    pem.replaceAll("\n", "\\r\\n"),
    JSON.stringify(pem),
    JSON.stringify({ type: "service_account", private_key: pem }),
  ];
  const data = new TextEncoder().encode("wallet-signing-regression-test");
  for (const input of formats) {
    const key = await importWalletPrivateKey(input);
    if (key.extractable) {
      throw new Error("Imported key must not be extractable");
    }
    const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, data);
    if (
      !await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        pair.publicKey,
        signature,
        data,
      )
    ) {
      throw new Error("Signature verification failed");
    }
  }
});

Deno.test("Malformed Wallet keys fail without leaking secret contents", async () => {
  for (
    const input of [
      "",
      "secret-sentinel",
      '"secret-sentinel',
      '{"private_key":"secret-sentinel"}',
      '{"private_key":123}',
      "{}",
      "null",
      "-----BEGIN RSA PRIVATE KEY-----\nAAAA\n-----END RSA PRIVATE KEY-----",
      "-----BEGIN PRIVATE KEY-----\n!!!!\n-----END PRIVATE KEY-----",
      "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----",
    ]
  ) {
    let error: unknown;
    try {
      await importWalletPrivateKey(input);
    } catch (caught) {
      error = caught;
    }
    if (
      !(error instanceof Error) ||
      !error.message.startsWith("GOOGLE_WALLET_PRIVATE_KEY must")
    ) {
      throw new Error("Expected actionable configuration error");
    }
    if (error.message.includes("secret-sentinel")) {
      throw new Error("Secret leaked in error");
    }
  }
});
