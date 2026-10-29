-- =============================================================================
-- Task 2 | Week 2 Internship Assessment
-- SAMPLE DATA
-- Agribusiness Data Analysis Platform
-- Database: PostgreSQL 15+
-- =============================================================================
-- Illustrative rows for schema validation and query testing.
-- All values are fictional; they are not claims about any real organization.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- REFERENCE TABLES
-- -----------------------------------------------------------------------------

INSERT INTO region (region_name, country_code) VALUES
  ('Punjab',      'IND'),
  ('Haryana',     'IND'),
  ('Maharashtra', 'IND'),
  ('Karnataka',   'IND'),
  ('Rajasthan',   'IND');

INSERT INTO crop (crop_name, crop_category, standard_unit) VALUES
  ('Wheat',       'Cereal',     'tonne'),
  ('Rice',        'Cereal',     'tonne'),
  ('Maize',       'Cereal',     'tonne'),
  ('Sugarcane',   'Cash Crop',  'tonne'),
  ('Cotton',      'Cash Crop',  'tonne'),
  ('Soybean',     'Oilseed',    'tonne'),
  ('Mustard',     'Oilseed',    'tonne'),
  ('Groundnut',   'Oilseed',    'tonne'),
  ('Tomato',      'Vegetable',  'tonne'),
  ('Onion',       'Vegetable',  'tonne');

INSERT INTO livestock_type (type_name, production_purpose) VALUES
  ('Dairy Cattle',  'Milk production'),
  ('Beef Cattle',   'Meat production'),
  ('Poultry',       'Eggs and meat'),
  ('Goat',          'Milk and meat'),
  ('Sheep',         'Wool and meat'),
  ('Buffalo',       'Milk and draught');

INSERT INTO market (market_name, region_id, market_type) VALUES
  ('Amritsar Mandi',    1, 'Wholesale'),
  ('Ludhiana Mandi',    1, 'Wholesale'),
  ('Karnal APMC',       2, 'APMC'),
  ('Pune Agricultural', 3, 'Wholesale'),
  ('Hubli Mandi',       4, 'Wholesale'),
  ('Jaipur Mandi',      5, 'Wholesale');

INSERT INTO farm (farm_code, farm_name, region_id, area_hectares) VALUES
  ('PB-F001', 'Singh Agro Farm',       1,  85.50),
  ('PB-F002', 'Gill Family Estate',    1, 120.00),
  ('HR-F001', 'Haryana Green Fields',  2,  60.25),
  ('HR-F002', 'Shekhawat Crops',       2,  95.75),
  ('MH-F001', 'Deccan Agri Pvt Ltd',   3, 200.00),
  ('MH-F002', 'Nashik Farms Co.',      3, 150.00),
  ('KA-F001', 'Tungabhadra Farms',     4,  75.00),
  ('RJ-F001', 'Desert Bloom Agro',     5,  45.00),
  ('RJ-F002', 'Thar Cultivation Ltd',  5,  55.50),
  ('PB-F003', 'Chandigarh Organics',   1,  30.00);

-- -----------------------------------------------------------------------------
-- FACT TABLES
-- -----------------------------------------------------------------------------

-- HARVEST (2024 and 2025 seasons)
INSERT INTO harvest (farm_id, crop_id, season_year, harvest_date, area_planted_ha, quantity_tonnes) VALUES
  -- Punjab farms - Wheat (2024)
  (1, 1, 2024, '2024-04-10',  80.00, 400.000),
  (2, 1, 2024, '2024-04-15', 115.00, 552.000),
  (10,1, 2024, '2024-04-20',  28.00, 126.000),
  -- Punjab farms - Rice (2024)
  (1, 2, 2024, '2024-11-05',  70.00, 315.000),
  (2, 2, 2024, '2024-11-08', 100.00, 470.000),
  -- Haryana - Wheat (2024)
  (3, 1, 2024, '2024-04-12',  55.00, 264.000),
  (4, 1, 2024, '2024-04-18',  90.00, 423.000),
  -- Haryana - Mustard (2024)
  (3, 7, 2024, '2024-03-28',  30.00,  48.000),
  (4, 7, 2024, '2024-03-30',  40.00,  62.400),
  -- Maharashtra - Sugarcane (2024)
  (5, 4, 2024, '2024-12-01', 180.00, 9720.000),
  (6, 4, 2024, '2024-12-10', 130.00, 7020.000),
  -- Maharashtra - Soybean (2024)
  (5, 6, 2024, '2024-10-20',  50.00, 100.000),
  (6, 6, 2024, '2024-10-25',  40.00,  78.000),
  -- Karnataka - Rice (2024)
  (7, 2, 2024, '2024-09-15',  70.00, 294.000),
  -- Karnataka - Maize (2024)
  (7, 3, 2024, '2024-07-20',  30.00,  72.000),
  -- Rajasthan - Mustard (2024)
  (8, 7, 2024, '2024-03-20',  40.00,  60.000),
  (9, 7, 2024, '2024-03-22',  50.00,  77.500),
  -- 2025 season
  (1, 1, 2025, '2025-04-08',  82.00, 418.200),
  (2, 1, 2025, '2025-04-14', 116.00, 565.600),
  (3, 1, 2025, '2025-04-11',  57.00, 278.100),
  (4, 1, 2025, '2025-04-17',  91.00, 437.300),
  (5, 4, 2025, '2025-12-05', 185.00, 10175.000),
  (6, 6, 2025, '2025-10-22',  42.00,  84.840),
  (7, 2, 2025, '2025-09-18',  72.00, 309.600),
  (8, 7, 2025, '2025-03-19',  42.00,  65.100),
  (9, 3, 2025, '2025-07-30',  20.00,  46.000),
  (10,1, 2025, '2025-04-22',  29.00, 133.400);

