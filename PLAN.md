# Add 'Fixed inclusion' option for selection items

## What this changes

Some items in a build (like structural inclusions) aren't choices — the customer doesn't need to pick a tier or a colour. Right now every item in Selections looks tappable and asks the user to "choose a finish", which is confusing for these fixed items.

## Admin side

- A new **"Fixed inclusion (no variants)"** toggle on the Spec Item editor.
- When turned on:
  - The upgrade tier options and linked colour categories are hidden in the editor (since they don't apply).
  - The item is saved as a non-variant item.

## End-user side (Selections screen)

- Fixed-inclusion items still appear in the room's list so the customer can see what's included.
- They show with a clear **"Included"** badge.
- They are **not tappable** — no chevron, no expand, nothing to choose.
- A subtle visual treatment (slightly muted card, no arrow) signals "this is set, no action needed".

## Result

Customers only see action prompts on items they actually need to make a decision on. Fixed inclusions read clearly as part of their build with no false invitation to interact.

---

# Final admin lock-in of the quote before construction

## What this changes

Once every selection is resolved (all upgrades priced, accepted/declined, all colours approved), the admin needs an explicit final step that **locks in the final quote** and **moves the build out of the Selections phase into the construction stages**.

## Where it lives

A new capstone section at the bottom of `AdminBuildSpecReviewView` that only appears when:

- No spec/colour/range upgrades are still pending on either side.
- All selections are admin-approved (`overallStatus == .approved`).

## What the capstone shows

- Final quote total (sum of all locked-in upgrades) with a short breakdown.
- A primary `Lock In Final Quote & Begin Build` button.
- A confirm alert: "This will lock all selections and move the build into construction. Are you sure?"

## What it does

- Marks the Pre-Construction stage (or first non-completed stage) as **completed**.
- Marks the next stage as **in progress** so the client's build dashboard advances.
- Sends a notification to the client: "Your final quote is locked in and your build is now underway."

Reopening for the client (existing button) remains available if changes are needed later.
