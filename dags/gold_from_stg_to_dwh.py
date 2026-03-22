import logging
import pendulum
import pandas as pd
from airflow import DAG
from airflow.sdk import task
from etl_logs import log_to_db
from sqlalchemy import create_engine, text
from airflow.providers.standard.operators.empty import EmptyOperator
from airflow.providers.standard.sensors.external_task import ExternalTaskSensor

OWNER = "e.novikau"
DAG_ID = "gold_from_stg_to_dwh"

STG_CONN_STR = "postgresql://postgres:postgres@dwh_db:5432/stg"
DWH_CONN_STR = "postgresql://postgres:postgres@dwh_db:5432/dwh"

DEFAULT_ARGS = {
    "owner": OWNER,
    "retries": 3,
    "retry_delay": pendulum.duration(minutes=5),
}

def get_engine(conn_str):
    """Создание SQLAlchemy engine"""
    
    try:
        create_engine(conn_str)
        return create_engine(conn_str)
    except Exception as e:
        logging.info(f"Error while establishing connection: {e}")
        
@task
def elt_load_customers():
    """Загрузка покупателей в dwh"""
    
    process_name = "stg_to_gwh"
    step_name = "customers"
    start_time = pendulum.now()
    
    try:
        stg_engine = get_engine(STG_CONN_STR)
        dwh_engine = get_engine(DWH_CONN_STR)
        
        df = pd.read_sql("SELECT * FROM stg_dim_customers", stg_engine)
        
        with dwh_engine.connect() as conn:

            conn.execute(text("DROP TABLE IF EXISTS tmp_dwh_customers"))

            df.to_sql("tmp_dwh_customers", conn, index=False)

            conn.execute(text("CALL load_customers_to_dwh()"))

            conn.execute(text("DROP TABLE tmp_dwh_customers"))

        end_time = pendulum.now()
            
        log_to_db(
            dwh_engine,
            process_name,
            step_name,
            "success",
            start_time,
            end_time,
            records_processed=len(df)
        )
        
    except Exception as e:
        
        logging.info(f"Error during process: {e}")
    
        end_time = pendulum.now()
        
        log_to_db(
            dwh_engine,
            process_name,
            step_name,
            "failed",
            start_time,
            end_time,
            records_processed=len(df)
        )

@task
def elt_load_products():
    """Загрузка продуктов в dwh"""

    process_name = "stg_to_gwh"
    step_name = "products"
    start_time = pendulum.now()
    
    try:
        
        stg_engine = get_engine(STG_CONN_STR)
        dwh_engine = get_engine(DWH_CONN_STR)

        df = pd.read_sql("SELECT * FROM stg_dim_products", stg_engine)

        with dwh_engine.connect() as conn:

            conn.execute(text("DROP TABLE IF EXISTS tmp_dwh_products"))

            df.to_sql("tmp_dwh_products", conn, index=False)

            conn.execute(text("CALL load_products_to_dwh()"))

            conn.execute(text("DROP TABLE tmp_dwh_products"))

        end_time = pendulum.now()
            
        log_to_db(
            dwh_engine,
            process_name,
            step_name,
            "success",
            start_time,
            end_time,
            records_processed=len(df)
        )
        
    except Exception as e:
        
        logging.info(f"Error during process: {e}")
    
        end_time = pendulum.now()
        
        log_to_db(
            dwh_engine,
            process_name,
            step_name,
            "failed",
            start_time,
            end_time,
            records_processed=len(df)
        )

@task
def etl_load_sales():
    """Загрузка продаж в dwh"""

    process_name = "stg_to_gwh"
    step_name = "sales"
    start_time = pendulum.now()
    
    try:
        stg_engine = get_engine(STG_CONN_STR)
        dwh_engine = get_engine(DWH_CONN_STR)

        df = pd.read_sql("SELECT * FROM stg_fact_sales", stg_engine)

        with dwh_engine.connect() as conn:

            conn.execute(text("DROP TABLE IF EXISTS tmp_dwh_sales"))

            df.to_sql("tmp_dwh_sales", conn, index=False)

            conn.execute(text("CALL load_sales_to_dwh()"))

            conn.execute(text("DROP TABLE tmp_dwh_sales"))

        end_time = pendulum.now()
            
        log_to_db(
            dwh_engine,
            process_name,
            step_name,
            "success",
            start_time,
            end_time,
            records_processed=len(df)
        )
        
    except Exception as e:
        
        logging.info(f"Error during process: {e}")
    
        end_time = pendulum.now()
        
        log_to_db(
            dwh_engine,
            process_name,
            step_name,
            "failed",
            start_time,
            end_time,
            records_processed=len(df)
        )
    
        
with DAG(
    dag_id=DAG_ID,
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="*/5 * * * *",
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["stg", "dwh"],
) as dag:

    start = EmptyOperator(task_id="start")

    sensor_on_stg = ExternalTaskSensor(
        task_id = "sensor_on_stg_layer",
        external_dag_id = "silver_from_mrr_to_stg",
        allowed_states=["success"],
        mode="reschedule",
        timeout=360000,
        poke_interval=60
    )

    customers = elt_load_customers()
    products = elt_load_products()
    sales = etl_load_sales()

    end = EmptyOperator(task_id="end")

    start >> [customers, products] >> sales >> end