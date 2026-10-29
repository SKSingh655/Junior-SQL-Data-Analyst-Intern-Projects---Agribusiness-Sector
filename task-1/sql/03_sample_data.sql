-- =====================================================================
-- File: 03_sample_data.sql  (tiny demo data; run on a freshly created schema)
-- =====================================================================
SET search_path TO agri;

INSERT INTO dim_region (state_name, district, latitude, longitude) VALUES
 ('Uttar Pradesh','Gautam Buddha Nagar',28.4744,77.5040),
 ('Punjab','Ludhiana',30.9010,75.8573),
 ('Maharashtra','Nashik',19.9975,73.7898);

INSERT INTO dim_farm (region_id, farm_name, farm_type, total_area_ha) VALUES
 (1,'Farm-UP-001','crop',4.50),
 (2,'Farm-PB-001','mixed',8.00),
 (3,'Farm-MH-001','crop',3.20);

INSERT INTO dim_crop (crop_name, crop_category, typical_season, avg_duration_days) VALUES
 ('Wheat','cereal','rabi',140),
 ('Rice','cereal','kharif',125),
 ('Tomato','vegetable','zaid',110),
 ('Onion','vegetable','rabi',120);

INSERT INTO dim_livestock_species (species_name, primary_purpose) VALUES
 ('Cattle','milk'), ('Buffalo','milk'), ('Poultry','eggs');

INSERT INTO dim_market (region_id, market_name, market_type) VALUES
 (1,'Noida Mandi','mandi'), (2,'Ludhiana Mandi','mandi'), (3,'Lasalgaon Mandi','mandi');

INSERT INTO fact_crop_production
 (farm_id, crop_id, season_year, season, area_planted_ha, production_tonnes, irrigation_type) VALUES
 (1,1,2023,'rabi',3.00,14.10,'canal'), (1,1,2024,'rabi',3.00,15.30,'canal'),
 (2,1,2023,'rabi',5.00,26.00,'tubewell'), (2,1,2024,'rabi',5.00,27.40,'tubewell'),
 (2,2,2023,'kharif',4.00,22.00,'tubewell'), (2,2,2024,'kharif',4.00,23.20,'tubewell'),
 (3,4,2023,'rabi',2.50,45.00,'drip'), (3,4,2024,'rabi',2.50,41.50,'drip');

INSERT INTO fact_input_usage (farm_id, crop_id, season_year, input_type, quantity, unit, cost) VALUES
 (1,1,2024,'seed',120,'kg',4200), (1,1,2024,'fertilizer',450,'kg',9800),
 (2,1,2024,'seed',200,'kg',7000), (2,1,2024,'fertilizer',800,'kg',17500),
 (3,4,2024,'seed',10,'kg',9000),  (3,4,2024,'labour',60,'days',24000);

INSERT INTO fact_sales (farm_id, crop_id, market_id, sale_date, quantity_tonnes, price_per_tonne) VALUES
 (1,1,1,'2024-04-20',15.30,24000), (2,1,2,'2024-04-25',27.40,24500),
 (3,4,3,'2024-05-10',41.50,18000);

INSERT INTO fact_market_price
 (market_id, crop_id, price_date, min_price, max_price, modal_price, arrivals_tonnes) VALUES
 (1,1,'2024-04-01',2200,2450,2350,120), (1,1,'2024-04-02',2210,2460,2360,135),
 (1,1,'2024-04-03',2190,2440,2340,128), (3,4,'2024-04-01',1400,2000,1800,540),
 (3,4,'2024-04-02',1450,2050,1850,520), (3,4,'2024-04-03',1500,2100,1900,495);

INSERT INTO fact_soil_test (farm_id, test_date, ph, nitrogen_kg_ha, phosphorus_kg_ha, potassium_kg_ha, organic_carbon_pct) VALUES
 (1,'2024-06-10',7.4,250,18,160,0.45), (2,'2024-06-12',8.1,300,9,120,0.62),
 (3,'2024-06-15',6.2,210,7,95,0.38);
