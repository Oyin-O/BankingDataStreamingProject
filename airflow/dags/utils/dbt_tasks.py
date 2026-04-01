from airflow.operators.bash import BashOperator
from utils.callbacks import alert_on_failure

DBT_DIR = "/opt/airflow/dbt/banking_dbt"
DBT_BIN = "/home/airflow/.local/bin/dbt"
PROFILES_DIR = "/opt/airflow/dbt/banking_dbt"


def dbt_command(command, select=None):
    cmd = f"cd {DBT_DIR} && {DBT_BIN} {command} --profiles-dir {PROFILES_DIR}"
    if select:
        cmd += f" --select '{select}'"
    return cmd


dbt_silver = BashOperator(
    task_id="dbt_silver",
    bash_command=dbt_command("run", "silver.*"),
    on_failure_callback=alert_on_failure
)

dbt_snapshot = BashOperator(
    task_id="dbt_snapshot",
    bash_command=dbt_command("snapshot"),
    on_failure_callback=alert_on_failure
)

dbt_gold = BashOperator(
    task_id="dbt_gold",
    bash_command=dbt_command("run", "gold.*"),
    on_failure_callback=alert_on_failure
)

dbt_test = BashOperator(
    task_id="dbt_test",
    bash_command=dbt_command("test", "silver.*"),
    on_failure_callback=alert_on_failure
)
