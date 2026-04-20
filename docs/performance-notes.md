# Performance notes

## Manual: confirm Supabase project region

Confirm the Supabase project region is `ap-southeast-2 (Sydney)`.

- Dashboard → **Settings → General**
- If it reads `us-east-1` or another non-AU region, a region migration is recommended
  for Australian users. Round-trip latency drops substantially once queries land on a
  Sydney-hosted Postgres + Storage edge.

This check cannot be automated from the iOS client; it must be verified in the
Supabase web dashboard.
