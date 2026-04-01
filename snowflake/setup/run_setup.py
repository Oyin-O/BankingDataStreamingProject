import snowflake.connector
import os
from dotenv import load_dotenv

load_dotenv()

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD")
)

cur = conn.cursor()

with open("snowflake/setup/01_initial_setup.sql", "r") as f:
    sql = f.read()

# Replace placeholders with env variables
sql = sql.replace("{{SNOWFLAKE_ROLE_ARN}}", os.getenv("SNOWFLAKE_ROLE_ARN"))
sql = sql.replace("{{SNOWFLAKE_S3_BUCKET}}", os.getenv("SNOWFLAKE_S3_BUCKET"))

# Split by semicolon and run each statement
statements = [s.strip() for s in sql.split(";") if s.strip()]

for statement in statements:
    if statement.startswith("--"):
        continue
    try:
        print(f"Running: {statement[:50]}...")
        cur.execute(statement)
        print("Done")
    except Exception as e:
        print(f"Error: {e}")

cur.close()
conn.close()
print("\nSnowflake setup complete!")