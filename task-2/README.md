# Task 2 — Database Schema Design & Query Optimization

> **Week 2 | Junior SQL Data Analyst Intern Assessment**
> Focus: Relational schema design, ER relationships, SQL reporting, and query optimization
> Database: PostgreSQL 15+

---

## Overview

This task proposes a fully normalized relational database for an **Agribusiness Data Analysis Platform**. The design covers:

- Farm and geographic information
- Crop production and harvest records
- Livestock inventory and periodic observations
- Market price tracking across commodities

---

## Repository Structure

```
task-2/
├── docs/
│   └── Database_Schema_Design_Query_Optimization_Week2.docx   ← Assessment brief
└── sql/
    ├── 01_schema.sql               ← Full DDL: tables, PKs, FKs, constraints
    ├── 02_indexes.sql              ← Query-driven index strategy
    ├── 03_sample_data.sql          ← Illustrative seed data (10 farms, 10 crops…)
    ├── 04_analytical_queries.sql   ← All reporting queries from the assessment
    └── 05_optimization_and_validation.sql  ← EXPLAIN ANALYZE, ANALYZE, data quality checks
```

---

## Database Schema

### Entity-Relationship Overview

```
REGION (1) ──────────< FARM (many)
                           │
                           ├────────< HARVEST >──────── CROP
                           │             many              1
                           │
                           └────< LIVESTOCK_OBSERVATION >── LIVESTOCK_TYPE
                                          many                     1

REGION (1) ──────────< MARKET (many)
                           │
                           └────────< MARKET_PRICE >──── CROP
                                          many              1
```

### Reference Tables

| Table | Primary Key | Key Attributes |
|---|---|---|
| `region` | `region_id` | `region_name`, `country_code` |
| `farm` | `farm_id` | `farm_code` (UNIQUE), `region_id` FK, `area_hectares` |
| `crop` | `crop_id` | `crop_name` (UNIQUE), `crop_category`, `standard_unit` |
| `livestock_type` | `livestock_type_id` | `type_name` (UNIQUE), `production_purpose` |
| `market` | `market_id` | `market_name`, `region_id` FK, `market_type` |

### Fact Tables

| Table | Primary Key | Key Attributes |
|---|---|---|
| `harvest` | `harvest_id` | `farm_id`, `crop_id`, `season_year`, `harvest_date`, `area_planted_ha`, `quantity_tonnes` |
| `livestock_observation` | `observation_id` | `farm_id`, `livestock_type_id`, `observed_on`, `animal_count` |
| `market_price` | `price_id` | `market_id`, `crop_id`, `observed_on`, `price_per_tonne`, `currency_code` |

---

## How to Run

```sql
-- Run in order:
\i sql/01_schema.sql
\i sql/02_indexes.sql
\i sql/03_sample_data.sql
\i sql/04_analytical_queries.sql
\i sql/05_optimization_and_validation.sql
```

Or with `psql`:

```bash
psql -U your_user -d your_db -f sql/01_schema.sql
psql -U your_user -d your_db -f sql/02_indexes.sql
psql -U your_user -d your_db -f sql/03_sample_data.sql
psql -U your_user -d your_db -f sql/04_analytical_queries.sql
psql -U your_user -d your_db -f sql/05_optimization_and_validation.sql
```

---

## Queries Covered

| Query | Business Question |
|---|---|
| Annual production by region | Which region+crop had the greatest output in a given year? |
| Yield by crop & season | Which crops had the highest tonnes-per-hectare in 2025? |
| Monthly market price trend | How do commodity prices move month-to-month? |
| Latest livestock counts | Most recent animal count per farm and livestock type |
| Farms above output threshold | Which farms exceeded 100 tonnes in 2025? |
| Production vs. price (bonus) | Estimated revenue by region for Wheat in 2025 |
| Season-over-season change (bonus) | Percentage change in farm output from 2024 to 2025 |

---

## Design Principles

| Principle | Decision |
|---|---|
| **Normalization** | Reference data stored once; referenced by foreign keys |
| **Fact separation** | Harvest, livestock, and market prices are distinct tables |
| **Referential integrity** | All FK relationships enforced; NOT NULL on core columns |
| **Time-aware records** | `season_year` / `observed_on` on every fact table |
| **Consistent units** | `standard_unit` defined per crop; currency stored as ISO code |
| **Query-driven indexes** | Indexes selected from actual filter/join patterns |
