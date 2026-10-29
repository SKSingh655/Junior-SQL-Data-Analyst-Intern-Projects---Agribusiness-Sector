# Task 1 — Agribusiness SQL Strategic Plan

> **Week 1 | Junior SQL Data Analyst Intern Assessment**
> Focus: Research, requirements, star schema data model, analytical queries, ETL error handling
> Database: PostgreSQL 14+

---

## Overview

A comprehensive strategic plan and SQL implementation for analysing agribusiness data across:
crop yield, livestock, inputs and costs, sales, market prices, weather, and soil.

---

## Repository Structure

```
task-1/
├── docs/
│   ├── Agribusiness_SQL_Strategic_Plan_Week1.docx   ← Full Week 1 report
│   ├── erd.png                                       ← Schema ERD
│   └── gantt.png                                     ← Project roadmap
└── sql/
    ├── 01_schema.sql               ← Star schema: 6 dimensions, 7 facts, staging & error-log tables
    ├── 02_indexes.sql              ← Index strategy (B-tree, covering, BRIN, partial)
    ├── 03_sample_data.sql          ← Small demo dataset
    ├── 04_analytical_queries.sql   ← 14 analytical queries
    └── 05_etl_error_handling.sql   ← PL/pgSQL batch loader with rejected-row logging
```

---

## How to Run

```bash
createdb agri_demo
psql -d agri_demo -f sql/01_schema.sql
psql -d agri_demo -f sql/02_indexes.sql
psql -d agri_demo -f sql/03_sample_data.sql
psql -d agri_demo -f sql/04_analytical_queries.sql
psql -d agri_demo -f sql/05_etl_error_handling.sql
```

---

## Notes

- Farm identifiers are anonymised labels; sample data is synthetic.
- Soil nutrient thresholds are illustrative; confirm with local guidelines.
- Public data sources are listed in the report (FAOSTAT, USDA NASS, Agmarknet, data.gov.in, NASA POWER and others).
