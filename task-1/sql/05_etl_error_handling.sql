-- =====================================================================
-- File: 05_etl_error_handling.sql
-- Row-level load with safe casting, upsert and error logging (PL/pgSQL)
-- Usage:  SELECT * FROM agri.load_market_price_batch('2026-W01');
-- =====================================================================
CREATE OR REPLACE FUNCTION agri.load_market_price_batch(p_batch_id TEXT)
RETURNS TABLE (rows_loaded INT, rows_rejected INT)
LANGUAGE plpgsql
AS $$
DECLARE
    r           RECORD;
    v_market_id INT;
    v_crop_id   INT;
    v_loaded    INT := 0;
    v_rejected  INT := 0;
BEGIN
    FOR r IN SELECT * FROM agri.stg_market_price WHERE batch_id = p_batch_id LOOP
        BEGIN   -- inner block = implicit savepoint: one bad row cannot abort the batch
            SELECT m.market_id INTO STRICT v_market_id
            FROM agri.dim_market m
            JOIN agri.dim_region g ON g.region_id = m.region_id
            WHERE LOWER(m.market_name) = LOWER(TRIM(r.market_name))
              AND LOWER(g.state_name)  = LOWER(TRIM(r.state_name))
            LIMIT 1;

            SELECT c.crop_id INTO STRICT v_crop_id
            FROM agri.dim_crop c
            WHERE LOWER(c.crop_name) = LOWER(TRIM(r.commodity));

            INSERT INTO agri.fact_market_price
                   (market_id, crop_id, price_date, min_price, max_price,
                    modal_price, arrivals_tonnes)
            VALUES (v_market_id, v_crop_id,
                    r.price_date::DATE,
                    r.min_price::NUMERIC, r.max_price::NUMERIC, r.modal_price::NUMERIC,
                    NULLIF(r.arrivals_tonnes, '')::NUMERIC)
            ON CONFLICT (market_id, crop_id, price_date) DO UPDATE
               SET min_price       = EXCLUDED.min_price,
                   max_price       = EXCLUDED.max_price,
                   modal_price     = EXCLUDED.modal_price,
                   arrivals_tonnes = EXCLUDED.arrivals_tonnes;

            v_loaded := v_loaded + 1;
        EXCEPTION WHEN OTHERS THEN
            INSERT INTO agri.etl_error_log
                   (batch_id, source_name, target_table, sqlstate_code, error_message, raw_record)
            VALUES (p_batch_id, 'stg_market_price', 'fact_market_price',
                    SQLSTATE, SQLERRM, TO_JSONB(r));
            v_rejected := v_rejected + 1;
        END;
    END LOOP;

    RETURN QUERY SELECT v_loaded, v_rejected;
END;
$$;

-- Review rejected rows after each run
-- SELECT sqlstate_code, error_message, COUNT(*) FROM agri.etl_error_log
-- WHERE batch_id = '2026-W01' GROUP BY 1, 2 ORDER BY 3 DESC;
