from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator
from utils.callbacks import alert_on_failure

DBT_CONN = "snowflake_default"
STAGE = "@banking_db.bronze.banking_s3_stage"


def get_copy_task(task_id, table, stage_path):
    return SnowflakeOperator(
        task_id=task_id,
        snowflake_conn_id=DBT_CONN,
        on_failure_callback=alert_on_failure,
        sql=f"""
            COPY INTO banking_db.bronze.{table}
            FROM {STAGE}/{stage_path}/data/
            FILE_FORMAT = (TYPE = PARQUET)
            MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
            PURGE = FALSE
            ON_ERROR = CONTINUE
            PATTERN = '.*\\\\.parquet';
        """
    )


copy_transactions = get_copy_task("copy_transactions", "transactions", "raw/transactions")
copy_customers = get_copy_task("copy_customers", "customers", "raw/customers")
copy_accounts = get_copy_task("copy_accounts", "accounts", "raw/accounts")
copy_transaction_legs = get_copy_task("copy_transaction_legs", "transaction_legs", "raw/transaction_legs")
copy_banks = get_copy_task("copy_banks", "banks", "raw/banks")
