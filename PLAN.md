# Align colour confirmation flow with the spec confirmation flow

## Current state

**Specs flow:** Status banner → upgrade basket → quoted upgrades → items → helper text → big brown Confirm button → alert dialog → submit. Confirm is blocked until all outstanding upgrade requests/quotes are resolved.

**Colours flow (today):** Status banner → progress ring → tier info → items → upgrade summary (only when upgrades exist) → Confirm button (no alert, helper text below, no incomplete warning).

## Improvements

- [x] **Confirmation alert** — tapping "Confirm My Colour Selections" will show a confirm dialog matching the spec flow ("Your colour selections will be submitted to the AVIA team for approval…") before locking them in.
- [x] **Helper text above the button** — move the "Submitting X selection(s)…" helper text above the button so it mirrors the spec layout exactly.
- [x] **Incomplete warning** — when the client has not picked a colour for every item, show a clear amber warning card directly above the confirm button: "You haven't selected a colour for X of Y items. You can still submit, but missing items will need to be completed later." Partial submission stays allowed.
- [x] **Upgrade summary card** — keep as-is (only shown when upgrades exist), per your preference.
- [x] **Button styling** — already using the timeless brown gradient; no change needed.

## What the client will see

- A familiar, consistent experience between the specs and colours confirmation screens.
- A friendly heads-up if they try to confirm with items still unselected, without being blocked.
- A confirmation dialog giving them one last chance to review before their colours are sent to the AVIA team.
