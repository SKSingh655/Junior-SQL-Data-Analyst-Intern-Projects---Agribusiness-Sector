"""
Task 3 | Week 3 Internship Assessment
ETL Extraction Adapter — Pseudocode / Reference Implementation
Agribusiness ETL Process Plan

Proposed stack: Python 3.10+, requests, pandas, psycopg2 / SQLAlchemy
NOTE: This is a conceptual reference, not a production-ready script.
      Verify each source's current access method, license and schema
      before implementing. Adapt endpoints, column names and auth
      to the actual provider's API or download format.
"""

from __future__ import annotations

import hashlib
import json
import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd
import requests

# ---------------------------------------------------------------------------
# Configuration (replace with env vars or a config file in production)
# ---------------------------------------------------------------------------
DB_DSN = "postgresql://user:password@localhost:5432/agri_etl"
RAW_LANDING_DIR = Path("raw_landing")       # immutable archive of source files
BATCH_TIMEOUT_SECONDS = 30
LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s — %(message)s"

logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger("agri_etl")

# ---------------------------------------------------------------------------
# Data sources registry
# ---------------------------------------------------------------------------
SOURCES = {
    "agmarknet": {
        "type": "bulk_download",
        "url": "https://agmarknet.gov.in/SearchCmmMkt.aspx",  # illustrative
        "stage_table": "stg_market_price",
        "schema_version": "v1.0",
    },
    "faostat": {
        "type": "bulk_download",
        "url": "https://www.fao.org/faostat/en/#data/QCL",    # illustrative
        "stage_table": "stg_crop_production",
        "schema_version": "v2.1",
    },
    "imd_weather": {
        "type": "bulk_download",
        "url": "https://mausam.imd.gov.in/",                  # illustrative
        "stage_table": "stg_weather",
        "schema_version": "v1.0",
    },
}

# ---------------------------------------------------------------------------
# Watermark helpers (simplified; persist in DB in production)
# ---------------------------------------------------------------------------
_watermarks: dict[str, str] = {}

def last_successful_watermark(source_name: str) -> str:
    """Return the last successful run cutoff date for a source."""
    return _watermarks.get(source_name, "2020-01-01")

def advance_watermark(source_name: str, cutoff: str) -> None:
    """Advance watermark ONLY after a successful batch commit."""
    _watermarks[source_name] = cutoff
    logger.info("Watermark advanced for %s → %s", source_name, cutoff)

# ---------------------------------------------------------------------------
# Batch metadata helpers
# ---------------------------------------------------------------------------
def create_batch(source_name: str, source_uri: str, schema_version: str) -> str:
    batch_id = str(uuid.uuid4())
    # In production: INSERT INTO etl_batch (batch_id, source_name, ...) VALUES (...)
    logger.info("Batch created: %s for source=%s", batch_id, source_name)
    return batch_id

def update_batch_status(batch_id: str, status: str, **counts: int) -> None:
    # In production: UPDATE etl_batch SET status=... WHERE batch_id=...
    logger.info("Batch %s → status=%s counts=%s", batch_id, status, counts)

