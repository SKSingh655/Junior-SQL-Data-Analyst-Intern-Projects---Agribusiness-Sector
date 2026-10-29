# Junior SQL Data Analyst Intern Projects — Agribusiness Sector

A collection of internship assessment solutions for the **Junior SQL Data Analyst** role focused on agribusiness data analytics using PostgreSQL.

---

## Repository Structure

```
repo/
├── task-1/          ← Week 1: Strategic Plan & Star Schema
│   ├── docs/        ← Assessment brief, ERD, Gantt chart
│   └── sql/         ← Schema, indexes, sample data, queries, ETL
│
├── task-2/          ← Week 2: Schema Design & Query Optimization
│   ├── docs/        ← Assessment brief
│   └── sql/         ← Schema, indexes, sample data, queries, optimization
│
└── README.md        ← This file
```

---

## Tasks at a Glance

### ✅ Task 1 — Agribusiness SQL Strategic Plan (Week 1)

> **Focus:** Research, requirements, star schema data model, analytical queries, ETL error handling

A comprehensive strategic plan and SQL implementation for analysing agribusiness data across crop yield, livestock, inputs, costs, sales, market prices, weather, and soil.

📁 See [`task-1/`](./task-1/) for details.

| File | Description |
|---|---|
| `sql/01_schema.sql` | PostgreSQL star schema: 6 dimensions, 7 facts, staging and error-log tables |
| `sql/02_indexes.sql` | Index strategy (B-tree, covering, BRIN, partial) |
| `sql/03_sample_data.sql` | Demo dataset |
| `sql/04_analytical_queries.sql` | 14 analytical queries (aggregation, window functions, anomaly detection) |
| `sql/05_etl_error_handling.sql` | PL/pgSQL batch loader with rejected-row logging |
| `docs/erd.png` | Schema ERD |
| `docs/gantt.png` | Project roadmap |

---

### ✅ Task 2 — Database Schema Design & Query Optimization (Week 2)

> **Focus:** Relational schema design, ER relationships, SQL reporting queries, query optimization with EXPLAIN ANALYZE

A normalized relational database design for an agribusiness analytics platform covering farms, crops, livestock, and market prices.

📁 See [`task-2/`](./task-2/) for details.

| File | Description |
|---|---|
| `sql/01_schema.sql` | Full DDL with PKs, FKs, check constraints |
| `sql/02_indexes.sql` | Query-driven index recommendations |
| `sql/03_sample_data.sql` | Illustrative seed data (10 farms, 10 crops, 6 markets) |
| `sql/04_analytical_queries.sql` | 7 reporting queries covering production, yield, market trends, livestock |
| `sql/05_optimization_and_validation.sql` | EXPLAIN ANALYZE workflow, ANALYZE, data quality checks |

---

## Tech Stack

- **Database:** PostgreSQL 15+
- **Language:** SQL / PL/pgSQL
- **Domain:** Agribusiness analytics

---

## Notes

- All sample data is synthetic and for demonstration purposes only.
- SQL syntax is PostgreSQL-specific; date functions and identity columns may differ in MySQL/SQL Server.
- Run schema files before index/data files in each task directory.
