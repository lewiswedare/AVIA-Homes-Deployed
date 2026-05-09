# Unified "Selections" — pick upgrades & colours together, by room

## What's changing

Today, clients have to bounce between two separate screens — Spec Range (to request upgrades on items) and Colour Selections (to pick colours after spec approval). We'll merge both into a single, visual feature called **Selections** that walks clients room-by-room and lets them pick the item finish *and* the colour on the same card.

## Features (Client side)

- **Single "Selections" tab** replaces both Spec Range and Colour Selections screens for every client build.
- **Room-based browsing**: Kitchen, Bathroom & Ensuite, Living, Bedrooms, Laundry, External, Outdoor — each room shown as a visual card with hero image and progress.
- **One unified card per item**: shows the item name, what's included as standard, and any available upgrade tiers with pricing.
- **Two-step flow on the same card**:
  1. Pick the tier — Standard (included) or an upgrade option with its price.
  2. Pick the colour/finish — colour swatches appear right below the tier choice, filtered to what's available for that tier.
- **Live running total** of upgrade costs at the top of each room and overall.
- **Submit when ready** — one button sends everything (item upgrades + colour choices) to the AVIA team for review and quoting.
- **Status pills** on each item: Not started, In progress, Submitted, Quoted, Approved, Changes requested.
- All client builds — new and in-flight — use the unified Selections flow. The legacy split Specs + Colours tabs have been removed.

## Features (Admin side)

- **One combined review screen** per build with every selection on a single line: item, chosen tier, colour swatch + name, upgrade cost, status.
- Filter by room or by status (needs quote, needs approval, approved).
- Approve, send back, or quote directly from any line.
- Total upgrade quote for the build shown at the top, with a single PDF export.

## Design

- Warm, editorial AVIA aesthetic — same palette (timeless brown, cream, soft accents).
- Each room card uses a real room photograph as the hero, with a subtle progress ring overlaid.
- Selection cards feel like a tactile sample board: large colour swatches, small tier chips, a clear price tag for upgrades.
- Smooth expand/collapse animation when a card is opened to reveal swatches.
- Haptic feedback on tier and swatch taps; small confirmation checkmark animation when an item is fully selected.
- A floating "Selections summary" pill at the bottom of the screen shows count complete and running upgrade total — tap to review and submit.

## Screens

- **Selections home** — list of rooms with hero images, progress, and overall upgrade total.
- **Room detail** — every selectable item in that room as expandable cards with tier picker + swatch picker.
- **Review & submit** — checklist of every selection grouped by room, total upgrade cost, submit button.
- **Status / quote screen** — shown after submission, lists each item with admin's quote and approval status, with accept / change buttons per line.
- **Admin combined review** — one table per build showing item + tier + colour + cost + status, with approve / quote actions.

## Data & rollout

- All client builds use the unified Selections flow — no contract-date cutoff.
- Legacy Spec + Colour client tabs removed from `ClientBuildDetailView`.
- Admin catalog (item categories, tiers, colour options) stays as-is — Selections reads from the same catalog.