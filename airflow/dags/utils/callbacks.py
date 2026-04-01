from airflow.utils.email import send_email
from airflow.models import Variable


def alert_on_failure(context):
    print("🚨 ALERT CALLBACK TRIGGERED")
    dag_id = context['dag'].dag_id
    task_id = context['task'].task_id
    execution_date = context['execution_date']
    log_url = context['task_instance'].log_url

    subject = f"Airflow Alert: {dag_id}.{task_id} Failed"
    body = f"""
    <h3>Pipeline Failure Alert</h3>
    <p><b>DAG:</b> {dag_id}</p>
    <p><b>Task:</b> {task_id}</p>
    <p><b>Execution Date:</b> {execution_date}</p>
    <p><b>Log URL:</b> <a href="{log_url}">View Logs</a></p>
    """
    send_email(
        to=[Variable.get("ALERT_EMAIL")],
        subject=subject,
        html_content=body
    )
    print("EMAIL SENT")


def alert_on_success(context):
    print("SUCCESS CALLBACK TRIGGERED")
    dag_id = context['dag'].dag_id
    execution_date = context['execution_date']

    alert_email = Variable.get("ALERT_EMAIL")

    subject = f"Airflow Success: {dag_id} Completed"
    body = f"""
    <h3>Pipeline Success</h3>
    <p><b>DAG:</b> {dag_id}</p>
    <p><b>Execution Date:</b> {execution_date}</p>
    <p>All tasks completed successfully.</p>
    """
    send_email(
        to=[Variable.get("ALERT_EMAIL")],
        subject=subject,
        html_content=body
    )
    print("SUCCESS EMAIL SENT")
