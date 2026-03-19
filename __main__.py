from sqlalchemy import create_engine
import pandas as pd

def sales_to_oltp(conn_params, csv_file_path):
    """
    Function to only load sales.scv to OLTP DataBase
    """
    
    df = pd.read_csv(csv_file_path,
                    delimiter=',',
                    header=0,
                    encoding ='utf-8')

    #Rename columns
    df.columns = [
            'sales_id', 'customer_id', 'product_id', 'dates',
            'quantity', 'price', 'discount'
        ]
    
    df['customer_id'] = df['customer_id'].str.extract(r'(\d+)').astype(int)
    df['product_id'] = df['product_id'].str.extract(r'(\d+)').astype(int)
      
    #Establish connection to OLTP DataBase
    engine = create_engine(
                f"postgresql://{conn_params['user']}:{conn_params['password']}@"
                f"{conn_params['host']}:{conn_params['port']}/{conn_params['database']}"
            )
    #Loading data to OLTP DataBase
    df.to_sql(
            'sales',
            engine,
            if_exists='append',  
            index=False,
            chunksize=1000
        )

def customers_to_oltp(conn_params, csv_file_path):
    """
    Function to only load customers.scv to OLTP DataBase
    """
    
    df = pd.read_csv(csv_file_path,
                    delimiter=',',
                    header=0,
                    encoding ='utf-8')
    
    df.columns = ['customer_id', 'name', 'age', 'gender','region']
    
    # Extract numeric part from product_id (remove letters)
    df['customer_id'] = df['customer_id'].str.extract(r'(\d+)').astype(int)
    
    engine = create_engine(
                f"postgresql://{conn_params['user']}:{conn_params['password']}@"
                f"{conn_params['host']}:{conn_params['port']}/{conn_params['database']}"
            )
    
    df.to_sql(
            'customers',
            engine,
            if_exists='append',  
            index=False,
            chunksize=1000
        )

def products_to_oltp(conn_params, csv_file_path):
    """
    Function to only load products.scv to OLTP DataBase
    """
    
    df = pd.read_csv(csv_file_path,
                    delimiter=',',
                    header=0,
                    encoding ='utf-8')
        
    df.columns = ['product_id', 'product_name', 'category', 'supplier_id','cost_price']
    
    # Extract numeric part from product_id (remove letters)
    df['product_id'] = df['product_id'].str.extract(r'(\d+)').astype(int)
    
    engine = create_engine(
                f"postgresql://{conn_params['user']}:{conn_params['password']}@"
                f"{conn_params['host']}:{conn_params['port']}/{conn_params['database']}"
            )
    
    df.to_sql(
            'products',
            engine,
            if_exists='append',  
            index=False,
            chunksize=1000
        )

if __name__ == "__main__":
     
    csv_file_paths = {
        "sales": "./raw_data/sales.csv",
        "products": "./raw_data/products.csv",
        "customers": "./raw_data/customers.csv"
    }
    
    conn_params = {
        "host": "localhost",
        "database": "oltp",
        "user": "postgres",
        "password": "postgres",
        "port": 5432
    }
    
    sales_to_oltp(conn_params, csv_file_paths["sales"])
    products_to_oltp(conn_params, csv_file_paths["products"])
    customers_to_oltp(conn_params, csv_file_paths["customers"])