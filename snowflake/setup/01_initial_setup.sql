USE ROLE ACCOUNTADMIN;

-- DATABASE AND SCHEMAS

CREATE DATABASE IF NOT EXISTS banking_db;

CREATE SCHEMA IF NOT EXISTS banking_db.bronze;
CREATE SCHEMA IF NOT EXISTS banking_db.silver;
CREATE SCHEMA IF NOT EXISTS banking_db.gold;

-- WAREHOUSE

CREATE WAREHOUSE IF NOT EXISTS banking_wh
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE DATABASE banking_db;
USE WAREHOUSE banking_wh;

-- STORAGE INTEGRATION

CREATE STORAGE INTEGRATION IF NOT EXISTS banking_s3_integration
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::168379645519:role/snowflake-s3-role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://oyin-banking-iceberg-warehouse/');

CREATE STORAGE INTEGRATION IF NOT EXISTS banking_s3_integration
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = '{{SNOWFLAKE_ROLE_ARN}}'
    STORAGE_ALLOWED_LOCATIONS = ('s3://{{SNOWFLAKE_S3_BUCKET}}/');


-- STAGE
CREATE STAGE IF NOT EXISTS banking_db.bronze.banking_s3_stage
    URL = 's3://{{SNOWFLAKE_S3_BUCKET}}/warehouse/'
    STORAGE_INTEGRATION = banking_s3_integration;

-- BRONZE TABLES

CREATE OR REPLACE TABLE banking_db.bronze.transactions (
    transaction_id   INT,
    account_id       INT,
    type             VARCHAR,
    amount           FLOAT,
    currency         VARCHAR,
    exchange_rate    FLOAT,
    amount_in_usd    FLOAT,
    status           VARCHAR,
    channel          VARCHAR,
    country          VARCHAR,
    city             VARCHAR,
    description      VARCHAR,
    created_at       BIGINT,
    updated_at       BIGINT,
    cdc_op           VARCHAR,
    ingested_at      TIMESTAMP,
    ingestion_date   DATE
);

CREATE OR REPLACE TABLE banking_db.bronze.customers (
    customer_id    INT,
    full_name      VARCHAR,
    email          VARCHAR,
    phone          VARCHAR,
    nationality    VARCHAR,
    created_at     BIGINT,
    updated_at     BIGINT,
    cdc_op         VARCHAR,
    ingested_at    TIMESTAMP,
    ingestion_date DATE
);

CREATE OR REPLACE TABLE banking_db.bronze.accounts (
    account_id     INT,
    customer_id    INT,
    bank_id        INT,
    account_type   VARCHAR,
    balance        FLOAT,
    currency       VARCHAR,
    opened_at      BIGINT,
    updated_at     BIGINT,
    cdc_op         VARCHAR,
    ingested_at    TIMESTAMP,
    ingestion_date DATE
);

CREATE OR REPLACE TABLE banking_db.bronze.transaction_legs (
    leg_id                      INT,
    transaction_id              INT,
    direction                   VARCHAR,
    account_id                  INT,
    bank_id                     INT,
    external_account_reference  VARCHAR,
    external_account_name       VARCHAR,
    amount                      FLOAT,
    currency                    VARCHAR,
    cdc_op                      VARCHAR,
    ingested_at                 TIMESTAMP,
    ingestion_date              DATE
);