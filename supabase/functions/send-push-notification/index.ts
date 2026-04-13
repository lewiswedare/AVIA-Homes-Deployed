// Supabase Edge Function: send-push-notification
// Triggered by a Postgres webhook on INSERT to the `notifications` table.
// Sends an APNs push notification to the recipient's device.
//
// Required env vars for APNs:
//   APNS_KEY_ID       — Apple Key ID
//   APNS_TEAM_ID      — Apple Team ID
//   APNS_PRIVATE_KEY  — p8 private key contents (PEM)
//   APNS_BUNDLE_ID    — e.g. com.aviahomes.app
//   APNS_ENVIRONMENT  — "production" or "development" (default: "production")
//
// Required env var for Supabase:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY — automatically available in Edge Functions

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: {
    record?: {
      recipient_id?: string;
      title?: string;
      message?: string;
      body?: string;
      type?: string;
    };
  };

  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const record = payload.record;
  if (!record?.recipient_id) {
    return new Response(JSON.stringify({ error: "missing recipient_id" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const recipientId = record.recipient_id;
  const title = record.title || "AVIA Homes";
  const body = record.body || record.message || "You have a new notification";
  const notificationType = record.type || "general";

  // Initialize Supabase client with service role key
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !supabaseServiceKey) {
    console.warn("[send-push-notification] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return new Response(JSON.stringify({ warning: "Supabase not configured" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // Fetch device tokens for recipient
  const { data: tokens, error: tokenError } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", recipientId);

  if (tokenError) {
    console.error("[send-push-notification] Error fetching tokens:", tokenError);
    return new Response(JSON.stringify({ error: "Failed to fetch device tokens" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!tokens || tokens.length === 0) {
    console.log(`[send-push-notification] No device tokens for user ${recipientId}`);
    return new Response(JSON.stringify({ info: "No device tokens found" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Check for APNs credentials
  const apnsKeyId = Deno.env.get("APNS_KEY_ID");
  const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
  const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.aviahomes.app";
  const apnsEnvironment = Deno.env.get("APNS_ENVIRONMENT") ?? "production";

  if (!apnsKeyId || !apnsTeamId || !apnsPrivateKey) {
    console.warn(
      "[send-push-notification] APNs credentials not configured (APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY). " +
      "Push notifications will not be sent. Set these env vars to enable APNs delivery."
    );
    return new Response(
      JSON.stringify({ warning: "APNs credentials not configured, push skipped" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }

  // Build JWT for APNs authentication
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "ES256", kid: apnsKeyId }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const claims = btoa(JSON.stringify({ iss: apnsTeamId, iat: now }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const signingInput = `${header}.${claims}`;
  const keyData = apnsPrivateKey
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  let jwt: string;
  try {
    const rawKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      rawKey,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"]
    );
    const signature = await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      cryptoKey,
      new TextEncoder().encode(signingInput)
    );
    const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    jwt = `${signingInput}.${sigB64}`;
  } catch (err) {
    console.error("[send-push-notification] Failed to sign APNs JWT:", err);
    return new Response(JSON.stringify({ error: "APNs JWT signing failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const apnsHost =
    apnsEnvironment === "development"
      ? "https://api.sandbox.push.apple.com"
      : "https://api.push.apple.com";

  const apnsPayload = JSON.stringify({
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1,
    },
    notification_type: notificationType,
  });

  const results: Array<{ token: string; status: number; body?: string }> = [];

  for (const { token } of tokens) {
    try {
      const res = await fetch(`${apnsHost}/3/device/${token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": apnsBundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: apnsPayload,
      });
      const resBody = res.ok ? undefined : await res.text();
      results.push({ token: token.substring(0, 8) + "...", status: res.status, body: resBody });
    } catch (err) {
      results.push({ token: token.substring(0, 8) + "...", status: 0, body: String(err) });
    }
  }

  console.log("[send-push-notification] Results:", JSON.stringify(results));

  return new Response(JSON.stringify({ sent: results.length, results }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
