import "jsr:@std/dotenv/load";
import { assertEquals } from "jsr:@std/assert";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ??
  "http://127.0.0.1:54321";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

async function consume(scope: string): Promise<boolean> {
  if (!serviceRoleKey) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY is required");
  }
  const response = await fetch(
    `${supabaseUrl}/rest/v1/rpc/consume_edge_rate_limit`,
    {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        p_action: "auth_signup_request:identity",
        p_scope: scope,
      }),
    },
  );
  if (!response.ok) {
    throw new Error(`Rate-limit RPC failed with ${response.status}`);
  }
  const data = await response.json();
  return (Array.isArray(data) ? data[0] : data)?.allowed === true;
}

Deno.test("parallel requests cannot exceed the atomic bucket capacity", async () => {
  const scope = `concurrency-${crypto.randomUUID()}`;
  const decisions = await Promise.all(
    Array.from({ length: 40 }, () => consume(scope)),
  );

  assertEquals(decisions.filter((allowed) => allowed).length, 3);
  assertEquals(decisions.filter((allowed) => !allowed).length, 37);

  // A separate identity remains isolated even while the first is exhausted.
  assertEquals(await consume(`${scope}-other-user`), true);
});
