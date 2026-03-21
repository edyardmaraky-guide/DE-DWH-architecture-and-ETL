-- Создаем все базы данных
CREATE DATABASE mrr;
CREATE DATABASE stg;
CREATE DATABASE dwh;

-- Подключаемся к mrr и создаем таблицы
\connect mrr;

-- MRR таблицы
CREATE TABLE mrr_dim_customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(20),
    age INT,
    gender VARCHAR(5),
    region VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE mrr_dim_products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(20),
    category VARCHAR(20),
    supplier_id VARCHAR(20),
    cost_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE mrr_fact_sales (
    sales_id INT PRIMARY KEY,
    customer_id INT,
    product_id INT,
    dates DATE,
    quantity INT,
    price DECIMAL(10,2),
    discount DECIMAL(10,2),
    updated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES mrr_dim_customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES mrr_dim_products(product_id)
);


-- Подключаемся к stg и создаем таблицы
\connect stg;

CREATE TABLE stg_dim_customers (
    customer_id INT PRIMARY KEY,
    name TEXT,
    age INT,
    age_group VARCHAR(10),
    gender VARCHAR(5),
    region VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stg_dim_products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(20),
    category VARCHAR(20),
    supplier_id VARCHAR(20),
    cost_price DECIMAL(10,2),
    price_category VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stg_fact_sales (
    sales_id INT PRIMARY KEY,
    customer_id INT,
    product_id INT,
    dates DATE,
    quantity INT,
    price DECIMAL(10,2),
    discount DECIMAL(10,2),
    gross_revenue DECIMAL(10,2),
    net_revenue DECIMAL(10,2),
    is_discounted BOOLEAN,
    day_of_week INT2,
    month_number INT2,
    year_number INT2,
    updated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Подключаемся к dwh и создаем таблицы
\connect dwh;

-- Таблица для логов ETL процессов
CREATE TABLE dwh_etl_logs (
    id SERIAL PRIMARY KEY,
    process_name VARCHAR(100),
    step_name VARCHAR(100),
    status VARCHAR(20),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    duration_seconds INT,
    error_message TEXT,
    records_processed INT
);

-- Таблица high water mark для dwh
CREATE TABLE dwh_high_water_mark (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) UNIQUE NOT NULL,
    last_updated TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DWH таблицы (звездная схема)
CREATE TABLE dwh_dim_customers (
    id INT PRIMARY KEY,
    name TEXT,
    country TEXT,
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE
);

CREATE TABLE dwh_dim_products (
    id INT PRIMARY KEY,
    name TEXT,
    category TEXT,
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE
);

CREATE TABLE dwh_fact_sales (
    id INT,
    customer_id INT,
    product_id INT,
    qty INT,
    sale_date DATE,
    revenue DECIMAL(10,2),
    updated_at TIMESTAMP
);

-- Инициализация HWM в dwh
INSERT INTO dwh_high_water_mark (table_name, last_updated) 
VALUES 
    ('customers', '1900-01-01'),
    ('products', '1900-01-01'),
    ('sales', '1900-01-01')
ON CONFLICT (table_name) DO NOTHING;

