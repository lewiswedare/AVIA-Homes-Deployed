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
