from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, from_json, current_timestamp, to_date
)
from pyspark.sql.types import (
    StructType, StructField, StringType,
    IntegerType, DoubleType, LongType
)
import os

# SPARK SESSION
spark = SparkSession.builder \
    .appName("KafkaToIceberg") \
    .config("spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.iceberg.type", "hadoop") \
    .config("spark.sql.catalog.iceberg.warehouse", "s3a://oyin-banking-iceberg-warehouse/warehouse") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.hadoop.fs.s3a.aws.credentials.provider",
            "com.amazonaws.auth.EnvironmentVariableCredentialsProvider") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
print("Spark session started")


# SCHEMAS
schemas = {
    "transactions": StructType([
        StructField("transaction_id",  IntegerType()),
        StructField("account_id",      IntegerType()),
        StructField("type",            StringType()),
        StructField("amount",          DoubleType()),
        StructField("currency",        StringType()),
        StructField("exchange_rate",   DoubleType()),
        StructField("amount_in_usd",   DoubleType()),
        StructField("status",          StringType()),
        StructField("channel",         StringType()),
        StructField("country",         StringType()),
        StructField("city",            StringType()),
        StructField("description",     StringType()),
        StructField("created_at",      LongType()),
        StructField("updated_at",      LongType()),
        StructField("__op",            StringType()),
        StructField("__table",         StringType()),
        StructField("__source_ts_ms",  LongType())
            ]),
    "customers": StructType([
        StructField("customer_id",   IntegerType()),
        StructField("full_name",     StringType()),
        StructField("email",         StringType()),
        StructField("phone",         StringType()),
        StructField("nationality",   StringType()),
        StructField("created_at",    LongType()),
        StructField("updated_at",    LongType()),
        StructField("__op",          StringType()),
        StructField("__table",       StringType()),
        StructField("__source_ts_ms",LongType()),
    ]),
    "accounts": StructType([
        StructField("account_id",    IntegerType()),
        StructField("customer_id",   IntegerType()),
        StructField("bank_id",       IntegerType()),
        StructField("account_type",  StringType()),
        StructField("balance",       DoubleType()),
        StructField("currency",      StringType()),
        StructField("account_status", StringType()),
        StructField("opened_at",     LongType()),
        StructField("updated_at",    LongType()),
        StructField("__op",          StringType()),
        StructField("__table",       StringType()),
        StructField("__source_ts_ms",LongType()),
    ]),
    "transaction_legs": StructType([
        StructField("leg_id",                     IntegerType()),
        StructField("transaction_id",             IntegerType()),
        StructField("direction",                  StringType()),
        StructField("account_id",                 IntegerType()),
        StructField("bank_id",                    IntegerType()),
        StructField("external_account_reference", StringType()),
        StructField("external_account_name",      StringType()),
        StructField("amount",                     DoubleType()),
        StructField("currency",                   StringType()),
        StructField("__op",                       StringType()),
        StructField("__table",                    StringType()),
        StructField("__source_ts_ms",             LongType()),
    ]),

    "banks": StructType([
        StructField("bank_id",    IntegerType()),
        StructField("bank_name",  StringType()),
        StructField("country",    StringType()),
        StructField("swift_code", StringType()),
        StructField("__op",       StringType()),
        StructField("__table",    StringType()),
        StructField("__source_ts_ms", LongType()),
    ])
}

# CREATE ICEBERG TABLES
spark.sql("""
    CREATE TABLE IF NOT EXISTS iceberg.raw.transactions (
        transaction_id   INT,
        account_id       INT,
        type             STRING,
        amount           DOUBLE,
        currency         STRING,
        exchange_rate    DOUBLE,
        amount_in_usd    DOUBLE,
        status           STRING,
        channel          STRING,
        country          STRING,
        city             STRING,
        description      STRING,
        created_at       BIGINT,
        updated_at       BIGINT,
        cdc_op           STRING,
        ingested_at      TIMESTAMP,
        ingestion_date   DATE
    ) USING iceberg PARTITIONED BY (ingestion_date)
""")

