// Cal.com webhook receiver — keeps `client_foundation_calls` in sync with
// real bookings made through the Cal.com booking link embedded in the CRM.
//
// Configure in Cal.com → Settings → Developer → Webhooks:
//   URL:    https://<project>.functions.supabase.co/cal-webhook
//   Secret: set to the value of CALCOM_WEBHOOK_SECRET (env)
//   Events: BOOKING_CREATED, BOOKING_RESCHEDULED, BOOKING_CANCELLED, MEETING_ENDED
//
// When booking, include `metadata[avia_client_id]=<uuid>` in the booking URL
// (the iOS CalComService does this automatically) so we can match the booking
// back to the AVIA client.
//
// Required env:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   CALCOM_WEBHOOK_SECRET   (optional but recommended)

// @ts-ignore - Deno runtime imports
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-ignore - Deno runtime imports
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// @ts-ignore - Deno globals
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
// @ts-ignore - Deno globals
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// @ts-ignore - Deno globals
const WEBHOOK_SECRET = Deno.env.get("CALCOM_WEBHOOK_SECRET") ?? "";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

type CalAttendee = { name?: string; email?: string };
type CalPayload = {
  triggerEvent?: string;
  type?: string;
  payload?: {
    uid?: string;
    bookingId?: number | string;
    title?: string;
    eventTypeId?: number | string;
    eventType?: { slug?: string; title?: string };
    startTime?: string;
    endTime?: string;
    attendees?: CalAttendee[];
    organizer?: { email?: string; name?: string };
    location?: string;
    meetingUrl?: string;
    videoCallData?: { url?: string };
    metadata?: Record<string, string>;
    responses?: Record<string, unknown>;
    cancellationReason?: string;
  };
};

function pickMeetingURL(p: CalPayload["payload"]): string | null {
  if (!p) return null;
  if (p.videoCallData?.url) return p.videoCallData.url;
  if (p.meetingUrl) return p.meetingUrl;
  if (p.location && /^https?:\/\//.test(p.location)) return p.location;
  return null;
}

function statusFor(event: string | undefined): string {
  switch (event) {
    case "BOOKING_CREATED":
      return "scheduled";
    case "BOOKING_RESCHEDULED":
      return "scheduled";
    case "BOOKING_CANCELLED":
      return "cancelled";
    case "MEETING_ENDED":
      return "completed";
    case "BOOKING_NO_SHOW_UPDATED":
      return "no_show";
    default:
      return "scheduled";
  }
}

async function resolveClientId(p: CalPayload["payload"]): Promise<string | null> {
  if (!p) return null;
  const metaId = p.metadata?.avia_client_id;
  if (typeof metaId === "string" && metaId.length > 0) return metaId;

  const email = p.attendees?.[0]?.email;
  if (!email) return null;
  const { data, error } = await supabase
    .from("profiles")
    .select("id")
    .eq("email", email)
    .limit(1);
  if (error) {
    console.error("[cal-webhook] resolveClientId profiles lookup failed", error);
    return null;
  }
  return data?.[0]?.id ?? null;
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  // Optional shared-secret check. Cal.com sends `x-cal-signature-256` (HMAC) —
  // for simplicity here we accept either a matching header value or a
  // `?secret=` query string equal to CALCOM_WEBHOOK_SECRET.
  if (WEBHOOK_SECRET.length > 0) {
    const header = req.headers.get("x-cal-secret") ?? "";
    const url = new URL(req.url);
    const queryParam = url.searchParams.get("secret") ?? "";
    if (header !== WEBHOOK_SECRET && queryParam !== WEBHOOK_SECRET) {
      return new Response("forbidden", { status: 403 });
    }
  }

  let body: CalPayload;
  try {
    body = await req.json();
  } catch (_err) {
    return new Response("invalid json", { status: 400 });
  }

  const event = body.triggerEvent ?? body.type;
  const p = body.payload;
  if (!p) return new Response("no payload", { status: 400 });

  const clientId = await resolveClientId(p);
  if (!clientId) {
    console.warn("[cal-webhook] could not resolve client for booking", p.uid);
    return new Response("ok (no client)", { status: 200 });
  }

  const status = statusFor(event);
  const calBookingUid = p.uid ?? null;
  const calBookingId = p.bookingId != null ? String(p.bookingId) : null;
  const meetingUrl = pickMeetingURL(p);
  const scheduledAt = p.startTime ?? null;
  const durationMinutes =
    p.startTime && p.endTime
      ? Math.max(1, Math.round((new Date(p.endTime).getTime() - new Date(p.startTime).getTime()) / 60000))
      : null;

  // Try to update an existing row by cal_booking_uid first.
  if (calBookingUid) {
    const { data: existing, error: lookupErr } = await supabase
      .from("client_foundation_calls")
      .select("id")
      .eq("cal_booking_uid", calBookingUid)
      .limit(1);
    if (lookupErr) console.error("[cal-webhook] lookup failed", lookupErr);

    if (existing && existing.length > 0) {
      const { error } = await supabase
        .from("client_foundation_calls")
        .update({
          status,
          scheduled_at: scheduledAt,
          duration_minutes: durationMinutes,
          meeting_url: meetingUrl,
          cal_booking_id: calBookingId,
          cal_event_type: p.eventType?.slug ?? p.eventType?.title ?? null,
          attendee_email: p.attendees?.[0]?.email ?? null,
          attendee_name: p.attendees?.[0]?.name ?? null,
          notes: p.cancellationReason ?? p.title ?? null,
        })
        .eq("id", existing[0].id);
      if (error) {
        console.error("[cal-webhook] update failed", error);
        return new Response("update failed", { status: 500 });
      }
      return new Response("ok (updated)", { status: 200 });
    }
  }

  // Otherwise: see if the client has a `pending` row we should fill in.
  const { data: pendingRows } = await supabase
    .from("client_foundation_calls")
    .select("id")
    .eq("client_id", clientId)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(1);

  if (pendingRows && pendingRows.length > 0) {
    const { error } = await supabase
      .from("client_foundation_calls")
      .update({
        status,
        scheduled_at: scheduledAt,
        duration_minutes: durationMinutes,
        meeting_url: meetingUrl,
        cal_booking_id: calBookingId,
        cal_booking_uid: calBookingUid,
        cal_event_type: p.eventType?.slug ?? p.eventType?.title ?? null,
        attendee_email: p.attendees?.[0]?.email ?? null,
        attendee_name: p.attendees?.[0]?.name ?? null,
        notes: p.cancellationReason ?? p.title ?? null,
      })
      .eq("id", pendingRows[0].id);
    if (error) {
      console.error("[cal-webhook] reconcile failed", error);
      return new Response("reconcile failed", { status: 500 });
    }
    return new Response("ok (reconciled)", { status: 200 });
  }

  // Otherwise insert a brand-new row.
  const { error: insertErr } = await supabase.from("client_foundation_calls").insert({
    client_id: clientId,
    status,
    scheduled_at: scheduledAt,
    duration_minutes: durationMinutes,
    meeting_url: meetingUrl,
    cal_booking_id: calBookingId,
    cal_booking_uid: calBookingUid,
    cal_event_type: p.eventType?.slug ?? p.eventType?.title ?? null,
    attendee_email: p.attendees?.[0]?.email ?? null,
    attendee_name: p.attendees?.[0]?.name ?? null,
    notes: p.cancellationReason ?? p.title ?? null,
  });
  if (insertErr) {
    console.error("[cal-webhook] insert failed", insertErr);
    return new Response("insert failed", { status: 500 });
  }

  return new Response("ok (inserted)", { status: 200 });
});
