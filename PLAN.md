# Client-facing Foundation Call banner

## Goal
When a client has a scheduled Foundation Call (synced from Cal.com), surface a prominent "Join your Foundation Call" banner on the client dashboard with a one-tap join button. Update live as Cal.com webhooks fire.

## Tasks
- [x] Add `ClientFoundationCallBanner` view (scheduled state, with countdown + Join button)
- [x] Wire it into `ClientDiscoverDashboardView` (only for `.client` role users with a scheduled call)
- [x] Fetch latest call on appear; subscribe to `client_foundation_calls` realtime updates
- [x] Refresh on Cal.com webhook updates so the banner appears/updates without manual refresh
- [x] Build & verify (runChecks ios)
