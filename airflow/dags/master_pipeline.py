from airflow import DAG
from datetime import datetime, timedelta
from airflow.operators.bash import BashOperator

from utils.callbacks import alert_on_failure,alert_on_success
from utils.bronze_tasks import (
    copy_transactions,
    copy_customers,
    copy_accounts,
    copy_transaction_legs,
    copy_banks
)
from utils.dbt_tasks import (
    dbt_silver,
    dbt_snapshot,
    dbt_gold,
    dbt_test
)


with DAG(
    dag_id="banking_pipeline",
    start_date=datetime(2026, 1, 1),
    schedule="*/30 * * * *",
    catchup=False,
    on_success_callback=alert_on_success
) as dag:

    # Assign tasks to DAG
    dag.add_task(copy_transactions)
    dag.add_task(copy_customers)
    dag.add_task(copy_accounts)
    dag.add_task(copy_transaction_legs)
    dag.add_task(copy_banks)
    dag.add_task(dbt_silver)
    dag.add_task(dbt_snapshot)
    dag.add_task(dbt_gold)
    dag.add_task(dbt_test)


    [copy_transactions, copy_customers, copy_accounts,
     copy_transaction_legs, copy_banks] >> dbt_silver

    dbt_silver >> dbt_snapshot >> dbt_gold >> dbt_test