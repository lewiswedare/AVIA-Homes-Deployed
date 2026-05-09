# Display Homes

## Goal
Let clients browse AVIA display homes, see opening hours/details, and request
a visit. Visits flow through to admin/staff who can confirm, reschedule, mark
completed/no-show, and assign a host. Clients see live status updates.

## Tasks
- [x] Migration: `display_homes` + `display_home_visits` with RLS + realtime
- [x] Models: `DisplayHome`, `DisplayHomeVisit` + Codable rows
- [x] Service: `SupabaseService` CRUD + realtime + state on `AppViewModel`
- [x] Client UI: list, detail, booking sheet, my-bookings
- [x] Admin UI: manage display homes + visit pipeline
- [x] Wire entry points (Discover, More, Admin menu) + runChecks ios
