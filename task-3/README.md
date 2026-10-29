# Task 3 — Data Extraction, Transformation & Loading (ETL)

> **Week 3 | Junior SQL Data Analyst Intern Assessment**
> Focus: Public data extraction, data cleaning, SQL transformation, database loading
> Stack: Python (requests/pandas) + PostgreSQL 15+

---

## Overview

This task implements a full **ETL pipeline** for the Agribusiness Analytics Platform. It describes how publicly available **crop production**, **market price**, and **weather** data can be collected, standardized, validated, and loaded into the relational database from Task 2 — without silently dropping any row.

---

## Repository Structure

```
task-3/
├── docs/
│   └── Week_3_Agribusiness_ETL_Process_Plan.docx   ← Assessment brief
├── python/
│   └── etl_extraction_adapter.py                   ← Extraction pseudocode (Python)
└── sql/
    ├── 01_etl_schema.sql           ← Batch audit, staging, crosswalk & curated extension tables
    ├── 03_staging_data.sql         ← Simulated raw rows (valid + intentionally invalid)
    ├── 04_transform_validate.sql   ← Validation, reject routing, unit conversion, parsed temps
    ├── 05_load_curated.sql         ← Idempotent upserts into curated tables
    └── 06_monitoring_tests.sql     ← Batch health, reconciliation, dupe checks, quality tests
```

> **Note:** `02_` is reserved for the Task 2 Week 2 schema (`01_schema.sql`).
> Run Task 2's schema first — Task 3 extends it.

---

## ETL Architecture

```
PUBLIC SOURCES
  ├─ Official API (JSON)        ─┐
  ├─ Bulk download (CSV/XLSX)   ─┼─→  EXTRACT ADAPTERS (Python)
  └─ Permitted HTML table       ─┘
                                        │
                                        ▼
                              RAW LANDING / ARCHIVE
                         (immutable payload + SHA-256 hash)
                                        │
                                        ▼
                              STAGING TABLES  (TEXT-first columns)
                         stg_market_price | stg_crop_production | stg_weather
                                        │
                                        ▼
                         VALIDATE + TRANSFORM + DEDUPE
                           ├─ accepted rows → parsed_* TEMP tables
                           └─ rejected rows → etl_reject (with reason code)
                                        │
                                        ▼
                              CURATED POSTGRESQL
                         market_price | crop_production_stat | weather_observation
                                        │
                                        ▼
                          SQL REPORTS / DASHBOARDS (Task 2 queries)
```

---

## Data Sources

| Domain | Candidate Source | Fields |
|---|---|---|
| Crop production | FAOSTAT (FAO) | Country-level area harvested, yield, production |
| Market prices | Agmarknet / DMI (India) | Commodity, mandi, date, variety, price |
| Weather | IMD / NASA POWER | Daily rainfall, temperature, humidity by region |
| Geography | Census of India / ISO 3166-2 | State/district codes → region mapping |

---

## Key Tables Created

### ETL Control Tables

| Table | Purpose |
|---|---|
| `etl_batch` | One row per pipeline run; tracks status and row counts |
| `etl_reject` | Quarantined invalid rows with `reason_code` and raw JSONB |

### Crosswalk / Alias Tables

| Table | Purpose |
|---|---|
| `crop_alias` | Maps source crop labels → `crop_id` |
| `geography_alias` | Maps source geo codes → `region_id` |
| `market_alias` | Maps source market labels → `market_id` |

### Staging Tables (text-first)

| Table | Source |
|---|---|
| `stg_market_price` | Agmarknet |
| `stg_crop_production` | FAOSTAT |
| `stg_weather` | IMD / NASA POWER |

### Curated Extension Tables

| Table | Description |
|---|---|
| `crop_production_stat` | Aggregate national crop stats (no farm_id invented) |
| `weather_observation` | Daily weather matched to region |

---

## How to Run

### Prerequisites
Run Task 2 schema first to create `region`, `farm`, `crop`, `market`, `market_price` etc.

```bash
# 1. Task 2 schema (from task-2/)
psql -d agri_db -f ../task-2/sql/01_schema.sql
psql -d agri_db -f ../task-2/sql/02_indexes.sql
psql -d agri_db -f ../task-2/sql/03_sample_data.sql

# 2. Task 3 ETL pipeline (from task-3/)
psql -d agri_db -f sql/01_etl_schema.sql
psql -d agri_db -f sql/03_staging_data.sql
psql -d agri_db -f sql/04_transform_validate.sql
psql -d agri_db -f sql/05_load_curated.sql
psql -d agri_db -f sql/06_monitoring_tests.sql
```

---

## Transformation Rules Applied

| Issue | Rule | Example |
|---|---|---|
| Whitespace/casing | `BTRIM()` + governed crosswalk table | `'  Wheat '` → `'Wheat'` |
| Dates | `TO_DATE()` with explicit format; reject ambiguous | `'2025-04-30'` → `DATE` |
| Numbers | Strip commas; regex-validate; reject malformed | `'1,250.50'` → `1250.50` |
| Units | Convert when source unit is known | `quintal` × 10 → price per tonne |
| Commodity names | `crop_alias` crosswalk table | `'Paddy'` → crop_id for Rice |
| Geography | `geography_alias` crosswalk table | `'IN-PB'` → Punjab region_id |
| Missing values | `NULLIF()` for empty strings; `NULL` for unknown | Blank rainfall ≠ 0 mm |
| Duplicates | `ON CONFLICT DO UPDATE` with business key | market + crop + date + currency |

---

## Reject Reason Codes

| Code | Meaning |
|---|---|
| `MISSING_MARKET` | Source market name is blank or NULL |
| `MISSING_CROP` | Source crop label is blank or NULL |
| `MISSING_GEO` | Geographic code is blank or NULL |
| `INVALID_DATE_FORMAT` | Date string does not match `YYYY-MM-DD` |
| `INVALID_PRICE` | Price string is non-numeric |
| `NEGATIVE_PRICE` | Price is a valid number but < 0 |
| `INVALID_AREA` | Area string is non-numeric |
| `NEGATIVE_AREA` | Area is valid but < 0 |
| `INVALID_PRODUCTION` | Production quantity is non-numeric |
| `INVALID_PERIOD` | Period string is not a 4-digit year |
| `INVALID_RAINFALL` | Rainfall string is non-numeric |
| `NEGATIVE_RAINFALL` | Rainfall is valid but < 0 |
| `INVALID_TEMP` | Temperature string is non-numeric |

---

## Monitoring Metrics (Section 6.2)

| Metric | Alert Condition |
|---|---|
| Batch completion | Run exceeds expected duration |
| Row-count variance | Daily count changes > agreed threshold |
| **Reject percentage** | **> 5% of extracted rows rejected** |
| Freshness lag | Latest data older than reporting SLA |
| Duplicate business keys | Any duplicate after deduplication |
| Reconciliation | `accepted + rejected ≠ extracted` |

---

## Implementation Roadmap

| Phase | Effort | Output |
|---|---|---|
| 1. Source discovery & access review | 4–5 hrs | Source inventory, formats, licence notes |
| 2. Extraction & raw landing | 5–6 hrs | Repeatable adapters + batch metadata |
| 3. Transformation & validation | 8–9 hrs | Crosswalk tables, staging, rejects, SQL transforms |
| 4. Database loading | 5–6 hrs | Transactional upserts, keys, indexes |
| 5. Testing & documentation | 6–8 hrs | Reconciliation tests, failure tests, runbook |

**Total: ~28–34 hours**
