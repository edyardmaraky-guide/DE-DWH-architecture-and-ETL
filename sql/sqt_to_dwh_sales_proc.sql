CREATE OR REPLACE PROCEDURE load_sales_to_dwh()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO dwh_fact_sales (
        sales_id,
        customer_id,
        product_id,
        dates,
        quantity,
        price,
        discount,
        gross_revenue,
        net_revenue,
        is_discounted,
        day_of_week,
        month_number,
        year_number,
        updated_at
    )
    SELECT
        sales_id,
        customer_id,
        product_id,
        dates,
        quantity,
        price,
        discount,
        gross_revenue,
        net_revenue,
        is_discounted,
        day_of_week,
        month_number,
        year_number,
        updated_at
    FROM tmp_dwh_sales
    ON CONFLICT (sales_id)
    DO UPDATE SET
        quantity = EXCLUDED.quantity,
        price = EXCLUDED.price,
        discount = EXCLUDED.discount,
        gross_revenue = EXCLUDED.gross_revenue,
        net_revenue = EXCLUDED.net_revenue,
        is_discounted = EXCLUDED.is_discounted,
        updated_at = EXCLUDED.updated_at;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO dwh_etl_logs(process_name, step_name, status, error_message)
    VALUES ('sales_load', 'FACT', 'error', SQLERRM);
END;
$$;