# Wire Spec Products + Colours into the client experience

## What's already in place
The admin tools already match the hierarchy you described — Spec Range → Spec Category → Spec Item → Spec Product (assigned to one or more ranges as Included or Upgrade with a cost) → Spec Product Colour (with optional extra cost). The Spec Item editor will be left as-is.

The gap is on the **client side**: when a customer opens a Spec Item in their range, they currently see the old generic colour swatches instead of the new Products. This plan focuses on connecting Products end-to-end.

## What clients will see
- **Inside a Spec Item** (e.g. Tapware in Kitchen):
  - A list of every Product available in their selected range
  - Each product card shows its image, name, brand, and a clear tag: "Included" (green) or "+$X Upgrade" (amber)
  - Products marked Unavailable in their range are hidden
  - The default Included product is pre-selected and highlighted
- **Tapping a product** opens a colour picker:
  - Swatches with name, hex chip, and any extra cost (e.g. "+$120")
  - Default colour pre-selected
  - Confirm button locks in product + colour for that Spec Item
- **Spec Items flagged "Fixed inclusion"** keep working as today — shown as Included, no product picker
- The cost summary updates live: range upgrade cost (if upgraded) + colour extra cost rolls into the build total
- Admin's final-confirmation quote flow continues to lock in selections

## What admins keep
- Catalogue → Spec Items list still works exactly as today
- Tapping into a Spec Item opens the existing Products screen (already built)
- Each Product editor: image, brand/model/SKU, range matrix (Included / Upgrade $ / Unavailable + Default toggle), and colours with extra cost
- The legacy "Selections" mapping screen is kept hidden from the client flow but remains for any old data that hasn't been migrated to products yet — it stops driving the client UI

## Behind the scenes
- Build selections store the chosen `productId` + `productColourId` (in addition to the existing spec item id)
- Selection summaries on the admin review and final quote screens display the chosen product + colour name, cost line items, and totals
- Existing builds without product data fall back to the old colour-only display so nothing breaks

## Edge cases handled
- Spec Item has no products yet → shows "Coming soon" placeholder, no crash
- Product has no colours → product is selectable, no colour step
- Default product/colour automatically picked for new builds
- Switching range refreshes which products are Included vs Upgrade vs hidden