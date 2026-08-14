import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

type Cleanup = {
  id: string;
  lease_token: string;
  bucket_id: string;
  object_path: string;
};

const json = (body: unknown, status = 200) => Response.json(body, {
  status,
  headers: { "Cache-Control": "no-store" },
});

function retryableStatus(status?: number): boolean {
  return status === undefined || status === 408 || status === 429 || status >= 500;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const expectedSecret = Deno.env.get("STORAGE_CLEANUP_WORKER_SECRET");
  if (!expectedSecret || request.headers.get("x-worker-secret") !== expectedSecret) {
    return json({ error: "Unauthorized" }, 401);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json({ error: "Runtime is not configured" }, 500);
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin.rpc("claim_storage_cleanup_v2", {
    p_worker: `edge:${crypto.randomUUID()}`,
    p_limit: 25,
    p_lease_seconds: 90,
  });
  if (error) return json({ error: "Cleanup claim failed" }, 500);

  const items = (data ?? []) as Cleanup[];
  const outcomes = await Promise.all(items.map(async (item) => {
    const { data: referenced, error: referenceError } = await admin.rpc(
      "storage_cleanup_is_referenced_v2",
      { p_cleanup_id: item.id, p_lease_token: item.lease_token },
    );
    if (referenceError) {
      await admin.rpc("complete_storage_cleanup_worker_v2", {
        p_cleanup_id: item.id, p_lease_token: item.lease_token,
        p_outcome: "retryable", p_error_category: "reference_check",
        p_error: referenceError.message,
      });
      return "retryable";
    }
    if (referenced === true) {
      await admin.rpc("complete_storage_cleanup_worker_v2", {
        p_cleanup_id: item.id, p_lease_token: item.lease_token,
        p_outcome: "referenced", p_error_category: null, p_error: null,
      });
      return "referenced";
    }

    const { error: removeError } = await admin.storage
      .from(item.bucket_id)
      .remove([item.object_path]);
    if (!removeError) {
      await admin.rpc("complete_storage_cleanup_worker_v2", {
        p_cleanup_id: item.id, p_lease_token: item.lease_token,
        p_outcome: "deleted", p_error_category: null, p_error: null,
      });
      return "deleted";
    }
    const status = Number(removeError.statusCode);
    const retryable = retryableStatus(Number.isFinite(status) ? status : undefined);
    await admin.rpc("complete_storage_cleanup_worker_v2", {
      p_cleanup_id: item.id, p_lease_token: item.lease_token,
      p_outcome: retryable ? "retryable" : "permanent",
      p_error_category: retryable ? "storage_transient" : "storage_permanent",
      p_error: removeError.message,
    });
    return retryable ? "retryable" : "terminal";
  }));

  const summary = {
    claimed: items.length,
    deleted: outcomes.filter((value) => value === "deleted").length,
    referenced: outcomes.filter((value) => value === "referenced").length,
    retryable: outcomes.filter((value) => value === "retryable").length,
    terminal: outcomes.filter((value) => value === "terminal").length,
  };
  console.log(JSON.stringify({ event: "storage_cleanup_v2_run", ...summary }));
  return json({ ok: true, ...summary });
});
