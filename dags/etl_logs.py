from sqlalchemy import create_engine, text
import pendulum

def log_to_db(engine, process_name, step_name, status, start_time, end_time=None, error_message=None, records_processed=0):
    duration = None
    if end_time:
        duration = int((end_time - start_time).total_seconds())

    query = text("""
        INSERT INTO dwh_etl_logs (
            process_name,
            step_name,
            status,
            start_time,
            end_time,
            duration_seconds,
            error_message,
            records_processed
        )
        VALUES (
            :process_name,
            :step_name,
            :status,
            :start_time,
            :end_time,
            :duration,
            :error_message,
            :records_processed
        )
    """)

    with engine.connect() as conn:
        conn.execute(query, {
            "process_name": process_name,
            "step_name": step_name,
            "status": status,
            "start_time": start_time,
            "end_time": end_time,
            "duration": duration,
            "error_message": error_message,
            "records_processed": records_processed
        })