-- LIVESTOCK_OBSERVATION
INSERT INTO livestock_observation (farm_id, livestock_type_id, observed_on, animal_count, average_weight_kg) VALUES
  (1, 1, '2025-01-15',  45, 430.00),
  (1, 1, '2025-04-15',  47, 445.00),
  (1, 1, '2025-07-15',  46, 440.00),
  (2, 1, '2025-01-10',  80, 425.00),
  (2, 1, '2025-07-10',  82, 432.00),
  (3, 4, '2025-02-01', 120,  38.50),
  (3, 4, '2025-05-01', 115,  39.00),
  (4, 6, '2025-01-20',  30, 490.00),
  (4, 6, '2025-07-20',  28, 485.00),
  (5, 3, '2025-03-01', 500,   2.80),
  (5, 3, '2025-06-01', 520,   2.90),
  (6, 2, '2025-02-15',  15, 380.00),
  (7, 4, '2025-01-10',  60,  37.00),
  (7, 4, '2025-07-10',  55,  38.00),
  (8, 5, '2025-03-10', 200,  45.00),
  (9, 5, '2025-03-12', 180,  43.00),
  (10,1, '2025-01-25',  12, 420.00),
  (10,1, '2025-07-25',  14, 435.00);

-- MARKET_PRICE (2025 monthly observations, INR per tonne)
INSERT INTO market_price (market_id, crop_id, observed_on, price_per_tonne, currency_code) VALUES
  -- Wheat - Amritsar
  (1, 1, '2025-01-15', 22500.00, 'INR'),
  (1, 1, '2025-02-15', 22800.00, 'INR'),
  (1, 1, '2025-03-15', 23200.00, 'INR'),
  (1, 1, '2025-04-15', 24000.00, 'INR'),
  (1, 1, '2025-05-15', 23600.00, 'INR'),
  (1, 1, '2025-06-15', 23100.00, 'INR'),
  -- Wheat - Ludhiana
  (2, 1, '2025-01-15', 22400.00, 'INR'),
  (2, 1, '2025-04-15', 23900.00, 'INR'),
  (2, 1, '2025-07-15', 23300.00, 'INR'),
  -- Rice - Karnal
  (3, 2, '2025-01-20', 34500.00, 'INR'),
  (3, 2, '2025-04-20', 35200.00, 'INR'),
  (3, 2, '2025-07-20', 36000.00, 'INR'),
  (3, 2, '2025-10-20', 37500.00, 'INR'),
  -- Sugarcane - Pune
  (4, 4, '2025-01-10',  3200.00, 'INR'),
  (4, 4, '2025-04-10',  3350.00, 'INR'),
  (4, 4, '2025-07-10',  3500.00, 'INR'),
  (4, 4, '2025-10-10',  3650.00, 'INR'),
  -- Soybean - Hubli
  (5, 6, '2025-02-01', 45000.00, 'INR'),
  (5, 6, '2025-05-01', 46500.00, 'INR'),
  (5, 6, '2025-08-01', 47200.00, 'INR'),
  (5, 6, '2025-11-01', 48000.00, 'INR'),
  -- Mustard - Jaipur
  (6, 7, '2025-01-05', 55000.00, 'INR'),
  (6, 7, '2025-04-05', 53500.00, 'INR'),
  (6, 7, '2025-07-05', 54000.00, 'INR'),
  (6, 7, '2025-10-05', 56000.00, 'INR'),
  -- Cotton - Hubli (bonus)
  (5, 5, '2025-03-01', 65000.00, 'INR'),
  (5, 5, '2025-06-01', 67000.00, 'INR'),
  (5, 5, '2025-09-01', 68500.00, 'INR');
