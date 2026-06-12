// Supabase Edge Function: delete-account
//
// App Store Guideline 5.1.1(v) requires in-app account deletion for apps with
// account creation. This function deletes the AUTHENTICATED caller's account:
//   1. Verifies the caller's Supabase JWT (no anon-key calls).
//   2. Removes their personal rows (profile, device tokens, Microsoft
//      connection/tokens) — other tables cascade from auth.users where FKs
//      exist, and remaining rows keyed by text ids are cleaned best-effort.
//   3. Deletes the auth.users row via the admin API, which invalidates all
//      sessions immediately.
//
// POST with Authorization: Bearer <user access token>. No body required.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const admin = createClient(SUPABASE_URL, SERVICE_KEY);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return json({ error: "server not configured" }, 500);
  }

  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  if (!token || token === ANON_KEY) return json({ error: "unauthorized" }, 401);

  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user?.id) return json({ error: "unauthorized" }, 401);

  const uid = data.user.id;
  const uidLower = uid.toLowerCase();

  // Best-effort cleanup of personal rows keyed by text ids (no FK cascade).
  const cleanup: Array<{ table: string; column: string; value: string }> = [
    { table: "device_tokens", column: "user_id", value: uidLower },
    { table: "profiles", column: "id", value: uidLower },
    { table: "microsoft_connections", column: "user_id", value: uid },
    { table: "microsoft_accounts", column: "user_id", value: uid },
  ];
  for (const { table, column, value } of cleanup) {
    const { error: delError } = await admin.from(table).delete().eq(column, value);
    if (delError) console.warn(`[delete-account] cleanup ${table} failed:`, delError.message);
  }

  const { error: authError } = await admin.auth.admin.deleteUser(uid);
  if (authError) {
    console.error("[delete-account] auth delete failed:", authError.message);
    return json({ error: "delete_failed", message: "Could not delete the account." }, 500);
  }

  console.log(`[delete-account] account ${uidLower} deleted`);
  return json({ deleted: true });
});