# ---------------------------------------------------------------------------
# Raw-file archive
# ---------------------------------------------------------------------------
def save_immutable_raw_payload(content: bytes, batch_id: str, source_name: str) -> Path:
    """
    Write raw bytes to the landing area. Returns the file path.
    The file must never be modified after writing.
    """
    RAW_LANDING_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now(tz=timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    file_path = RAW_LANDING_DIR / f"{source_name}_{batch_id}_{ts}.raw"
    file_path.write_bytes(content)
    logger.info("Raw payload archived: %s (%d bytes)", file_path, len(content))
    return file_path

def sha256_of(file_path: Path) -> str:
    return hashlib.sha256(file_path.read_bytes()).hexdigest()

# ---------------------------------------------------------------------------
# Extraction adapters (one per source type)
# ---------------------------------------------------------------------------
def extract_bulk_download(
    source_name: str,
    url: str,
    start_date: str,
    end_date: str,
    batch_id: str,
) -> tuple[pd.DataFrame, str]:
    """
    Download a CSV/XLSX file from a public portal.
    Returns (dataframe, file_hash).
    """
    logger.info("Downloading %s from %s ...", source_name, url)
    # In production: pass auth headers, query params and date ranges as needed.
    response = requests.get(
        url,
        params={"start": start_date, "end": end_date},
        timeout=BATCH_TIMEOUT_SECONDS,
    )
    response.raise_for_status()                    # raises on 4xx/5xx

    raw_path = save_immutable_raw_payload(response.content, batch_id, source_name)
    file_hash = sha256_of(raw_path)

    # Parse — adapt sep/encoding/sheet to actual file
    try:
        df = pd.read_csv(raw_path, dtype=str, keep_default_na=False)
    except Exception as exc:
        raise ValueError(f"Failed to parse {raw_path}: {exc}") from exc

    logger.info("Extracted %d rows from %s", len(df), source_name)
    return df, file_hash


def extract_api_json(
    source_name: str,
    url: str,
    params: dict[str, Any],
    batch_id: str,
) -> tuple[list[dict], str]:
    """
    Call a JSON API endpoint with explicit filters.
    Supports pagination (illustrative; adapt to real API).
    """
    all_records: list[dict] = []
    page = 1
    while True:
        response = requests.get(
            url,
            params={**params, "page": page},
            timeout=BATCH_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        data = response.json()

        records = data.get("results") or data.get("data") or []
        all_records.extend(records)

        if not data.get("next"):          # end of pagination
            break
        page += 1

    raw_bytes = json.dumps(all_records, ensure_ascii=False).encode()
    raw_path  = save_immutable_raw_payload(raw_bytes, batch_id, source_name)
    file_hash = sha256_of(raw_path)

    logger.info("Extracted %d records from %s API", len(all_records), source_name)
    return all_records, file_hash

# ---------------------------------------------------------------------------
# Staging loader: write raw rows to PostgreSQL staging table
# ---------------------------------------------------------------------------
def load_to_staging(
    df: pd.DataFrame,
    stage_table: str,
    batch_id: str,
    column_map: dict[str, str],
) -> int:
    """
    Map source columns to staging columns and insert with batch_id.
    Returns number of rows inserted.
    In production: use psycopg2 COPY or SQLAlchemy bulk insert.
    """
    df = df.rename(columns=column_map).copy()
    df["batch_id"] = batch_id
    df["source_row_number"] = range(1, len(df) + 1)

    # Pseudocode placeholder — replace with actual DB insert:
    # engine = create_engine(DB_DSN)
    # df[list(column_map.values()) + ["batch_id", "source_row_number"]].to_sql(
    #     stage_table, engine, if_exists="append", index=False
    # )
    logger.info("Staged %d rows into %s for batch %s", len(df), stage_table, batch_id)
    return len(df)

# ---------------------------------------------------------------------------
# Main orchestration loop
# ---------------------------------------------------------------------------
def run_etl_pipeline(run_cutoff: str | None = None) -> None:
    if run_cutoff is None:
        run_cutoff = datetime.now(tz=timezone.utc).strftime("%Y-%m-%d")

    for source_name, cfg in SOURCES.items():
        logger.info("=== Starting extraction: %s ===", source_name)
        batch_id = create_batch(source_name, cfg["url"], cfg["schema_version"])

        try:
            start_date = last_successful_watermark(source_name)

            if cfg["type"] == "bulk_download":
                df, file_hash = extract_bulk_download(
                    source_name, cfg["url"], start_date, run_cutoff, batch_id
                )
                extracted_rows = load_to_staging(
                    df,
                    stage_table=cfg["stage_table"],
                    batch_id=batch_id,
                    column_map={},            # TODO: define per-source column map
                )
            else:
                raise NotImplementedError(f"Source type {cfg['type']} not yet implemented")

            update_batch_status(batch_id, "extracted", extracted_rows=extracted_rows)

            # --- Transformation, validation and loading happen in SQL (04, 05) ---
            # After SQL steps succeed:
            advance_watermark(source_name, run_cutoff)
            update_batch_status(batch_id, "loaded", loaded_rows=extracted_rows)

        except Exception as exc:
            update_batch_status(batch_id, "failed")
            logger.error("Batch %s failed for %s: %s", batch_id, source_name, exc)
            # Do NOT advance the watermark on failure.

if __name__ == "__main__":
    run_etl_pipeline()
