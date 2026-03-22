CREATE OR REPLACE PROCEDURE load_products_to_dwh()
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Закрываем старые версии
    UPDATE dwh_dim_products d
    SET valid_to = CURRENT_TIMESTAMP,
        is_current = FALSE
    FROM tmp_dwh_products t
    WHERE d.id = t.product_id
      AND d.is_current = TRUE
      AND (
          d.name <> t.product_name OR
          d.category <> t.category
      );

    -- 2. Вставляем новые версии
    INSERT INTO dwh_dim_products (
        id, name, category, valid_from, is_current
    )
    SELECT
        t.product_id,
        t.product_name,
        t.category,
        CURRENT_TIMESTAMP,
        TRUE
    FROM tmp_dwh_products t
    LEFT JOIN dwh_dim_products d
        ON d.id = t.product_id
        AND d.is_current = TRUE
    WHERE d.id IS NULL
       OR d.name <> t.product_name
       OR d.category <> t.category;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO dwh_etl_logs(process_name, step_name, status, error_message)
    VALUES ('products_load', 'SCD2', 'error', SQLERRM);
END;
$$;