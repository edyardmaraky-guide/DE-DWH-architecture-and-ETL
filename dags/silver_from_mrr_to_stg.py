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
DAG_ID = "silver_from_mrr_to_stg"

DEFAULT_ARGS = {
    "owner": OWNER,
    "retries": 3,
    "retry_delay": pendulum.duration(minutes=5),
}

MRR_CONN_STR = "postgresql://postgres:postgres@dwh_db:5432/mrr"
STG_CONN_STR = "postgresql://postgres:postgres@dwh_db:5432/stg"
DWH_CONN_STR = "postgresql://postgres:postgres@dwh_db:5432/dwh"

def get_engine(conn_str):
    """Создание SQLAlchemy engine"""
    
    try:
        create_engine(conn_str)
        return create_engine(conn_str)
    except Exception as e:
        logging.info(f"Error while establishing connection: {e}")
  
@task
def etl_customers_to_stg():
    """Извлечение и обработка данных покупателей из MRR в STG"""
    
    process_name = "mrr_to_stg"
    step_name = "customers"
    start_time = pendulum.now()
    
    try:
        
        logging.info("Starting customers extraction from MRR to STG")
        
        mrr_engine = create_engine(MRR_CONN_STR)
        stg_engine = create_engine(STG_CONN_STR)
        dwh_engine = get_engine(DWH_CONN_STR)
        
        query = """SELECT * FROM mrr_dim_customers"""
        
        df = pd.read_sql(query, mrr_engine)
        
        #Обработка данных
        #Удаление дубликатов
        df = df.drop_duplicates(subset=['customer_id'])
        
        #Удаление пробелов и проебразование в нижний регистр
        df['name'] = df['name'].str.strip().str.lower()
        
        #Заполнеине NULL значений
        df['region'] = df['region'].fillna('Unknown')
        
        #Обогащение данных возраста
        df['age_group'] = pd.cut(df['age'], bins=[0,18,30,50,100], labels=['child','young','adult','senior'])
        
        with stg_engine.connect() as conn:
            conn.execute(text("TRUNCATE TABLE stg_dim_customers"))
            df.to_sql("stg_dim_customers", conn, if_exists="append", index=False)
        
        logging.info(f"Loaded {len(df)} customers into STG")

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
def etl_products_to_stg():
    """Очистка и обогащение продуктов"""
    
    process_name = "mrr_to_stg"
    step_name = "products"
    start_time = pendulum.now()
    
    try:
        logging.info("Starting products transformation MRR → STG")
        
        mrr_engine = create_engine(MRR_CONN_STR)
        stg_engine = create_engine(STG_CONN_STR)
        dwh_engine = get_engine(DWH_CONN_STR)
        
        query = """SELECT * FROM mrr_dim_products"""
        
        df = pd.read_sql(query, mrr_engine)
        
        #Очистка данных
        #Удаление дубликатов
        df = df.drop_duplicates(subset=['product_id'])
        
        #Удаление пробелов и проебразование в нижний регистр
        df['product_name'] = df['product_name'].str.strip().str.lower()
        df['category'] = df['category'].str.strip().str.lower()
        
        #Заполнеине NULL значений
        df['category'] = df['category'].fillna('unknown')
        df['supplier_id'] = df['supplier_id'].fillna('unknown')
        
        #Обогащение ценовых данных
        df['price_category'] = df['cost_price'].apply(
            lambda x: 'cheap' if x <= 10 else ('medium' if x < 20 else 'expensive')
        )
        
        with stg_engine.connect() as conn:
            conn.execute(text("TRUNCATE TABLE stg_dim_products"))
            df.to_sql("stg_dim_products", conn, if_exists="append", index=False)
        
        logging.info(f"Loaded {len(df)} products into STG")
        
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
def etl_sales_to_stg():
    """Очистка и обогащение продаж"""
    
    process_name = "mrr_to_stg"
    step_name = "sales"
    start_time = pendulum.now()
    
    try:
        logging.info("Starting sales transformation MRR → STG")
        
        mrr_engine = create_engine(MRR_CONN_STR)
        stg_engine = create_engine(STG_CONN_STR)
        dwh_engine = get_engine(DWH_CONN_STR)
        
        query = """SELECT * FROM mrr_fact_sales"""
        
        df = pd.read_sql(query, mrr_engine)
        
        #Очистка
        #Заполнеине NULL значений
        df['quantity'] = df['quantity'].fillna(0)
        df['price'] = df['price'].fillna(0)
        df['discount'] = df['discount'].fillna(0)
        
        #Убираем отрицательные значения
        df = df[(df['quantity'] >= 0) & (df['price'] >= 0)]
        
        #Нормализация дат
        df['dates'] = pd.to_datetime(df['dates'])
        
        # --- ОБОГАЩЕНИЕ ---
        
        # выручка без скидки
        df['gross_revenue'] = df['quantity'] * df['price']
        
        # выручка со скидкой
        df['net_revenue'] = df['quantity'] * df['price'] * (1 - df['discount'])
        
        # флаг скидки
        df['is_discounted'] = df['discount'] > 0
        
        # день недели
        df['day_of_week'] = df['dates'].dt.day_of_week
        
        # месяц
        df['month_number'] = df['dates'].dt.month
        
        # год
        df['year_number'] = df['dates'].dt.year
        
        with stg_engine.connect() as conn:
            conn.execute(text("TRUNCATE TABLE stg_fact_sales"))
            df.to_sql("stg_fact_sales", conn, if_exists="append", index=False)

        logging.info(f"Loaded {len(df)} sales into STG")

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
    tags=["mrr", "clear", "stg"],
    max_active_runs=1,
) as dag:
    
    start = EmptyOperator(task_id="start")
    
    sensor_on_mrr = ExternalTaskSensor(
        task_id = "sensor_on_mrr_layer",
        external_dag_id = "bronze_from_oltp_to_mrr",
        allowed_states=["success"],
        mode="reschedule",
        timeout=360000,
        poke_interval=60
    )
    
    customers = etl_customers_to_stg()
    
    products = etl_products_to_stg()
    
    sales = etl_sales_to_stg()
    
    end = EmptyOperator(task_id="end")
    
    start >> sensor_on_mrr >> [customers, products] >> sales >> end
        
