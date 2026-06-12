// Supabase Edge Function: microsoft-mail
//
// Lets AVIA staff send email AS THEMSELVES from their real Microsoft 365 / Outlook
// account (delegated Microsoft Graph `sendMail`, saveToSentItems=true), plus tracks
// when clients open those emails via a 1x1 pixel.
//
// Routes (single function, dispatched by path / `action` query):
//   POST ...?action=start                        → { url } Microsoft consent URL (signed state)
//   GET  .../callback?code=..&state=..           → verifies signed state, token exchange,
//                                                   bounces back to app (aviahomes://ms-connected)
//   GET  ...?action=status&uid=<staffId>         → { connected, email, display_name }
//   POST ...?action=send  { staff_id, client_id, to, subject, body, document_url?,
//                           document_name?, document_id? }  → sends + records email_sends row
//   POST ...?action=disconnect { uid }           → removes the stored connection
//   GET  .../track/<sendId>                       → 1x1 gif, records the open
//
// SECURITY: start/status/send/disconnect REQUIRE a valid Supabase user JWT in the
// Authorization header, and the user must hold a staff-tier role. The OAuth state
// is HMAC-signed so the callback cannot be forged for an arbitrary uid.
//
// Required Supabase Edge Function secrets (set in the Supabase dashboard):
//   MS_CLIENT_ID       — Azure app (client) ID
//   MS_CLIENT_SECRET   — Azure client secret value
//   MS_TENANT_ID       — Azure directory (tenant) ID, or "common"
//   APP_CALLBACK_SCHEME — optional, defaults to "aviahomes" (the in-app return scheme)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY — provided automatically.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GRAPH = "https://graph.microsoft.com/v1.0";
const SCOPES = "offline_access User.Read Mail.Send";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MS_CLIENT_ID = Deno.env.get("MS_CLIENT_ID") ?? "";
const MS_CLIENT_SECRET = Deno.env.get("MS_CLIENT_SECRET") ?? "";
const MS_TENANT_ID = Deno.env.get("MS_TENANT_ID") ?? "common";
const APP_SCHEME = Deno.env.get("APP_CALLBACK_SCHEME") ?? "aviahomes";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

function functionBaseURL(req: Request): string {
  // e.g. https://<project>.supabase.co/functions/v1/microsoft-mail
  const url = new URL(req.url);
  const idx = url.pathname.indexOf("/microsoft-mail");
  const base = idx >= 0 ? url.pathname.slice(0, idx + "/microsoft-mail".length) : url.pathname;
  return `${url.origin}${base}`;
}

function tokenEndpoint(): string {
  return `https://login.microsoftonline.com/${MS_TENANT_ID}/oauth2/v2.0/token`;
}

function authorizeEndpoint(): string {
  return `https://login.microsoftonline.com/${MS_TENANT_ID}/oauth2/v2.0/authorize`;
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

// ── Auth helpers ──────────────────────────────────────────────────────────────────

const STAFF_ROLES = new Set([
  "admin", "superadmin", "super_admin", "super admin",
  "salesadmin", "sales_admin", "sales admin",
  "staff", "preconstruction", "pre_construction",
  "buildingsupport", "building_support",
  "partner", "salespartner", "sales_partner",
]);

const ADMIN_ROLES = new Set([
  "admin", "superadmin", "super_admin", "super admin",
  "salesadmin", "sales_admin", "sales admin",
]);

interface AuthedUser {
  uid: string;
  role: string;
  isStaff: boolean;
  isAdmin: boolean;
}

/// Verifies the caller's Supabase JWT and loads their profile role.
/// Returns null when the token is missing, invalid, or the anon key itself.
async function requireUser(req: Request): Promise<AuthedUser | null> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!token || token === anonKey) return null;

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user?.id) return null;

  const uid = data.user.id.toLowerCase();
  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", uid)
    .maybeSingle();

  const role = (profile?.role ?? "").toLowerCase();
  return {
    uid,
    role,
    isStaff: STAFF_ROLES.has(role),
    isAdmin: ADMIN_ROLES.has(role),
  };
}

// ── Signed OAuth state (HMAC-SHA256 keyed with MS_CLIENT_SECRET) ─────────────

