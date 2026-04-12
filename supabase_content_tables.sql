-- ============================================================
-- AVIA Homes — Content Tables Schema & Seed Data
-- Run this in your Supabase SQL Editor to create all content
-- tables and populate them with your actual data.
-- ============================================================

-- 1. HOME DESIGNS
CREATE TABLE IF NOT EXISTS home_designs (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    bedrooms INTEGER NOT NULL DEFAULT 4,
    bathrooms INTEGER NOT NULL DEFAULT 2,
    garages INTEGER NOT NULL DEFAULT 2,
    square_meters DOUBLE PRECISION NOT NULL DEFAULT 0,
    image_url TEXT NOT NULL DEFAULT '',
    price_from TEXT NOT NULL DEFAULT '',
    storeys INTEGER NOT NULL DEFAULT 1,
    lot_width DOUBLE PRECISION NOT NULL DEFAULT 12.5,
    slug TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    house_width DOUBLE PRECISION NOT NULL DEFAULT 0,
    house_length DOUBLE PRECISION NOT NULL DEFAULT 0,
    living_areas INTEGER NOT NULL DEFAULT 1,
    floorplan_image_url TEXT NOT NULL DEFAULT '',
    room_highlights JSONB NOT NULL DEFAULT '[]',
    inclusions JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE home_designs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "home_designs_read" ON home_designs FOR SELECT USING (true);

-- 2. HOUSE & LAND PACKAGES
CREATE TABLE IF NOT EXISTS house_land_packages (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    location TEXT NOT NULL DEFAULT '',
    lot_size TEXT NOT NULL DEFAULT '',
    home_design TEXT NOT NULL DEFAULT '',
    price TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL DEFAULT '',
    is_new BOOLEAN NOT NULL DEFAULT false,
    lot_number TEXT NOT NULL DEFAULT '',
    lot_frontage TEXT NOT NULL DEFAULT '',
    lot_depth TEXT NOT NULL DEFAULT '',
    land_price TEXT NOT NULL DEFAULT '',
    house_price TEXT NOT NULL DEFAULT '',
    spec_tier TEXT NOT NULL DEFAULT 'Messina',
    title_date TEXT NOT NULL DEFAULT '',
    council TEXT NOT NULL DEFAULT '',
    zoning TEXT NOT NULL DEFAULT '',
    build_time_estimate TEXT NOT NULL DEFAULT '',
    inclusions JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE house_land_packages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "packages_read" ON house_land_packages FOR SELECT USING (true);

-- 3. BLOG POSTS
CREATE TABLE IF NOT EXISTS blog_posts (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL DEFAULT '',
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_time TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blog_posts_read" ON blog_posts FOR SELECT USING (true);

-- 4. LAND ESTATES
CREATE TABLE IF NOT EXISTS land_estates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    location TEXT NOT NULL DEFAULT '',
    suburb TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'Current',
    total_lots INTEGER NOT NULL DEFAULT 0,
    available_lots INTEGER NOT NULL DEFAULT 0,
    price_from TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    features JSONB NOT NULL DEFAULT '[]',
    expected_completion TEXT NOT NULL DEFAULT '',
    logo_url TEXT,
    logo_asset_name TEXT,
    brochure_url TEXT,
    site_map_url TEXT,
    site_map_asset_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE land_estates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "estates_read" ON land_estates FOR SELECT USING (true);

-- 5. FACADES
CREATE TABLE IF NOT EXISTS facades (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    style TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    hero_image_url TEXT NOT NULL DEFAULT '',
    gallery_image_urls JSONB NOT NULL DEFAULT '[]',
    features JSONB NOT NULL DEFAULT '[]',
    pricing_type TEXT NOT NULL DEFAULT 'included',
    pricing_amount TEXT,
    storeys INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE facades ENABLE ROW LEVEL SECURITY;
CREATE POLICY "facades_read" ON facades FOR SELECT USING (true);

-- 6. DOCUMENTS (per-client)
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Contracts',
    date_added TIMESTAMPTZ NOT NULL DEFAULT now(),
    file_size TEXT NOT NULL DEFAULT '',
    is_new BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "documents_read" ON documents FOR SELECT USING (true);

-- 7. SCHEDULE ITEMS (per-client)
CREATE TABLE IF NOT EXISTS schedule_items (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL DEFAULT '',
    icon TEXT NOT NULL DEFAULT 'calendar',
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    type TEXT NOT NULL DEFAULT 'Meeting',
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE schedule_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "schedule_items_read" ON schedule_items FOR SELECT USING (true);

-- Enable Realtime on content tables (optional, for admin editing)
ALTER PUBLICATION supabase_realtime ADD TABLE home_designs;
ALTER PUBLICATION supabase_realtime ADD TABLE house_land_packages;
ALTER PUBLICATION supabase_realtime ADD TABLE blog_posts;
ALTER PUBLICATION supabase_realtime ADD TABLE land_estates;
ALTER PUBLICATION supabase_realtime ADD TABLE facades;
ALTER PUBLICATION supabase_realtime ADD TABLE documents;
ALTER PUBLICATION supabase_realtime ADD TABLE schedule_items;


-- ============================================================
-- SEED DATA — HOME DESIGNS
-- ============================================================

INSERT INTO home_designs (id, name, bedrooms, bathrooms, garages, square_meters, image_url, price_from, storeys, lot_width, slug, description, house_width, house_length, living_areas, floorplan_image_url, room_highlights, inclusions) VALUES
('alassio', 'Alassio', 4, 2, 2, 280.47, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 1, 12.5, 'alassio', 'The Alassio is designed for those who appreciate generous proportions and refined living. With a sprawling single-storey layout spanning over 280m², this home delivers a premium lifestyle with dedicated zones for entertaining, relaxing, and private retreat.', 14.0, 22.5, 2, '', '["Master suite with ensuite & walk-in robe","Separate theatre/media room","Open-plan kitchen with island bench","Walk-in pantry","Large covered alfresco","Activity room","Separate laundry with linen","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height","Colorbond roof","Quality carpet to bedrooms"]'),
('alicante', 'Alicante', 4, 2, 2, 241.73, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', '', 1, 12.0, 'alicante', 'A functional and stylish single-storey design ideal for family living.', 12.0, 22.0, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Walk-in pantry","Covered alfresco area","Separate laundry","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('almada', 'Almada', 3, 2, 2, 213.37, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', '', 1, 12.0, 'almada', 'A well-proportioned three-bedroom home offering generous living spaces.', 12.0, 20.0, 1, '', '["Master suite with ensuite & WIR","Open-plan living/dining","Modern kitchen with island","Walk-in pantry","Covered alfresco","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('amalfi', 'Amalfi', 4, 2, 2, 300.53, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 2, 10.0, 'amalfi', 'The Amalfi is a striking two-storey residence that makes the most of a narrow lot without compromising on space.', 8.24, 23.75, 3, '', '["Ground floor study & multi-purpose room","Open-plan living extending to alfresco","Upstairs sitting area & rumpus room","Master suite with ensuite & WIR","Kitchen with island & walk-in pantry","Separate laundry","Double garage with internal access","Powder room downstairs"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height (ground)","2440mm ceiling height (upper)","Colorbond roof"]'),
('athens', 'Athens', 3, 2, 2, 163.49, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', '', 1, 10.0, 'athens', 'A compact and efficient three-bedroom design perfect for narrow lots.', 10.0, 19.0, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Covered alfresco","Separate laundry","Double garage","Narrow lot design"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('augusta', 'Augusta', 4, 2, 2, 211.38, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', '', 1, 12.0, 'augusta', 'The Augusta is designed to maximise space and comfort for modern families.', 12.5, 20.0, 2, '', '["Master suite with ensuite & walk-in robe","Separate media room or lounge","Open-plan kitchen with island bench","Walk-in pantry","Covered outdoor entertaining area","Three bedrooms with built-in wardrobes","Separate laundry with linen cupboard","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height","Colorbond roof","Quality carpet to bedrooms","Energy-efficient design elements"]'),
('barcelona', 'Barcelona', 4, 2, 2, 192.59, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', '', 1, 12.0, 'barcelona', 'The Barcelona is a stylish single-storey four-bedroom home with flowing open-plan living areas.', 12.5, 19.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Central kitchen with island bench","Covered alfresco area","Separate laundry","Three minor bedrooms with BIRs","Double garage with internal access","Linen cupboard"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height","Colorbond roof"]'),
('benabbio', 'Benabbio', 4, 2, 2, 230.33, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 1, 12.0, 'benabbio', 'A spacious single-storey home featuring separate living zones.', 12.0, 21.5, 2, '', '["Master suite with ensuite & WIR","Separate lounge room","Open-plan kitchen/dining/living","Walk-in pantry","Covered alfresco","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('berlin', 'Berlin', 4, 2, 2, 163.96, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', '', 1, 12.0, 'berlin', 'An efficient four-bedroom design that maximises living space on a compact footprint.', 12.0, 16.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Covered alfresco","Separate laundry","Double garage","Compact efficient design"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('burano', 'Burano', 3, 2, 2, 230.58, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', '', 1, 12.0, 'burano', 'A generous three-bedroom home with expansive living areas and seamless indoor-outdoor flow.', 12.0, 21.5, 2, '', '["Master suite with ensuite & WIR","Expansive open-plan living","Separate lounge/media room","Kitchen with island bench","Walk-in pantry","Large covered alfresco","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('calabria', 'Calabria', 3, 2, 2, 164.89, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', '', 1, 12.0, 'calabria', 'A compact three-bedroom home designed for smart living.', 12.0, 16.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Covered alfresco","Separate laundry","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('capri', 'Capri', 4, 2, 2, 200.79, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', '', 1, 10.0, 'capri', 'A versatile four-bedroom home suitable for narrow lots.', 10.0, 22.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Narrow lot design (10m)","Covered alfresco","Walk-in pantry","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('carmada', 'Carmada', 4, 2, 2, 203.40, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 1, 12.5, 'carmada', 'A four-bedroom single-storey home with a practical layout.', 12.5, 19.0, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Walk-in pantry","Covered alfresco","Separate laundry","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('cassis', 'Cassis', 3, 1, 2, 128.84, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', '', 1, 10.0, 'cassis', 'A cleverly designed compact home, ideal for first home buyers or investors.', 10.0, 15.5, 1, '', '["Master bedroom with WIR","Open-plan kitchen/dining/living","Covered alfresco","Separate laundry","Double garage","Compact lot design"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('catalina', 'Catalina', 3, 2, 2, 210.32, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', '', 1, 12.0, 'catalina', 'A spacious three-bedroom home with a flowing open-plan layout.', 12.0, 20.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Kitchen with island bench","Walk-in pantry","Covered alfresco","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('corfu', 'Corfu', 4, 2, 2, 210.44, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', '', 1, 12.5, 'corfu', 'The Corfu is crafted with intention, offering grand appeal through generous, light-filled spaces designed for modern family living.', 11.15, 21.23, 2, '', '["Rear living flowing to alfresco","Kitchen with island bench for entertaining","Walk-in pantry","Master suite at rear with ensuite & WIR","Front multi-purpose room","Separate laundry with linen cupboard","Three minor bedrooms near entry","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height","Colorbond roof","Quality carpet to bedrooms"]'),
('cortona', 'Cortona', 4, 2, 2, 222.96, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', '', 1, 12.5, 'cortona', 'A generous four-bedroom home with well-defined living zones.', 12.5, 20.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Kitchen with island bench","Walk-in pantry","Covered alfresco","Separate laundry","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('crete', 'Crete', 4, 3, 2, 302.59, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 2, 12.5, 'crete', 'The Crete is a grand two-storey residence with multiple living zones, three bathrooms, and generous proportions.', 12.5, 22.0, 3, '', '["Three bathrooms including master ensuite","Ground floor open-plan living & dining","Gourmet kitchen with butler''s pantry","Upstairs rumpus room","Master suite with WIR & ensuite","Covered alfresco","Powder room downstairs","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height (ground)","2440mm ceiling height (upper)","Colorbond roof"]'),
('dervio', 'Dervio', 3, 2, 2, 267.61, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 1, 12.0, 'dervio', 'An expansive three-bedroom home with generous living spaces.', 12.0, 24.0, 2, '', '["Master suite with ensuite & WIR","Expansive open-plan living","Separate media/theatre room","Large covered alfresco","Kitchen with island & walk-in pantry","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('dublin', 'Dublin', 4, 2, 2, 180.16, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', '', 1, 12.5, 'dublin', 'A well-balanced four-bedroom home with a practical layout.', 12.5, 17.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Covered alfresco","Walk-in pantry","Separate laundry","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('elba', 'Elba', 4, 2, 2, 200.10, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', '', 1, 12.5, 'elba', 'A four-bedroom home offering well-proportioned rooms.', 12.5, 19.0, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Walk-in pantry","Covered alfresco","Separate laundry","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('evora', 'Evora', 3, 2, 2, 210.99, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', '', 1, 12.0, 'evora', 'A spacious three-bedroom design with generous proportions.', 12.0, 20.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Kitchen with island bench","Walk-in pantry","Covered alfresco","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('faro', 'Faro', 4, 2, 2, 172.97, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', '', 1, 12.0, 'faro', 'A smart four-bedroom home that delivers impressive living on a moderate footprint.', 12.0, 17.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Covered alfresco","Walk-in pantry","Separate laundry","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('geneva', 'Geneva', 4, 2, 2, 200.96, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 1, 10.0, 'geneva', 'A versatile four-bedroom home designed for narrow lots.', 10.0, 22.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Narrow lot design (10m)","Walk-in pantry","Covered alfresco","Double garage"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('havana', 'Havana', 4, 2, 2, 235.00, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', '', 1, 12.5, 'havana', 'The Havana is a stylish four-bedroom home with flowing living areas and a dedicated theatre room.', 12.5, 21.0, 2, '', '["Master suite with ensuite & walk-in robe","Dedicated theatre room","Open-plan kitchen/dining/living","Kitchen with island bench","Walk-in pantry","Covered alfresco entertaining","Separate laundry with linen","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height","Colorbond roof","Quality carpet to bedrooms"]'),
('lazio', 'Lazio', 4, 2, 2, 250.00, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', '', 1, 12.0, 'lazio', 'A generous four-bedroom home with separate living zones and premium proportions.', 12.0, 23.0, 2, '', '["Master suite with ensuite & WIR","Separate lounge room","Open-plan kitchen/dining/living","Kitchen with island & walk-in pantry","Large covered alfresco","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('lisbon', 'Lisbon', 4, 2, 2, 220.00, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', '', 1, 12.5, 'lisbon', 'A well-designed four-bedroom home balancing style and practicality.', 12.5, 20.0, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Kitchen with island bench","Walk-in pantry","Covered alfresco","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('lyon', 'Lyon', 4, 2, 2, 240.00, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', '', 1, 12.0, 'lyon', 'A spacious four-bedroom home with elegant proportions.', 12.0, 22.5, 2, '', '["Master suite with ensuite & WIR","Separate retreat/lounge","Open-plan kitchen/dining/living","Kitchen with island & walk-in pantry","Large covered alfresco","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]'),
('madrid', 'Madrid', 4, 2, 2, 220.00, 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', '', 1, 12.0, 'madrid', 'A stylish four-bedroom residence with open-plan living.', 12.0, 20.5, 1, '', '["Master suite with ensuite & WIR","Open-plan kitchen/dining/living","Kitchen with island bench","Walk-in pantry","Covered alfresco","Double garage with internal access"]', '["Stone benchtops to kitchen","900mm stainless steel appliances","Ducted air conditioning","2590mm ceiling height"]')
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- SEED DATA — HOUSE & LAND PACKAGES
-- ============================================================

INSERT INTO house_land_packages (id, title, location, lot_size, home_design, price, image_url, is_new, lot_number, lot_frontage, lot_depth, land_price, house_price, spec_tier, title_date, council, zoning, build_time_estimate, inclusions) VALUES
('1', 'Corfu 210 at Harmony', 'Palmview, Sunshine Coast', '450m²', 'Corfu 210', '$685,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg', true, 'Lot 142', '15.0m', '30.0m', '$295,000', '$390,000', 'Messina', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '8–10 months', '["Site costs included","Driveway & crossover","Landscaping to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Window furnishings"]'),
('2', 'Crete 302 at Aura', 'Caloundra South, Sunshine Coast', '520m²', 'Crete 302', '$795,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', true, 'Lot 287', '17.3m', '30.1m', '$340,000', '$455,000', 'Portobello', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '10–12 months', '["Site costs included","Driveway & crossover","Premium landscaping package","Fencing to 3 boundaries","Letterbox & clothesline","Premium floor coverings","Ducted air conditioning","Dual roller blinds throughout"]'),
('3', 'Athens 163 at Harmony', 'Palmview, Sunshine Coast', '375m²', 'Athens 163', '$529,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', false, 'Lot 318', '12.5m', '30.0m', '$265,000', '$264,000', 'Volos', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '7–9 months', '["Site costs included","Driveway & crossover","Turf to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Roller blinds to bedrooms & living"]'),
('4', 'Alassio 280 at Pebble Creek', 'Caloundra West, Sunshine Coast', '600m²', 'Alassio 280', '$849,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', true, 'Lot 56', '20.0m', '30.0m', '$360,000', '$489,000', 'Portobello', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '9–11 months', '["Site costs included","Exposed aggregate driveway","Premium landscaping package","Fencing to 3 boundaries","Rendered letterbox","Premium floor coverings","Ducted air conditioning","Dual roller blinds throughout","Alfresco ceiling fan"]'),
('5', 'Barcelona 192 at Harmony', 'Palmview, Sunshine Coast', '420m²', 'Barcelona 192', '$615,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', false, 'Lot 205', '14.0m', '30.0m', '$285,000', '$330,000', 'Messina', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '8–10 months', '["Site costs included","Driveway & crossover","Landscaping to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Window furnishings"]'),
('6', 'Havana 235 at Aura', 'Caloundra South, Sunshine Coast', '480m²', 'Havana 235', '$725,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', true, 'Lot 411', '16.0m', '30.0m', '$310,000', '$415,000', 'Messina', 'Registering Q3 2025', 'Sunshine Coast Regional Council', 'Low Density Residential', '8–10 months', '["Site costs included","Driveway & crossover","Landscaping to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Window furnishings"]'),
('7', 'Amalfi 300 at Pebble Creek', 'Caloundra West, Sunshine Coast', '400m²', 'Amalfi 300', '$769,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', false, 'Lot 89', '12.5m', '32.0m', '$310,000', '$459,000', 'Messina', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Medium Density Residential', '10–12 months', '["Site costs included","Driveway & crossover","Landscaping to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Window furnishings"]'),
('8', 'Corfu 210 at Harmony', 'Palmview, Sunshine Coast', '430m²', 'Corfu 210', '$669,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg', false, 'Lot 167', '14.3m', '30.1m', '$280,000', '$389,000', 'Messina', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '8–10 months', '["Site costs included","Driveway & crossover","Landscaping to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Window furnishings"]'),
('9', 'Cassis 128 at Baringa', 'Baringa, Sunshine Coast', '320m²', 'Cassis 128', '$479,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', false, 'Lot 72', '10.0m', '32.0m', '$220,000', '$259,000', 'Volos', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '6–8 months', '["Site costs included","Driveway & crossover","Turf to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Roller blinds to bedrooms & living"]'),
('10', 'Lyon 240 at Aura', 'Caloundra South, Sunshine Coast', '510m²', 'Lyon 240', '$745,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', true, 'Lot 334', '17.0m', '30.0m', '$320,000', '$425,000', 'Messina', 'Registering Q4 2025', 'Sunshine Coast Regional Council', 'Low Density Residential', '8–10 months', '["Site costs included","Driveway & crossover","Landscaping to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Window furnishings"]'),
('11', 'Dublin 180 at Baringa', 'Baringa, Sunshine Coast', '390m²', 'Dublin 180', '$595,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', false, 'Lot 118', '13.0m', '30.0m', '$260,000', '$335,000', 'Messina', 'Titled — Ready Now', 'Sunshine Coast Regional Council', 'Low Density Residential', '8–10 months', '["Site costs included","Driveway & crossover","Landscaping to front yard","Fencing to 3 boundaries","Letterbox & clothesline","Floor coverings throughout","Ducted air conditioning","Window furnishings"]')
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- SEED DATA — BLOG POSTS
-- ============================================================

INSERT INTO blog_posts (id, title, subtitle, category, image_url, date, read_time, content) VALUES
('1', 'Choosing the Right Facade for Your New Home', 'Our design team shares tips on creating a stunning first impression with your home''s exterior.', 'Design Tips', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg', now() - interval '2 days', '4 min read', 'Your facade is the first thing people see when they visit your home, and it sets the tone for everything inside. At AVIA Homes, we offer four distinct facade styles — Contemporary, Classic, Coastal, and Resort — each designed to complement different streetscapes and personal tastes.'),
('2', 'AVIA Homes Wins HIA Award for Best Display Home', 'We''re thrilled to announce our Corfu 210 display has been recognised for outstanding design.', 'Company News', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', now() - interval '5 days', '3 min read', 'We are proud to announce that AVIA Homes has been awarded the HIA Award for Best Display Home for our Corfu 210 design at the Harmony estate in Palmview.'),
('3', 'Understanding Your Build Timeline', 'A complete guide to what happens at each stage of your new home construction.', 'Build Guide', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', now() - interval '8 days', '6 min read', 'Building a new home is one of the most exciting journeys you''ll ever take, and understanding the timeline helps you feel confident every step of the way.'),
('4', 'Top 5 Kitchen Trends for 2025', 'From stone benchtops to integrated appliances, discover what''s defining modern kitchens this year.', 'Design Tips', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', now() - interval '12 days', '5 min read', 'The kitchen remains the heart of every home, and 2025 brings exciting new trends that elevate both style and function.'),
('5', 'Sustainability at AVIA Homes', 'How we''re building energy-efficient homes that reduce your footprint and your bills.', 'Company News', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', now() - interval '15 days', '4 min read', 'At AVIA Homes, sustainability isn''t an add-on — it''s built into every home we create.'),
('6', 'Choosing the Perfect Colour Palette', 'Expert tips for selecting colours that create harmony throughout your new home.', 'Design Tips', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', now() - interval '20 days', '5 min read', 'Selecting colours for your new home can feel overwhelming with so many options available.'),
('7', 'New Display Home Now Open at Aura', 'Visit our latest display featuring the Havana 235 with Portobello specifications.', 'Company News', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg', now() - interval '25 days', '3 min read', 'We''re excited to open the doors to our newest display home — the Havana 235 at Aura, Caloundra South.'),
('8', 'First Home Buyer''s Guide to Building', 'Everything you need to know about building your first home with AVIA.', 'Build Guide', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', now() - interval '30 days', '7 min read', 'Building your first home is an exciting milestone, and at AVIA Homes we''re here to make the process as smooth and enjoyable as possible.')
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- SEED DATA — LAND ESTATES
-- ============================================================

INSERT INTO land_estates (id, name, location, suburb, status, total_lots, available_lots, price_from, image_url, description, features, expected_completion, logo_url, logo_asset_name, brochure_url, site_map_url, site_map_asset_name) VALUES
('aura', 'Aura', 'Caloundra South, Sunshine Coast', 'Caloundra South', 'Current', 320, 47, '$320,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg', 'A thriving master-planned community on the Sunshine Coast featuring parks, schools, and a vibrant town centre.', '["Parks & playgrounds","Schools nearby","Shopping precinct","Walking & cycling trails","Community centre"]', 'Stages releasing progressively', NULL, 'estate_logo_aura', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', NULL, 'sitemap_aura'),
('harmony', 'Harmony', 'Palmview, Sunshine Coast', 'Palmview', 'Current', 260, 32, '$295,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg', 'Nestled in the heart of Palmview, Harmony is a modern residential community designed for families.', '["Town centre","Sports fields","Primary school","Lake & parklands","Café precinct"]', 'Final stages now selling', NULL, 'estate_logo_harmony', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', NULL, 'sitemap_harmony'),
('pebble-creek', 'Pebble Creek', 'Caloundra West, Sunshine Coast', 'Caloundra West', 'Current', 180, 24, '$310,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg', 'A boutique estate offering premium lots in a peaceful setting.', '["Boutique community","Near beaches","Landscaped streetscapes","Walking paths","Close to schools"]', 'Limited lots remaining', NULL, 'estate_logo_pebble_creek', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', NULL, 'sitemap_pebble_creek'),
('meridian-plains', 'Meridian Plains', 'Meridian Plains, Sunshine Coast', 'Meridian Plains', 'Upcoming', 145, 145, '$340,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg', 'An exciting new estate launching soon in the growing Meridian Plains corridor.', '["New release","Variety of lot sizes","Future parklands","Central location","Close to Bruce Highway"]', 'Stage 1 — Q3 2025', NULL, NULL, NULL, NULL, NULL),
('caboolture-south', 'Riverton Rise', 'Caboolture South, Moreton Bay', 'Caboolture South', 'Upcoming', 200, 200, '$275,000', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg', 'A new community coming to the Moreton Bay region offering affordable family lots.', '["Affordable lots","Near train station","Schools nearby","Shopping centres","Community parks planned"]', 'Stage 1 — Q4 2025', NULL, NULL, NULL, NULL, NULL),
('baringa', 'Baringa Central', 'Baringa, Sunshine Coast', 'Baringa', 'Completed', 280, 0, 'Sold Out', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg', 'A fully sold community that set the standard for modern estate design on the Sunshine Coast.', '["Fully established","Town centre complete","Schools operational","Parks & recreation","Public transport links"]', 'Complete', NULL, NULL, NULL, NULL, NULL),
('nirimba', 'Nirimba', 'Nirimba, Sunshine Coast', 'Nirimba', 'Completed', 150, 0, 'Sold Out', 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg', 'One of AVIA''s earliest partner estates, Nirimba is a fully developed community.', '["Established community","Mature landscaping","Walking trails","Near schools","Local shops"]', 'Complete', NULL, NULL, NULL, NULL, NULL)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- SEED DATA — FACADES
-- ============================================================

INSERT INTO facades (id, name, style, description, hero_image_url, gallery_image_urls, features, pricing_type, pricing_amount, storeys) VALUES
('airlie', 'Airlie', 'Modern & Refined', 'The Airlie facade delivers a fresh, modern aesthetic with clean lines and balanced proportions.', 'https://framerusercontent.com/images/9iQpPTg9RLwtwKHf8mf6tv9ZeY.jpg', '["https://framerusercontent.com/images/9iQpPTg9RLwtwKHf8mf6tv9ZeY.jpg"]', '["Render & cladding material mix","Clean modern lines","Feature entry portico","Aluminium window frames","Modern garage door design","Colorbond roof"]', 'included', NULL, 1),
('ascot', 'Ascot', 'Elegant Street Presence', 'The Ascot facade brings an elevated level of sophistication to your streetscape.', 'https://framerusercontent.com/images/zWqrIv68xuBD0qm5ufh47n7ha0.jpg', '["https://framerusercontent.com/images/zWqrIv68xuBD0qm5ufh47n7ha0.jpg"]', '["Premium render finish","Refined facade detailing","Feature window surrounds","Upgraded entry portico","Designer garage door","Colorbond roof"]', 'upgrade', '$7,500', 1),
('austin', 'Austin', 'Bold Contemporary', 'The Austin facade makes a bold architectural statement with dramatic material contrasts.', 'https://framerusercontent.com/images/8RrJdVdDeF0ATmZOfOxZ6NnbSg.jpg', '["https://framerusercontent.com/images/8RrJdVdDeF0ATmZOfOxZ6NnbSg.jpg"]', '["Premium material contrasts","Expansive glazing","Architectural feature elements","Dark tone accents","Flat or low-pitch roofline","Designer garage door"]', 'upgrade', '$15,000', 1),
('botany', 'Botany', 'Subtle Upgrade', 'The Botany facade offers an affordable upgrade with enhanced render detailing.', 'https://framerusercontent.com/images/qfUU21CHeV6uwDA6vRgSD6ccp74.jpg', '["https://framerusercontent.com/images/qfUU21CHeV6uwDA6vRgSD6ccp74.jpg"]', '["Enhanced render detailing","Refined proportions","Feature entry design","Quality window frames","Modern garage door","Colorbond roof"]', 'upgrade', '$2,000', 1),
('bridgehampton', 'Bridgehampton', 'Hamptons Inspired', 'The Bridgehampton facade captures the timeless elegance of Hamptons-style living.', 'https://framerusercontent.com/images/rchDQHmGaopGtW2Y6nhw0DwkZU.jpg', '["https://framerusercontent.com/images/rchDQHmGaopGtW2Y6nhw0DwkZU.jpg"]', '["Weatherboard cladding","White trim details","Covered front porch","Traditional pitched roof","Hamptons-style proportions","Feature entry"]', 'upgrade', '$7,500', 1),
('brooklyn', 'Brooklyn', 'Luxury Industrial', 'The Brooklyn facade is our premium offering, combining industrial-inspired elements with luxury finishes.', 'https://framerusercontent.com/images/v6QhtxHqBkYANAWfvDxDYqV8A4.jpg', '["https://framerusercontent.com/images/v6QhtxHqBkYANAWfvDxDYqV8A4.jpg"]', '["Premium dark brick","Metal cladding accents","Expansive window glazing","Architectural feature walls","Designer entry","Premium garage door"]', 'upgrade', '$25,000', 2),
('byron', 'Byron', 'Coastal Relaxed', 'Inspired by the laid-back coastal lifestyle of Byron Bay.', 'https://framerusercontent.com/images/lH6oSEDbTnXNHoqYQqH6JXY6aV0.jpg', '["https://framerusercontent.com/images/lH6oSEDbTnXNHoqYQqH6JXY6aV0.jpg"]', '["Timber-look accents","Natural material tones","Coastal-inspired detailing","Relaxed proportions","Feature entry","Colorbond roof"]', 'upgrade', '$3,000', 1),
('carolina', 'Carolina', 'Classic & Clean', 'The Carolina facade offers a classic, timeless design with clean lines.', 'https://framerusercontent.com/images/7N3UQTEUq2LA6L0iTYkkEMTfBeg.jpg', '["https://framerusercontent.com/images/7N3UQTEUq2LA6L0iTYkkEMTfBeg.jpg"]', '["Quality render finish","Balanced proportions","Traditional roofline","Feature window surrounds","Covered entry","Colorbond roof"]', 'included', NULL, 1),
('cedarvale', 'Cedarvale', 'Natural Warmth', 'The Cedarvale facade brings natural warmth and character to your home.', 'https://framerusercontent.com/images/wgfeJHpLGh2QbTMSl2C7fauwJeg.jpg', '["https://framerusercontent.com/images/wgfeJHpLGh2QbTMSl2C7fauwJeg.jpg"]', '["Timber-look feature elements","Earthy tone palette","Modern design lines","Feature entry portico","Quality window frames","Colorbond roof"]', 'included', NULL, 1),
('fairhaven', 'Fairhaven', 'Timeless Appeal', 'The Fairhaven facade delivers timeless street appeal with its classic brick and render combination.', 'https://framerusercontent.com/images/mkM136Wotu7CNfm4wE1w9Q6pr1Y.jpg', '["https://framerusercontent.com/images/mkM136Wotu7CNfm4wE1w9Q6pr1Y.jpg"]', '["Brick & render combination","Pitched roofline","Balanced proportions","Feature window details","Covered entry porch","Colorbond roof"]', 'included', NULL, 1),
('fortitude', 'Fortitude', 'Strong & Modern', 'The Fortitude facade makes a strong, modern impression.', 'https://framerusercontent.com/images/m8FMNUc8t7l3M5kat0bU0pGR5E.jpg', '["https://framerusercontent.com/images/m8FMNUc8t7l3M5kat0bU0pGR5E.jpg"]', '["Bold geometric lines","Contemporary material mix","Clean architectural detailing","Modern entry design","Quality window frames","Colorbond roof"]', 'included', NULL, 1),
('lennox', 'Lennox', 'Coastal Contemporary', 'The Lennox facade blends coastal style with contemporary design.', 'https://framerusercontent.com/images/RW3SG6TE5GJXrOK24uiEyv7s9lc.jpg', '["https://framerusercontent.com/images/RW3SG6TE5GJXrOK24uiEyv7s9lc.jpg"]', '["Coastal-inspired cladding","Light tone palette","Contemporary clean lines","Feature entry design","Modern window frames","Colorbond roof"]', 'upgrade', '$4,500', 1),
('milton', 'Milton', 'Urban Modern', 'The Milton facade brings urban sophistication.', 'https://framerusercontent.com/images/skY5JJqw84PNr7HCEqu2NmmtSs.jpg', '["https://framerusercontent.com/images/skY5JJqw84PNr7HCEqu2NmmtSs.jpg"]', '["Urban modern aesthetic","Sharp clean detailing","Contemporary material palette","Feature entry portico","Aluminium window frames","Colorbond roof"]', 'included', NULL, 1),
('newstead', 'Newstead', 'Refined Elegance', 'The Newstead facade exudes refined elegance with premium render finishes.', 'https://framerusercontent.com/images/YgPCkS8rcoqqs9ghs0jI9hzPoI4.jpg', '["https://framerusercontent.com/images/YgPCkS8rcoqqs9ghs0jI9hzPoI4.jpg"]', '["Premium render finishes","Sophisticated proportions","Detailed feature elements","Upgraded entry design","Quality window surrounds","Colorbond roof"]', 'upgrade', '$4,500', 1),
('noosa', 'Noosa', 'Resort Living', 'Inspired by the premium resort lifestyle of Noosa.', 'https://framerusercontent.com/images/FGXRcXDp6QNNvU0BZ8FUHPYYw8.jpg', '["https://framerusercontent.com/images/FGXRcXDp6QNNvU0BZ8FUHPYYw8.jpg"]', '["Resort-inspired design","Light tone palette","Quality material combinations","Relaxed proportions","Feature entry","Colorbond roof"]', 'included', NULL, 1),
('oceanside', 'Oceanside', 'Premium Coastal', 'The Oceanside facade is our premium coastal offering.', 'https://framerusercontent.com/images/vuu7WDlQk36JILwsxxwwZY1rHOg.jpg', '["https://framerusercontent.com/images/vuu7WDlQk36JILwsxxwwZY1rHOg.jpg"]', '["Premium weatherboard cladding","Expansive glazing","Luxury coastal detailing","Covered verandah","Premium entry design","Designer garage door"]', 'upgrade', '$25,000', 1),
('oslo', 'Oslo', 'Scandinavian Minimal', 'The Oslo facade draws inspiration from Scandinavian design.', 'https://framerusercontent.com/images/OJNizu75GAP8UrNGS6Sbt6VWlA.jpg', '["https://framerusercontent.com/images/OJNizu75GAP8UrNGS6Sbt6VWlA.jpg"]', '["Scandinavian-inspired design","Minimalist clean lines","Restrained material palette","Geometric proportions","Modern entry design","Premium window frames"]', 'upgrade', '$7,500', 1),
('paddington', 'Paddington', 'Heritage Character', 'The Paddington facade pays tribute to Queensland''s heritage character homes.', 'https://framerusercontent.com/images/WZ0rOOUECThfBC0PExJvdoVsHk.jpg', '["https://framerusercontent.com/images/WZ0rOOUECThfBC0PExJvdoVsHk.jpg"]', '["Heritage-inspired design","Traditional proportions","Verandah details","Character elements","Quality finishes","Colorbond roof"]', 'included', NULL, 1),
('portland', 'Portland', 'Luxury Statement', 'The Portland is our most premium facade.', 'https://framerusercontent.com/images/2GsNaAlwxrMUxoKHc2Fu3xQWLg.jpg', '["https://framerusercontent.com/images/2GsNaAlwxrMUxoKHc2Fu3xQWLg.jpg"]', '["Ultra-premium finishes","Architectural feature walls","Expansive glazing","Feature lighting package","Dark tone palette","Premium garage door"]', 'upgrade', '$35,000', 2),
('seabrook', 'Seabrook', 'Coastal Classic', 'The Seabrook facade combines coastal charm with classic design principles.', 'https://framerusercontent.com/images/js0xz7lml9J3ixKeUyob3zUJQQ4.jpg', '["https://framerusercontent.com/images/js0xz7lml9J3ixKeUyob3zUJQQ4.jpg"]', '["Coastal-inspired cladding","Light colour palette","Classic proportions","Quality detailing","Feature entry","Colorbond roof"]', 'included', NULL, 1),
('yamba', 'Yamba', 'Relaxed Coastal', 'Named after the beloved coastal town, the Yamba facade captures the essence of relaxed coastal living.', 'https://framerusercontent.com/images/xRNBgo5b9nipPbWYteT5lR8R5A.jpg', '["https://framerusercontent.com/images/xRNBgo5b9nipPbWYteT5lR8R5A.jpg"]', '["Natural coastal tones","Clean modern lines","Welcoming street presence","Quality render finish","Feature entry","Colorbond roof"]', 'included', NULL, 1)
ON CONFLICT (id) DO NOTHING;
