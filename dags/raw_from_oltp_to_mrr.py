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

OLTP_CONN_STR = "postgresql://postgres:postgres@oltp_db:5432/oltp"
MRR_CONN_STR = "postgresql://postgres:postgres@dwh_db:5432/mrr"

def get_engine(conn_str):
    """Создание SQLAlchemy engine"""
    
    try:
        create_engine(conn_str)
        return create_engine(conn_str)
    except Exception as e:
        logging.info(f"Error while establishing connection: {e}")

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
        SELECT customer_id, name, age, gender, region, updated_at
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
                INSERT INTO mrr_dim_customers (customer_id, name, age, gender, region, updated_at)
                SELECT customer_id, name, age, gender, region, updated_at
                FROM temp_customers
                ON CONFLICT (customer_id) 
                DO UPDATE SET 
                    name = EXCLUDED.name,
                    age = EXCLUDED.age,
                    gender = EXCLUDED.gender,
                    region = EXCLUDED.region,
                    updated_at = EXCLUDED.updated_at
            """
            conn.execute(text(upsert_query))
            
        # Находим максимальную дату для обновления HWM
        max_date = df['updated_at'].max()
        update_high_water_mark(mrr_engine, "customers", max_date)
        
        logging.info(f"Successfully loaded {rows_processed} customers to MRR")
    else:
        logging.info("No new customers to load")
    
    return rows_processed

@task
def extract_products():
    """Извлечение продуктов из OLTP в MRR"""
    logging.info("Starting products extraction from OLTP to MRR")
    
    # Создаем подключения
    oltp_engine = get_engine(OLTP_CONN_STR)
    mrr_engine = get_engine(MRR_CONN_STR)
    
    # Получаем последнюю дату загрузки
    last_updated = get_high_water_mark(mrr_engine, "products")
    logging.info(f"Last updated: {last_updated}")
    
    # Извлекаем данные из OLTP
    query = f"""
        SELECT product_id, product_name, category, supplier_id, cost_price, updated_at
        FROM products 
        WHERE updated_at > '{last_updated}'
        ORDER BY updated_at
    """
    
    df = pd.read_sql(query, oltp_engine)
    rows_processed = len(df)
    
    logging.info(f"Extracted {rows_processed} products from OLTP")
    
    if rows_processed > 0:
        # Загружаем в MRR
        with mrr_engine.connect() as conn:
            # Используем временную таблицу для UPSERT
            df.to_sql('temp_products', conn, if_exists='replace', index=False)
            
            # UPSERT операция
            upsert_query = """
                INSERT INTO mrr_dim_products (product_id, product_name, category, supplier_id, cost_price, updated_at)
                SELECT product_id, product_name, category, supplier_id, cost_price, updated_at
                FROM temp_products
                ON CONFLICT (product_id) 
                DO UPDATE SET 
                    product_name = EXCLUDED.product_name,
                    category = EXCLUDED.category,
                    supplier_id = EXCLUDED.supplier_id,
                    cost_price = EXCLUDED.cost_price,
                    updated_at = EXCLUDED.updated_at
            """
            conn.execute(text(upsert_query))
            
        # Находим максимальную дату для обновления HWM
        max_date = df['updated_at'].max()
        update_high_water_mark(mrr_engine, "products", max_date)
        
        logging.info(f"Successfully loaded {rows_processed} products to MRR")
    else:
        logging.info("No new products to load")
    
    return rows_processed

@task
def extract_sales():
    """Извлечение продаж из OLTP в MRR"""
    logging.info("Starting sales extraction from OLTP to MRR")
    
    # Создаем подключения
    oltp_engine = get_engine(OLTP_CONN_STR)
    mrr_engine = get_engine(MRR_CONN_STR)
    
    # Получаем последнюю дату загрузки
    last_updated = get_high_water_mark(mrr_engine, "sales")
    logging.info(f"Last updated: {last_updated}")
    
    # Извлекаем данные из OLTP
    query = f"""
        SELECT sales_id, customer_id, product_id, dates, quantity, price, discount, updated_at
        FROM sales 
        WHERE updated_at > '{last_updated}'
        ORDER BY updated_at
    """
    
    df = pd.read_sql(query, oltp_engine)
    rows_processed = len(df)
    
    logging.info(f"Extracted {rows_processed} sales from OLTP")
    
    if rows_processed > 0:
        # Загружаем в MRR
        with mrr_engine.connect() as conn:
            # Используем временную таблицу для UPSERT
            df.to_sql('temp_sales', conn, if_exists='replace', index=False)
            
            # UPSERT операция
            upsert_query = """
                INSERT INTO mrr_fact_sales (sales_id, customer_id, product_id, dates, quantity, price, discount, updated_at)
                SELECT sales_id, customer_id, product_id, dates, quantity, price, discount, updated_at
                FROM temp_sales
                ON CONFLICT (sales_id) 
                DO UPDATE SET 
                    customer_id = EXCLUDED.customer_id,
                    product_id = EXCLUDED.product_id,
                    dates = EXCLUDED.dates,
                    quantity = EXCLUDED.quantity,
                    price = EXCLUDED.price,
                    discount = EXCLUDED.discount,
                    updated_at = EXCLUDED.updated_at
            """
            conn.execute(text(upsert_query))
            
        # Находим максимальную дату для обновления HWM
        max_date = df['updated_at'].max()
        update_high_water_mark(mrr_engine, "sales", max_date)
        
        logging.info(f"Successfully loaded {rows_processed} sales to MRR")
    else:
        logging.info("No new sales to load")
    
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
    
    products = extract_products()

    sales = extract_sales()
    
    
    end = EmptyOperator(task_id="end")
    
    start >> [customers, products] >> sales >>  end