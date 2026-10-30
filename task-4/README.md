# Task 4 — Data Aggregation & Business Reporting

> **Week 4 | Junior SQL Data Analyst Intern Assessment**
> Focus: SQL aggregation, agribusiness KPIs, reporting and visualization strategy
> Database: PostgreSQL 15+ | Builds on Task 2 schema + Task 3 ETL pipeline

---

## Overview

This task implements a **complete SQL-based business reporting framework** for the Agribusiness Analytics Platform. It defines eight KPI metrics, packages them as reusable views, generates all management-report sections from those views, and guards against the most common aggregation mistakes (fan-out joins, average-of-averages, mixed units).

---

## Repository Structure

```
task-4/
├── docs/
│   └── Week_4_Agribusiness_Data_Aggregation_Business_Reporting.docx
├── views/
│   ├── 01_kpi_views.sql          ← 7 SQL views (one per KPI)
│   └── 02_materialized_views.sql ← 2 materialized views for high-frequency dashboards
└── sql/
    ├── 01_production_yield_reports.sql   ← Production, yield, YoY change, concentration
    ├── 02_market_livestock_reports.sql   ← Price trends, market ranking, livestock snapshot
    ├── 03_reliability_performance.sql    ← Data quality, pitfall guards, EXPLAIN ANALYZE
    └── 04_executive_report.sql           ← Full management report (all sections in order)
```

---

## How to Run

### Prerequisites (run first)
```bash
# Task 2 — relational schema
psql -d agri_db -f ../task-2/sql/01_schema.sql
psql -d agri_db -f ../task-2/sql/02_indexes.sql
psql -d agri_db -f ../task-2/sql/03_sample_data.sql

# Task 3 — ETL schema + pipeline
psql -d agri_db -f ../task-3/sql/01_etl_schema.sql
psql -d agri_db -f ../task-3/sql/03_staging_data.sql
psql -d agri_db -f ../task-3/sql/04_transform_validate.sql
psql -d agri_db -f ../task-3/sql/05_load_curated.sql
```

### Task 4 — Reporting layer
```bash
# 1. Create KPI views and materialized views
psql -d agri_db -f views/01_kpi_views.sql
psql -d agri_db -f views/02_materialized_views.sql

# 2. Run reports
psql -d agri_db -f sql/01_production_yield_reports.sql
psql -d agri_db -f sql/02_market_livestock_reports.sql
psql -d agri_db -f sql/03_reliability_performance.sql
psql -d agri_db -f sql/04_executive_report.sql
```

---

## KPI Catalogue (Section 1.2)

| KPI | Formula / Definition | View | Decision Value |
|---|---|---|---|
| **Total Production** | `SUM(quantity_tonnes)` per crop, region, period | `v_annual_production` | Supply planning, procurement |
| **Crop Yield** | `SUM(production) / SUM(area_planted_ha)` | `v_annual_production` | Productivity comparison |
| **Production Change (%)** | `(current − prior) / prior × 100` via `LAG` | `v_yoy_production` | Growth/decline early warning |
| **Average Market Price** | `AVG(price_per_tonne)` — one currency, one grade | `v_monthly_market_price` | Selling timing, price monitoring |
| **Price Change (%)** | Month-over-month via `LAG` | `v_price_yoy` | Price direction and magnitude |
| **Livestock Inventory** | Latest `animal_count` per farm/type only | `v_latest_livestock` | Capacity and feed planning |
| **Production Concentration** | Region/crop share of total production | `v_production_concentration` | Supply-chain concentration risk |
| **Data Quality Rate** | `accepted_rows / extracted_rows × 100` | `v_data_quality_summary` | Confidence in reported figures |

---

## View Reference

| View | Purpose |
|---|---|
| `v_annual_production` | Production totals + yield per region/crop/season |
| `v_yoy_production` | Year-over-year production change with `trend_flag` |
| `v_monthly_market_price` | Monthly avg/min/max prices per crop/market/currency |
| `v_price_yoy` | Month-over-month price change % |
| `v_latest_livestock` | Latest snapshot per farm × livestock type |
| `v_production_concentration` | Share % of total production + `production_rank` |
| `v_data_quality_summary` | ETL batch health + quality/reject rate per source |

### Materialized Views

| View | Refresh Command |
|---|---|
| `mv_annual_production` | `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_annual_production;` |
| `mv_monthly_price_summary` | `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_price_summary;` |

> Refresh after every successful ETL load.

---

## Report Structure (Section 6.1)

| Section | Content | Visualization |
|---|---|---|
| **Executive Summary** | 5 headline KPI cards | KPI tiles with period and unit |
| **Production Overview** | Top 10 crop/region rankings + crop mix | Ranked bar chart; category donut |
| **Trend Analysis** | YoY production change + monthly price movement | Line charts with period labels |
| **Market Comparison** | Avg/min/max prices, market ranking, spread | Horizontal bar; price volatility table |
| **Livestock Snapshot** | Latest counts by region and type | Stacked bar or summary table |
| **Data Quality Note** | Freshness, row counts, rejects, health status | Status table with timestamp |

---

## Key Aggregation Rules

| Rule | Why It Matters |
|---|---|
| Aggregate each fact table independently before joining | Prevents fan-out row multiplication |
| `SUM(qty) / SUM(area)` for yield — not `AVG(farm yield)` | Avoids bias toward small farms |
| Always include `observations` count next to `AVG()` | `AVG` silently ignores NULLs; sparse data misleads |
| Never mix currencies in the same aggregation | `AVG(INR + USD)` is meaningless |
| Livestock = latest observation per farm/type only | Summing all history double-counts animals |
| Half-open date intervals: `>= start AND < end` | Sargable; index-friendly; includes all timestamps |

---

## Common Pitfalls Demonstrated (`03_reliability_performance.sql`)

- ❌ Fan-out join: `harvest JOIN market_price ON crop_id` — multiplies rows  
- ❌ Average of averages: `AVG(quantity / area)` per farm — area-biased  
- ✅ Correct yield: `SUM(quantity) / SUM(area)` after grouping  
- ✅ Correct cross-source join: aggregate independently, join on crop dimension  

---

## Implementation Workload (Section 7)

| Workstream | Effort | Output |
|---|---|---|
| Metric definitions & schema review | 4–5 hrs | KPI dictionary, grain and unit assumptions |
| SQL query design & validation | 8–9 hrs | Production, yield, price, livestock, change queries |
| Data quality & performance review | 5–6 hrs | Reconciliation, explain plans, index recommendations |
| Report layout & visual design | 5–6 hrs | Executive summary, tables, chart specifications |
| Testing, documentation & revision | 7–8 hrs | Reviewed queries, limitations, final report |

**Total: ~29–34 hours**