spark.sql("""
    CREATE TABLE IF NOT EXISTS iceberg.raw.customers (
        customer_id    INT,
        full_name      STRING,
        email          STRING,
        phone          STRING,
        nationality    STRING,
        created_at     BIGINT,
        updated_at     BIGINT,
        cdc_op         STRING,
        ingested_at    TIMESTAMP,
        ingestion_date DATE
    ) USING iceberg PARTITIONED BY (ingestion_date)
""")

spark.sql("""
    CREATE TABLE IF NOT EXISTS iceberg.raw.accounts (
        account_id     INT,
        customer_id    INT,
        bank_id        INT,
        account_type   STRING,
        balance        DOUBLE,
        currency       STRING,
        account_status STRING,
        opened_at      BIGINT,
        updated_at     BIGINT,
        cdc_op         STRING,
        ingested_at    TIMESTAMP,
        ingestion_date DATE
    ) USING iceberg PARTITIONED BY (ingestion_date)
""")

spark.sql("""
    CREATE TABLE IF NOT EXISTS iceberg.raw.transaction_legs (
        leg_id                      INT,
        transaction_id              INT,
        direction                   STRING,
        account_id                  INT,
        bank_id                     INT,
        external_account_reference  STRING,
        external_account_name       STRING,
        amount                      DOUBLE,
        currency                    STRING,
        cdc_op                      STRING,
        ingested_at                 TIMESTAMP,
        ingestion_date              DATE
    ) USING iceberg PARTITIONED BY (ingestion_date)
""")

spark.sql("""
    CREATE TABLE IF NOT EXISTS iceberg.raw.banks (
        bank_id       INT,
        bank_name     STRING,
        country       STRING,
        swift_code    STRING,
        cdc_op        STRING,
        ingested_at   TIMESTAMP,
        ingestion_date DATE
    ) USING iceberg PARTITIONED BY (ingestion_date)
""")

print("All Iceberg tables ready")


# READ ALL TOPICS FROM KAFKA
topics = [
    "banking.banking.transactions",
    "banking.banking.customers",
    "banking.banking.accounts",
    "banking.banking.transaction_legs",
    "banking.banking.banks"
]

kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", ",".join(topics)) \
    .option("startingOffsets", "earliest") \
    .option("failOnDataLoss", "false") \
    .load()


# PROCESS EACH BATCH
def write_to_iceberg(batch_df, batch_id):
    if batch_df.count() == 0:
        return

    for topic in topics:
        table_name = topic.split(".")[-1]
        schema = schemas[table_name]

        topic_df = batch_df.filter(col("topic") == topic)

        if topic_df.count() == 0:
            continue

        try:
            parsed_df = topic_df \
                .select(
                    from_json(col("value").cast("string"), schema).alias("data")
                ) \
                .select("data.*") \
                .withColumn("cdc_op",         col("__op")) \
                .withColumn("ingested_at",    current_timestamp()) \
                .withColumn("ingestion_date", to_date(current_timestamp())) \
                .drop("__op", "__table", "__source_ts_ms")

            count = parsed_df.count()
            if count == 0:
                continue

            print(f"Batch {batch_id}: writing {count} rows to iceberg.raw.{table_name}")
            parsed_df.writeTo(f"iceberg.raw.{table_name}").append()
            print(f"iceberg.raw.{table_name} done")

        except Exception as e:
            print(f"Failed to process {table_name} in batch {batch_id}: {e}")
            print(f"Sending failed messages to dead letter topic")

            # Send failed messages to dead letter topic
            topic_df.select(
                col("topic"),
                col("value"),
                col("offset"),
                col("timestamp"),
                current_timestamp().alias("failed_at"),
                lit(str(e)).alias("error_message")
            ).write \
                .format("kafka") \
                .option("kafka.bootstrap.servers", "kafka:9092") \
                .option("topic", f"dead_letter.{table_name}") \
                .save()

            print(f"Failed messages sent to dead_letter.{table_name}")

# ─────────────────────────────────────────
# START STREAMING
# ─────────────────────────────────────────
query = kafka_df.writeStream \
    .foreachBatch(write_to_iceberg) \
    .option("checkpointLocation", "s3a://oyin-banking-iceberg-warehouse/checkpoints/all_tables")  \
    .trigger(processingTime="30 seconds") \
    .start()

print("Streaming job started — watching all topics")
for t in topics:
    print(f"   {t}")

query.awaitTermination()