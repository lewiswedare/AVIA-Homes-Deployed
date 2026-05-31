# Send from your real Microsoft 365 accounts inside each client's CRM, with a document library and open tracking

## What you'll be able to do

**Send as your real Outlook self**
- Each staff member connects their own Microsoft 365 / Outlook account once (a secure "Connect Microsoft" button in their profile).
- Emails you send from the app go out from your actual address and land in your real Outlook **Sent Items**, so the whole thread stays in Outlook exactly as if you'd typed it there.
- If a teammate hasn't connected their account yet, they'll see a friendly prompt to connect before sending.

**Send straight from the client record**
- Inside each client's CRM profile, a new "Documents & Sending" area lets you:
  - Browse the client's document library (plans, contracts, brochures, anything already stored for them).
  - Compose and fire off an email — pick a document to attach, write a subject and message, and send — all without leaving the client record.
  - Use quick starting points (e.g. "Send plans", "Send contract", "Follow up") that pre-fill the message so sending takes seconds.

**See what's been sent and what's been opened**
- A "Sent history" list on the client profile shows every email sent from the app: who sent it, when, the subject, and any attached document.
- Each item shows a live status — **Sent**, then **Opened** once the client views it (with the time they first opened it and how many times).
- The communication log and lead activity stay in sync, so an opened email can nudge the lead score and timeline.

## How it will look and feel
- The new section uses the same warm AVIA card styling already in the CRM (rounded "bento" cards, brown accents).
- The compose screen is a clean sheet: recipient chip, subject, message, an attach-document row, and a prominent "Send from {your name}" button.
- Sent items animate in with clear status pills — a soft grey "Sent" pill that turns into a green "Opened" pill the moment a client opens the email.

## One thing I need from you
Sending as your real Microsoft accounts requires a small one-time setup in your Microsoft 365 tenant (registering AVIA Homes as an approved app so staff can grant permission to send mail on their behalf). I'll need three values from that registration — a client ID, a client secret, and your tenant ID. I'll request these securely when we get to that step. Everything else (the CRM UI, document library, sending, and open tracking) I'll build now.

## Build order
- [x] The behind-the-scenes sending + open-tracking service.
- [x] The "Connect Microsoft" button in each staff member's profile.
- [x] The Documents & Sending area inside the client CRM (browse, compose, attach, send).
- [x] The Sent history list with live Sent/Opened status.

## Remaining to go live
- [ ] Microsoft 365 tenant credentials (client ID, client secret, tenant ID) added as secrets.
- [ ] Database migrations applied (`20260526_build_timeline_schedule.sql`, `20260527_microsoft_mail.sql`, `20260528_task_management.sql`).

---

# Admin task management (added)
- [x] Manual tasks can be created directly from the Tasks dashboard, optionally linked to a client or left as a general team to-do.
- [x] Automated sales-workflow steps in each client's CRM can be ticked off manually (overriding auto-detection), persisted per client via `client_stage_completions`.
- [ ] Apply migration `20260528_task_management.sql` (client tasks become optionally client-less + adds the stage-completion table).