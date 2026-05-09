# Client-facing Foundation Call banner

## Goal
When a client has a scheduled Foundation Call (synced from Cal.com), surface a prominent "Join your Foundation Call" banner on the client dashboard with a one-tap join button. Update live as Cal.com webhooks fire. Also let clients self-schedule a Foundation Call with the AVIA team via Cal.com.

## Tasks
- [x] Add `ClientFoundationCallBanner` view (scheduled state, with countdown + Join button)
- [x] Wire it into `ClientDiscoverDashboardView` (only for `.client` role users with a scheduled call)
- [x] Fetch latest call on appear; subscribe to `client_foundation_calls` realtime updates
- [x] Refresh on Cal.com webhook updates so the banner appears/updates without manual refresh
- [x] Client-initiated booking: "Schedule a Call" CTA when no upcoming call, opens Cal.com prefilled with name/email/clientId
- [x] Optimistic pending record so the webhook can reconcile by client_id
- [x] Build & verify (runChecks ios)
