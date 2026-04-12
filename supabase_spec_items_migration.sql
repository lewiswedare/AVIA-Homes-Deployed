-- ============================================================
-- AVIA Homes — Spec Items Flat Table Migration
-- Run this in Supabase SQL Editor AFTER supabase_catalog_tables.sql
--
-- This creates a new `spec_items` table where each spec item
-- is its own row — much easier to edit in the Supabase dashboard
-- than the old JSONB array inside spec_categories.items.
-- ============================================================

-- 1. Create the flat spec_items table
CREATE TABLE IF NOT EXISTS spec_items (
    id TEXT PRIMARY KEY,
    category_id TEXT NOT NULL,
    name TEXT NOT NULL,
    volos_description TEXT NOT NULL DEFAULT '',
    messina_description TEXT NOT NULL DEFAULT '',
    portobello_description TEXT NOT NULL DEFAULT '',
    is_upgradeable BOOLEAN NOT NULL DEFAULT false,
    image_url TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. RLS
ALTER TABLE spec_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read spec_items" ON spec_items FOR SELECT USING (true);
CREATE POLICY "Auth write spec_items" ON spec_items FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 3. Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_spec_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER spec_items_updated_at
    BEFORE UPDATE ON spec_items
    FOR EACH ROW
    EXECUTE FUNCTION update_spec_items_updated_at();

-- ============================================================
-- SEED DATA — one row per spec item, easy to edit!
-- ============================================================

INSERT INTO spec_items (id, category_id, name, volos_description, messina_description, portobello_description, is_upgradeable, sort_order) VALUES
-- Structure & Ceiling
('ceiling_height', 'structure', 'Ceiling Height', '2,440mm internal ceiling height', '2,590mm internal ceiling height', '2,740mm internal ceiling height', true, 1),
('concrete_slab', 'structure', 'Concrete Slab', 'Engineer designed slab to suit soil conditions', 'Engineer designed slab to suit soil conditions', 'Engineer designed slab to suit soil conditions', false, 2),
('frame_trusses', 'structure', 'Frame & Trusses', 'Termite-resistant H2F blue treated pine timber', 'Termite-resistant H2F blue treated pine timber', 'Termite-resistant H2F blue treated pine timber', false, 3),
('insulation', 'structure', 'Insulation Batts', 'R 3.5 ceiling batts, R 2.0 wall batts', 'R 3.5 ceiling batts, R 2.0 wall batts', 'R 3.5 ceiling batts, R 2.0 wall batts', false, 4),

-- External Finishes
('facade', 'exterior', 'Facade Finish', 'Face brick from standard range with off-white mortar, ironed profile', 'Face brick from standard range with off-white mortar, ironed profile', 'Face brick from standard range with off-white mortar, ironed profile', true, 1),
('cladding', 'exterior', 'Lightweight Cladding', 'Painted finish as per plan', 'Painted finish as per plan', 'Painted finish as per plan', false, 2),
('roof', 'exterior', 'Roof', 'COLORBOND® corrugated steel roofing with standard colour range', 'COLORBOND® corrugated steel roofing with standard colour range', 'COLORBOND® corrugated steel roofing with full colour range', true, 3),
('fascia_gutters', 'exterior', 'Fascia & Gutters', 'COLORBOND® fascia, gutters & PVC downpipes', 'COLORBOND® fascia, gutters & PVC downpipes', 'COLORBOND® fascia, gutters & PVC downpipes', false, 4),
('driveway', 'exterior', 'Driveway', 'Standard concrete driveway', 'Broom finish concrete driveway', 'Exposed aggregate concrete driveway', true, 5),

-- Windows & Doors
('windows', 'windows_doors', 'Windows', 'Aluminium windows with keyed locks', 'Aluminium windows with keyed locks & Low-E glass', 'Powder-coated aluminium windows with keyed locks & Low-E glass', true, 1),
('ext_doors', 'windows_doors', 'External Doors', '2,100mm high external doors', '2,100mm high external doors', '2,340mm high external doors', true, 2),
('front_entry', 'windows_doors', 'Front Entry Door', 'Standard hinged front entry door', 'Corinthian Blonde Oak front entry with digital touchpad lock', '1,200mm wide Corinthian Blonde Oak entry with digital touchpad lock', true, 3),
('security_screens', 'windows_doors', 'Security Screens', 'Diamond grille with fibreglass mesh fly screens', 'Diamond grille with fibreglass mesh fly screens', 'Diamond grille with fibreglass mesh fly screens on all openings', false, 4),
('garage_door', 'windows_doors', 'Garage Door', 'Panel lift garage door', 'Panel lift garage door with 2 x remotes', 'Panel lift garage door with 2 x remotes', true, 5),

-- Kitchen
('benchtop', 'kitchen', 'Benchtop', 'Laminate benchtop from standard range', '20mm stone benchtop from standard range', '20mm premium stone benchtop from extended range', true, 1),
('cabinetry', 'kitchen', 'Cabinetry', 'Standard flat panel cabinetry in white', 'Two-tone cabinetry with soft-close drawers & doors', 'Premium two-tone cabinetry with soft-close, pot drawers & pantry internals', true, 2),
('splashback', 'kitchen', 'Splashback', 'Standard tiled splashback', '600mm tiled splashback from standard range', 'Full-height tiled splashback from premium range', true, 3),
('sink', 'kitchen', 'Sink', 'Single bowl stainless steel sink', '1 & 3/4 bowl stainless steel undermount sink', 'Double bowl stainless steel undermount sink', true, 4),
('tapware', 'kitchen', 'Tapware', 'Chrome mixer tap', 'Chrome gooseneck mixer tap', 'Matte black gooseneck mixer tap', true, 5),
('appliances', 'kitchen', 'Appliances', '600mm oven, ceramic cooktop & rangehood', '900mm oven, 5-burner gas cooktop & rangehood', '900mm pyrolytic oven, induction cooktop, integrated rangehood & dishwasher', true, 6),

-- Bathroom & Ensuite
('floor_tiles', 'bathroom', 'Floor Tiles', 'Standard ceramic floor tiles', '300x600mm porcelain floor tiles from standard range', '600x600mm porcelain floor tiles from premium range', true, 1),
('wall_tiles', 'bathroom', 'Wall Tiles', 'Standard ceramic wall tiles to 1,200mm', '300x600mm porcelain wall tiles to 1,800mm', '300x600mm porcelain wall tiles floor to ceiling', true, 2),
('vanity', 'bathroom', 'Vanity', 'Standard 750mm vanity with ceramic top', '900mm wall-hung vanity with stone top', '1,200mm wall-hung double vanity with stone top', true, 3),
('bath_tapware', 'bathroom', 'Tapware', 'Chrome basin mixer & shower set', 'Chrome basin mixer & rail shower set', 'Matte black basin mixer, overhead rain shower & rail shower set', true, 4),
('shower_screen', 'bathroom', 'Shower Screen', 'Framed pivot shower screen', 'Semi-frameless shower screen', 'Frameless glass shower screen', true, 5),
('mirror', 'bathroom', 'Mirror', 'Standard mirror above vanity', 'Polished edge mirror above vanity', 'Frameless pencil edge mirror with LED backlight', true, 6),
('toilet', 'bathroom', 'Toilet Suite', 'Close-coupled toilet suite', 'Back-to-wall toilet suite with soft close seat', 'Wall-faced toilet suite with concealed cistern & soft close seat', true, 7),
('bath_accessories', 'bathroom', 'Accessories', 'Chrome towel rail & toilet roll holder', 'Chrome towel rail, robe hook & toilet roll holder', 'Matte black towel rail, robe hook, toilet roll holder & shelf', true, 8),

-- Flooring
('main_flooring', 'flooring', 'Main Living Flooring', 'Vinyl plank flooring to living areas', 'Hybrid vinyl plank flooring to living areas from standard range', 'Premium hybrid flooring to living areas from extended range', true, 1),
('carpet', 'flooring', 'Carpet', 'Solution-dyed nylon carpet to bedrooms', 'Premium solution-dyed nylon carpet with upgraded underlay', 'Luxury plush carpet with premium underlay to all bedrooms', true, 2),
('wet_area_tiles', 'flooring', 'Wet Area Tiles', 'Standard ceramic tiles to wet areas', 'Porcelain tiles from standard range to wet areas', 'Premium porcelain tiles from extended range to all wet areas', true, 3),

-- Internal Finishes
('int_doors', 'internal', 'Internal Doors', '2,040mm flat panel internal doors', '2,100mm designer deco panel internal doors', '2,340mm designer deco panel internal doors with premium hardware', true, 1),
('door_hardware', 'internal', 'Door Hardware', 'Standard satin chrome lever handles', 'Satin chrome lever handles with privacy locks to WC', 'Matte black lever handles with privacy locks to WC & ensuite', true, 2),
('paint', 'internal', 'Internal Paint', 'Taubmans low sheen paint, single colour throughout', 'Taubmans low sheen paint with feature wall colour', 'Dulux Wash & Wear low sheen paint with feature wall colours', true, 3),
('blinds', 'internal', 'Window Furnishings', 'Single roller blinds to bedrooms & living', 'Deluxe single blockout roller blinds to all windows', 'Deluxe dual roller blinds (blockout + sunscreen) to all windows', true, 4),
('skirting', 'internal', 'Skirting & Architraves', '67mm skirting & 42mm architraves', '90mm skirting & 67mm architraves', '115mm skirting & 90mm architraves', true, 5),

-- Electrical & Lighting
('powerpoints', 'electrical', 'Powerpoints', '1 double powerpoint per room', 'Double powerpoints per room, USB-A & USB-C in kitchen & main bed', 'Multiple double powerpoints per room, USB-A & USB-C in kitchen, main bed & living', true, 1),
('switches', 'electrical', 'Light Switches', 'Standard white switches & plates', 'Clipsal white Saturn switches', 'Clipsal Iconic matte black switches & plates', true, 2),
('lighting', 'electrical', 'Lighting', 'Standard LED downlights throughout', 'LED downlights with dimmer to living areas', 'Premium LED downlights with dimmers, pendant provision & LED strip to kitchen', true, 3),
('ext_lighting', 'electrical', 'External Lighting', '1 x external light to front entry', 'External lights to front entry & alfresco', 'External lights to front entry, alfresco & garage with sensor', true, 4),
('data_comms', 'electrical', 'Data & Communications', 'NBN/Opticomm provision to 1 location', 'NBN/Opticomm provision with data points to living & main bed', 'NBN/Opticomm provision with data points to living, main bed & study', true, 5),

-- Outdoor & Landscaping
('alfresco', 'outdoor', 'Alfresco', 'Covered concrete alfresco (as per plan)', 'Covered concrete alfresco with ceiling fan provision', 'Covered tiled alfresco with ceiling fan & gas bayonet', true, 1),
('letterbox', 'outdoor', 'Letterbox', 'Standard rendered letterbox', 'Rendered letterbox to match facade', 'Premium rendered letterbox with house number', true, 2),
('clothesline', 'outdoor', 'Clothesline', 'Fold-down clothesline', 'Fold-down clothesline', 'Retractable clothesline', false, 3),
('ext_tap', 'outdoor', 'External Taps', '1 x garden tap', '2 x garden taps (front & rear)', '2 x garden taps (front & rear) with hose connections', true, 4)
ON CONFLICT (id) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    name = EXCLUDED.name,
    volos_description = EXCLUDED.volos_description,
    messina_description = EXCLUDED.messina_description,
    portobello_description = EXCLUDED.portobello_description,
    is_upgradeable = EXCLUDED.is_upgradeable,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();
