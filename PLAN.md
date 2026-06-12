# Build an admin "Workspace" — a daily operating-system hub for tasks, clients, jobs, scheduling & sending

_Status: ✅ Implemented — `AdminWorkspaceView` is the admin landing tab (Today, Tasks, Leads, Clients, Jobs, Schedule, Sending lanes). Build green._

_Web parity: ✅ The web Workspace now matches the iOS admin panel — lane badges, full Action Required panel (pending users with role assignment, open requests, EOIs, spec reviews, upgrades to price), task inbox filters, full lead/opportunity record with the sales workflow & contract gate, job spec-review badges, and admin-managed stock library uploads._

_Full-app web parity: ✅ The web app now mirrors the entire iOS surface — role-scoped Packages catalog (+ detail pages for packages, designs, estates, facades, spec ranges), admin Package Management (create/edit/delete, client sharing, partner assignment & exclusivity, EOI review), client Discover mode for no-build clients (news, designs, spec ranges, facades, shared-package banner), My Package review with the 4-step EOI wizard, Stocklist with admin estate/lot editing, Display Homes with visit booking & My Visits, Requests & Support (client submit + staff respond/status flow), SuperAdmin Overview, and role-matched navigation for every role._

Right now admins jump between separate menus for tasks, clients, builds, scheduling and sending. I'll bring it all together into one workflow-driven home screen that acts as their daily operating system.

## What admins will be able to do

**Start their day from one "Today" hub**
- A new main screen greets them with today's date and a live snapshot: how many tasks are due, what's overdue, who needs following up, and what's scheduled today across all clients.
- An "Action Required" panel surfaces anything waiting on them (approvals, reviews, pending users, client requests) with one-tap jump-throughs.

**Move between the five workflows in one place**
- A clean row of workflow lanes at the top: **Today**, **Tasks**, **Leads**, **Clients**, **Jobs**, **Schedule**, **Sending** — tap to switch the workspace without digging through menus.
- **Leads** — inbound enquiries from the website and social media land here for triage. Each lead can be assigned to an admin or staff member, filtered by owner (all / mine / unassigned) and source, moved through the pipeline, and opened to a full record with notes, call/email actions and editable details.
- **Today** — the focus view: overdue + due-today tasks, today's and this week's appointments, and follow-ups due, all in one prioritised list they can act on.
- **Tasks** — the full task board (add manual tasks, tick off automated workflow steps, filter by mine/overdue/today/week).
- **Clients** — the client pipeline (lead stages) plus quick search into each client's record.
- **Jobs** — every active build with its stage and progress, so job management lives alongside everything else.
- **Schedule** — a unified upcoming-appointments timeline pulled from every client (meetings, inspections, site visits, handovers), grouped by day.
- **Sending** — a quick launchpad to pick a client and open their documents & sending area to compose and fire off emails.

**Act without losing their place**
- Every item (a task, a client, a build, an appointment) deep-links straight to the right detail screen and back.
- Quick actions stay one tap away: new task, new build, jump to a client.

## How it will look and feel
- Same warm AVIA styling already used across the admin app — rounded "bento" cards, brown accents, soft backgrounds — so it feels native, not bolted on.
- The workflow lanes sit in a smooth horizontal selector with an animated highlight; switching lanes cross-fades the content.
- The "Today" hub leads with bold summary metric cards and a clean prioritised feed, with gentle press animations and clear status pills (e.g. overdue in amber, scheduled in brown).
- Each day in the schedule view gets a light date header so the timeline reads at a glance.

## Screens
- **Admin Workspace (new main screen)** — replaces the current admin landing tab as the operating-system home, with the six workflow lanes described above.
- Existing detail screens (client record, build detail, task editor, schedule milestone editor, documents & sending) are reused and linked in — nothing existing is removed.

Note: this reorganises and unifies what already exists into a single workflow hub; it doesn't change any of the underlying data or sending behaviour.