async function hmacHex(message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(MS_CLIENT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function signState(uid: string): Promise<string> {
  const exp = Date.now() + 15 * 60 * 1000; // 15 minute window
  const sig = await hmacHex(`${uid}.${exp}`);
  return `${uid}.${exp}.${sig}`;
}

/// Returns the uid when the state is authentic and unexpired, else null.
async function verifyState(state: string): Promise<string | null> {
  const parts = state.split(".");
  if (parts.length !== 3) return null;
  const [uid, expStr, sig] = parts;
  const exp = Number(expStr);
  if (!uid || !Number.isFinite(exp) || Date.now() > exp) return null;
  const expected = await hmacHex(`${uid}.${exp}`);
  return sig === expected ? uid : null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

// 1x1 transparent GIF
const PIXEL = Uint8Array.from([
  0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00,
  0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x21, 0xf9, 0x04, 0x01, 0x00, 0x00, 0x00,
  0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02,
  0x44, 0x01, 0x00, 0x3b,
]);

function pixelResponse(): Response {
  return new Response(PIXEL, {
    status: 200,
    headers: {
      "Content-Type": "image/gif",
      "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
      "Pragma": "no-cache",
      "Expires": "0",
    },
  });
}

async function refreshAccessToken(refreshToken: string, redirectUri: string) {
  const params = new URLSearchParams({
    client_id: MS_CLIENT_ID,
    client_secret: MS_CLIENT_SECRET,
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    redirect_uri: redirectUri,
    scope: SCOPES,
  });
  const res = await fetch(tokenEndpoint(), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });
  if (!res.ok) {
    throw new Error(`refresh failed ${res.status}: ${await res.text()}`);
  }
  return await res.json();
}

// ── Handlers ───────────────────────────────────────────────────────────────────

async function handleStart(req: Request): Promise<Response> {
  const user = await requireUser(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  if (!user.isStaff) return json({ error: "forbidden" }, 403);
  if (!MS_CLIENT_ID) return json({ error: "MS_CLIENT_ID not configured" }, 500);

  // The mailbox always connects to the AUTHENTICATED user — never a caller-
  // supplied uid — and the state is signed so the callback can't be forged.
  const state = await signState(user.uid);
  const redirectUri = `${functionBaseURL(req)}/callback`;
  const authUrl = new URL(authorizeEndpoint());
  authUrl.searchParams.set("client_id", MS_CLIENT_ID);
  authUrl.searchParams.set("response_type", "code");
  authUrl.searchParams.set("redirect_uri", redirectUri);
  authUrl.searchParams.set("response_mode", "query");
  authUrl.searchParams.set("scope", SCOPES);
  authUrl.searchParams.set("state", state);
  authUrl.searchParams.set("prompt", "select_account");

  return json({ url: authUrl.toString() });
}

function htmlBounce(message: string, success: boolean): Response {
  const target = `${APP_SCHEME}://ms-${success ? "connected" : "failed"}`;
  const body = `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="0;url=${target}">
<style>body{font-family:-apple-system,system-ui,sans-serif;background:#f5f1ea;color:#3a3027;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center}
.card{padding:32px}a{color:#8a6d4f;font-weight:600}</style></head>
<body><div class="card"><h2>${message}</h2>
<p>You can return to AVIA Homes.</p>
<p><a href="${target}">Tap here if you're not redirected.</a></p>
<script>location.href=${JSON.stringify(target)};</script></div></body></html>`;
  return new Response(body, { status: 200, headers: { "Content-Type": "text/html" } });
}

async function handleCallback(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state") ?? "";
  const err = url.searchParams.get("error_description") ?? url.searchParams.get("error");
  if (err) {
    console.error("[microsoft-mail] callback error:", err);
    return htmlBounce("Couldn't connect Microsoft", false);
  }
  const uid = state ? await verifyState(state) : null;
  if (!code || !uid) return htmlBounce("Couldn't connect Microsoft", false);

  const redirectUri = `${functionBaseURL(req)}/callback`;
  try {
    const params = new URLSearchParams({
      client_id: MS_CLIENT_ID,
      client_secret: MS_CLIENT_SECRET,
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri,
      scope: SCOPES,
    });
    const tokRes = await fetch(tokenEndpoint(), {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: params.toString(),
    });
    if (!tokRes.ok) {
      console.error("[microsoft-mail] token exchange failed:", await tokRes.text());
      return htmlBounce("Couldn't connect Microsoft", false);
    }
    const tok = await tokRes.json();

    // Identify the connected mailbox.
    const meRes = await fetch(`${GRAPH}/me`, {
      headers: { Authorization: `Bearer ${tok.access_token}` },
    });
    const me = meRes.ok ? await meRes.json() : {};
    const email: string = me.mail ?? me.userPrincipalName ?? "";
    const displayName: string = me.displayName ?? "";
    const msUserId: string = me.id ?? "";

    const expiresAt = new Date(Date.now() + (tok.expires_in ?? 3600) * 1000).toISOString();

    await supabase.from("microsoft_connections").upsert({
      user_id: uid,
      ms_user_id: msUserId,
      email,
      display_name: displayName,
      refresh_token: tok.refresh_token,
      access_token: tok.access_token,
      token_expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    });
    await supabase.from("microsoft_accounts").upsert({
      user_id: uid,
      email,
      display_name: displayName,
      connected_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });

    return htmlBounce("Microsoft connected", true);
  } catch (e) {
    console.error("[microsoft-mail] callback exception:", e);
    return htmlBounce("Couldn't connect Microsoft", false);
  }
}

async function handleStatus(req: Request): Promise<Response> {
  const user = await requireUser(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  if (!user.isStaff) return json({ error: "forbidden" }, 403);
  const url = new URL(req.url);
  const uid = (url.searchParams.get("uid") ?? user.uid).toLowerCase();
  const { data } = await supabase
    .from("microsoft_accounts")
    .select("email, display_name, connected_at")
    .eq("user_id", uid)
    .maybeSingle();
  return json({
    connected: !!data,
    email: data?.email ?? null,
    display_name: data?.display_name ?? null,
    connected_at: data?.connected_at ?? null,
  });
}

async function handleDisconnect(req: Request): Promise<Response> {
  const user = await requireUser(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  let body: { uid?: string } = {};
  try {
    body = await req.json();
  } catch { /* ignore */ }
  const uid = (body.uid ?? user.uid).toLowerCase();
  // Staff can only disconnect their own mailbox; admins may disconnect anyone's.
  if (uid !== user.uid && !user.isAdmin) return json({ error: "forbidden" }, 403);
  await supabase.from("microsoft_connections").delete().eq("user_id", uid);
  await supabase.from("microsoft_accounts").delete().eq("user_id", uid);
  return json({ disconnected: true });
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

async function handleSend(req: Request): Promise<Response> {
  const user = await requireUser(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  if (!user.isStaff) return json({ error: "forbidden" }, 403);

  let body: {
    staff_id?: string;
    client_id?: string;
    to?: string;
    subject?: string;
    body?: string;
    document_url?: string;
    document_name?: string;
    document_id?: string;
  } = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  const staffId = (body.staff_id ?? user.uid).toLowerCase();
  const clientId = body.client_id ?? "";
  const to = (body.to ?? "").trim();
  const subject = (body.subject ?? "").trim();
  const messageText = body.body ?? "";

  if (!staffId || !clientId || !to || !subject) {
    return json({ error: "missing required fields" }, 400);
  }

  // Emails only go out from the caller's own connected mailbox.
  if (staffId !== user.uid) {
    return json({ error: "forbidden", message: "You can only send from your own mailbox." }, 403);
  }

  // Load the sender's Microsoft connection.
  const { data: conn } = await supabase
    .from("microsoft_connections")
    .select("*")
    .eq("user_id", staffId)
    .maybeSingle();

  if (!conn) {
    return json({ error: "not_connected", message: "Connect your Microsoft account first." }, 409);
  }

  const redirectUri = `${functionBaseURL(req)}/callback`;
  const sendId = crypto.randomUUID();

  // Build HTML body with a tracking pixel.
  const pixelUrl = `${functionBaseURL(req)}/track/${sendId}`;
  const paragraphs = escapeHtml(messageText).replace(/\n/g, "<br>");
  let htmlBody = `<div style="font-family:-apple-system,Segoe UI,sans-serif;font-size:15px;color:#2b2b2b;line-height:1.5">${paragraphs}`;

  // Try to attach the document; on failure, fall back to a link in the body.
  const attachments: Array<Record<string, unknown>> = [];
  if (body.document_url) {
    try {
      const docRes = await fetch(body.document_url);
      if (docRes.ok) {
        const buf = new Uint8Array(await docRes.arrayBuffer());
        // Graph sendMail inline attachment limit is ~3MB.
        if (buf.byteLength <= 3_000_000) {
          let binary = "";
          for (let i = 0; i < buf.length; i++) binary += String.fromCharCode(buf[i]);
          const b64 = btoa(binary);
          attachments.push({
            "@odata.type": "#microsoft.graph.fileAttachment",
            name: body.document_name ?? "attachment.pdf",
            contentBytes: b64,
          });
        }
      }
    } catch (e) {
      console.warn("[microsoft-mail] attachment fetch failed:", e);
    }
    if (attachments.length === 0) {
      htmlBody += `<p style="margin-top:16px"><a href="${body.document_url}">${escapeHtml(body.document_name ?? "View document")}</a></p>`;
    }
  }
  htmlBody += `<img src="${pixelUrl}" width="1" height="1" style="display:none" alt=""></div>`;

  // Refresh the access token, then send via Graph.
  let accessToken = conn.access_token as string;
  try {
    const refreshed = await refreshAccessToken(conn.refresh_token as string, redirectUri);
    accessToken = refreshed.access_token;
    await supabase.from("microsoft_connections").update({
      access_token: refreshed.access_token,
      refresh_token: refreshed.refresh_token ?? conn.refresh_token,
      token_expires_at: new Date(Date.now() + (refreshed.expires_in ?? 3600) * 1000).toISOString(),
      updated_at: new Date().toISOString(),
    }).eq("user_id", staffId);
  } catch (e) {
    console.error("[microsoft-mail] token refresh failed:", e);
    return json({ error: "token_refresh_failed", message: "Please reconnect your Microsoft account." }, 401);
  }

  const message = {
    message: {
      subject,
      body: { contentType: "HTML", content: htmlBody },
      toRecipients: [{ emailAddress: { address: to } }],
      attachments,
    },
    saveToSentItems: true,
  };

  const sendRes = await fetch(`${GRAPH}/me/sendMail`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(message),
  });

  const ok = sendRes.status === 202;
  const errText = ok ? null : await sendRes.text();
  if (!ok) console.error("[microsoft-mail] sendMail failed:", sendRes.status, errText);

  const preview = messageText.length > 280 ? messageText.slice(0, 280) : messageText;
  await supabase.from("email_sends").insert({
    id: sendId,
    client_id: clientId,
    sender_id: staffId,
    sender_email: conn.email,
    sender_name: conn.display_name,
    to_email: to,
    subject,
    body_preview: preview,
    document_id: body.document_id ?? null,
    document_name: body.document_name ?? null,
    document_url: body.document_url ?? null,
    status: ok ? "sent" : "failed",
    error: errText,
  });

  if (!ok) {
    return json({ error: "send_failed", message: "Microsoft rejected the message.", detail: errText }, 502);
  }
  return json({ sent: true, id: sendId });
}

async function handleTrack(req: Request, sendId: string): Promise<Response> {
  if (sendId) {
    try {
      const { data: row } = await supabase
        .from("email_sends")
        .select("open_count, first_opened_at")
        .eq("id", sendId)
        .maybeSingle();
      if (row) {
        const now = new Date().toISOString();
        await supabase.from("email_sends").update({
          open_count: (row.open_count ?? 0) + 1,
          first_opened_at: row.first_opened_at ?? now,
          last_opened_at: now,
        }).eq("id", sendId);
      }
    } catch (e) {
      console.warn("[microsoft-mail] track failed:", e);
    }
  }
  return pixelResponse();
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  const url = new URL(req.url);
  const path = url.pathname;

  // Path-based routes first (callback + tracking pixel use clean paths).
  if (path.endsWith("/callback")) {
    return handleCallback(req);
  }
  const trackIdx = path.indexOf("/track/");
  if (trackIdx >= 0) {
    const sendId = path.slice(trackIdx + "/track/".length).split("/")[0];
    return handleTrack(req, sendId);
  }

  const action = url.searchParams.get("action");
  switch (action) {
    case "start":
      return handleStart(req);
    case "status":
      return handleStatus(req);
    case "disconnect":
      return handleDisconnect(req);
    case "send":
      return handleSend(req);
    default:
      if (req.method === "POST") {
        // Allow action via body for POSTs too.
        return handleSend(req);
      }
      return json({ error: "unknown action" }, 400);
  }
});
