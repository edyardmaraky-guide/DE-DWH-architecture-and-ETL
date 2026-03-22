CREATE OR REPLACE PROCEDURE load_customers_to_dwh()
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Закрываем старые версии
    UPDATE dwh_dim_customers d
    SET valid_to = CURRENT_TIMESTAMP,
        is_current = FALSE
    FROM tmp_dwh_customers t
    WHERE d.id = t.customer_id
      AND d.is_current = TRUE
      AND (
          d.name <> t.name OR
          d.country <> t.region
      );

    -- 2. Вставляем новые версии
    INSERT INTO dwh_dim_customers (
        id, name, country, valid_from, is_current
    )
    SELECT
        t.customer_id,
        t.name,
        t.region,
        CURRENT_TIMESTAMP,
        TRUE
    FROM tmp_dwh_customers t
    LEFT JOIN dwh_dim_customers d
        ON d.id = t.customer_id
        AND d.is_current = TRUE
    WHERE d.id IS NULL
       OR d.name <> t.name
       OR d.country <> t.region;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO dwh_etl_logs(process_name, step_name, status, error_message)
    VALUES ('customers_load', 'SCD2', 'error', SQLERRM);
END;
$$;