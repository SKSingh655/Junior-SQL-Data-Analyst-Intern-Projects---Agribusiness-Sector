# Agribusiness Data Analysis with SQL: Strategic Plan (Week 1)

Strategic plan, data model and SQL starter code for analysing agribusiness data
(crop yield, livestock, inputs and costs, sales, market prices, weather and soil).

## Contents
| Path | Description |
|------|-------------|
| `docs/Agribusiness_SQL_Strategic_Plan_Week1.docx` | Full Week 1 report: research, requirements, data model, SQL query types, roadmap, optimization and error handling |
| `sql/01_schema.sql` | PostgreSQL star schema: 6 dimensions, 7 facts, staging and error-log tables |
| `sql/02_indexes.sql` | Index strategy (B-tree, covering, BRIN, partial) |
| `sql/03_sample_data.sql` | Small demo dataset |
| `sql/04_analytical_queries.sql` | 14 analytical queries (aggregation, window functions, correlation, anomaly detection, data-quality audits, materialized view) |
| `sql/05_etl_error_handling.sql` | PL/pgSQL batch loader that logs rejected rows |
| `docs/erd.png`, `docs/gantt.png` | Schema overview and roadmap figures |

## Run it (PostgreSQL 14+)
```bash
createdb agri_demo
psql -d agri_demo -f sql/01_schema.sql
psql -d agri_demo -f sql/02_indexes.sql
psql -d agri_demo -f sql/03_sample_data.sql
psql -d agri_demo -f sql/04_analytical_queries.sql
psql -d agri_demo -f sql/05_etl_error_handling.sql
```

## Notes
- Farm identifiers are anonymised labels; sample data is synthetic.
- Soil nutrient thresholds are illustrative; confirm with local guidelines.
- Public data sources are listed in the report (FAOSTAT, USDA NASS, Agmarknet, data.gov.in, NASA POWER and others).
