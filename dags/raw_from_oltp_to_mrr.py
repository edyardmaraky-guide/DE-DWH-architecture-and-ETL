import logging
import pendulum
import pandas as pd
from airflow import DAG
from airflow.sdk import task
from sqlalchemy import create_engine, text
from airflow.providers.standard.operators.empty import EmptyOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

OWNER = "e.novikau"
DAG_ID = "raw_from_oltp_to_mrr"

DEFAULT_ARGS = {
    "owner": OWNER,
    "retries": 3,
    "retry_delay": pendulum.duration(minutes=5),
}

OLTP_CONN_STR = "postgresql://postgres:postgres@localhost:5432/oltp"
MRR_CONN_STR = "postgresql://postgres:postgres@localhost:5433/mrr"

def get_engine(conn_str):
    """Создание SQLAlchemy engine"""
    return create_engine(conn_str)

def get_high_water_mark(engine, table_name):
    """Получение последней даты загрузки из MRR"""
    query = text("SELECT last_updated FROM mrr_high_water_mark WHERE table_name = :table_name")
    with engine.connect() as conn:
        result = conn.execute(query, {"table_name": table_name}).first()
        if result and result[0]:
            logging.info(f"High water mark for {table_name}: {result[0]}")
            return result[0]
        else:
            logging.info(f"No high water mark for {table_name}, using default")
            return '1900-01-01'

def update_high_water_mark(engine, table_name, max_date):
    """Обновление high water mark в MRR"""
    query = text("""
        UPDATE mrr_high_water_mark 
        SET last_updated = :max_date
        WHERE table_name = :table_name
    """)
    with engine.connect() as conn:
        conn.execute(query, {"max_date": max_date, "table_name": table_name})
        conn.commit()
    logging.info(f"Updated high water mark for {table_name} to {max_date}")

@task
def extract_customers():
    """Извлечение клиентов из OLTP в MRR"""
    logging.info("Starting customers extraction from OLTP to MRR")
    
    # Создаем подключения
    oltp_engine = get_engine(OLTP_CONN_STR)
    mrr_engine = get_engine(MRR_CONN_STR)
    
    # Получаем последнюю дату загрузки
    last_updated = get_high_water_mark(mrr_engine, "customers")
    logging.info(f"Last updated: {last_updated}")
    
    # Извлекаем данные из OLTP
    query = f"""
        SELECT id, name, country, updated_at
        FROM customers 
        WHERE updated_at > '{last_updated}'
        ORDER BY updated_at
    """
    
    df = pd.read_sql(query, oltp_engine)
    rows_processed = len(df)
    
    logging.info(f"Extracted {rows_processed} customers from OLTP")
    
    if rows_processed > 0:
        # Загружаем в MRR
        with mrr_engine.connect() as conn:
            # Используем временную таблицу для UPSERT
            df.to_sql('temp_customers', conn, if_exists='replace', index=False)
            
            # UPSERT операция
            upsert_query = """
                INSERT INTO mrr_dim_customers (id, name, country, updated_at)
                SELECT id, name, country, updated_at
                FROM temp_customers
                ON CONFLICT (id) 
                DO UPDATE SET 
                    name = EXCLUDED.name,
                    country = EXCLUDED.country,
                    updated_at = EXCLUDED.updated_at
            """
            conn.execute(text(upsert_query))
            conn.commit()
        
        # Находим максимальную дату для обновления HWM
        max_date = df['updated_at'].max()
        update_high_water_mark(mrr_engine, "customers", max_date)
        
        logging.info(f"Successfully loaded {rows_processed} customers to MRR")
    else:
        logging.info("No new customers to load")
    
    return rows_processed

with DAG(
    dag_id=DAG_ID,
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="*/5 * * * *",
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["oltp", "mrr"],
    max_active_runs=1,
) as dag:
    
    start = EmptyOperator(task_id="start")
    
    customers = extract_customers()
    
    end = EmptyOperator(task_id="end")
    
    start >> customers >> end