CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(20),
    age INT,
    gender VARCHAR(5),
    region VARCHAR(50)
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(20),
    category VARCHAR(20),
    supplier_id VARCHAR(20),
    cost_price DECIMAL(10,2)
);

CREATE TABLE sales (
    sales_id INT PRIMARY KEY,
    customer_id INT,
    product_id INT,
    dates DATE,
    quantity INT,
    price DECIMAL(10,2),
    discount DECIMAL(10,2),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);