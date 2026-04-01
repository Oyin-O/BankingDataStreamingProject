# ─────────────────────────────────────────
# TERRAFORM CONFIG
# ─────────────────────────────────────────
terraform {
  backend "s3" {
    bucket = "oyin-banking-iceberg-warehouse"
    key    = "terraform/snowflake/terraform.tfstate"
    region = "eu-west-2"
  }

  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
  }
}

# ─────────────────────────────────────────
# PROVIDERS
# ─────────────────────────────────────────
provider "snowflake" {
  alias             = "accountadmin"
  organization_name = var.snowflake_organization
  account_name      = var.snowflake_account_name
  user              = "TERRAFORM_SVC"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.snowflake_private_key_path)
  role              = "ACCOUNTADMIN"
  preview_features_enabled = [
    "snowflake_storage_integration_resource"
  ]
}

provider "snowflake" {
  alias             = "sysadmin"
  organization_name = var.snowflake_organization
  account_name      = var.snowflake_account_name
  user              = "TERRAFORM_SVC"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.snowflake_private_key_path)
  role              = "SYSADMIN"
  preview_features_enabled = [
    "snowflake_table_resource",
    "snowflake_stage_resource",
    "snowflake_storage_integration_resource"
  ]
}

provider "snowflake" {
  alias             = "securityadmin"
  organization_name = var.snowflake_organization
  account_name      = var.snowflake_account_name
  user              = "TERRAFORM_SVC"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.snowflake_private_key_path)
  role              = "SECURITYADMIN"
}

# ─────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────
resource "snowflake_database" "banking" {
  provider = snowflake.sysadmin
  name     = "BANKING_DB"
}

# ─────────────────────────────────────────
# SCHEMAS
# ─────────────────────────────────────────
resource "snowflake_schema" "bronze" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  name     = "BRONZE"
}

resource "snowflake_schema" "silver" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  name     = "SILVER"
}

resource "snowflake_schema" "gold" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  name     = "GOLD"
}

resource "snowflake_schema" "snapshots" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  name     = "SNAPSHOTS"
}

# ─────────────────────────────────────────
# WAREHOUSE
# ─────────────────────────────────────────
resource "snowflake_warehouse" "banking" {
  provider       = snowflake.sysadmin
  name           = "BANKING_WH"
  warehouse_size = "x-small"
  auto_suspend   = 60
  auto_resume    = true
}

# ─────────────────────────────────────────
# STORAGE INTEGRATION
# ─────────────────────────────────────────
resource "snowflake_storage_integration" "s3" {
  provider                  = snowflake.sysadmin
  name                      = "BANKING_S3_INTEGRATION"
  type                      = "EXTERNAL_STAGE"
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = var.snowflake_role_arn
  storage_allowed_locations = ["s3://${var.s3_bucket}/"]
}

# ─────────────────────────────────────────
# STAGE
# ─────────────────────────────────────────
resource "snowflake_stage" "banking" {
  provider            = snowflake.sysadmin
  name                = "BANKING_S3_STAGE"
  database            = snowflake_database.banking.name
  schema              = snowflake_schema.bronze.name
  storage_integration = snowflake_storage_integration.s3.name
  url                 = "s3://${var.s3_bucket}/warehouse/"
}

# ─────────────────────────────────────────
# BRONZE TABLES
# ─────────────────────────────────────────
resource "snowflake_table" "bronze_transactions" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  schema   = snowflake_schema.bronze.name
  name     = "TRANSACTIONS"

  column {
    name = "TRANSACTION_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "ACCOUNT_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "TYPE"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "AMOUNT"
    type = "FLOAT"
  }
  column {
    name = "CURRENCY"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "EXCHANGE_RATE"
    type = "FLOAT"
  }
  column {
    name = "AMOUNT_IN_USD"
    type = "FLOAT"
  }
  column {
    name = "STATUS"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "CHANNEL"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "COUNTRY"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "CITY"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "DESCRIPTION"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "CREATED_AT"
    type = "NUMBER(38,0)"
  }
  column {
    name = "UPDATED_AT"
    type = "NUMBER(38,0)"
  }
  column {
    name = "CDC_OP"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "INGESTED_AT"
    type = "TIMESTAMP_NTZ(9)"
  }
  column {
    name = "INGESTION_DATE"
    type = "DATE"
  }
}

resource "snowflake_table" "bronze_customers" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  schema   = snowflake_schema.bronze.name
  name     = "CUSTOMERS"

  column {
    name = "CUSTOMER_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "FULL_NAME"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "EMAIL"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "PHONE"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "NATIONALITY"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "CREATED_AT"
    type = "NUMBER(38,0)"
  }
  column {
    name = "UPDATED_AT"
    type = "NUMBER(38,0)"
  }
  column {
    name = "CDC_OP"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "INGESTED_AT"
    type = "TIMESTAMP_NTZ(9)"
  }
  column {
    name = "INGESTION_DATE"
    type = "DATE"
  }
}

resource "snowflake_table" "bronze_accounts" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  schema   = snowflake_schema.bronze.name
  name     = "ACCOUNTS"

  column {
    name = "ACCOUNT_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "CUSTOMER_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "BANK_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "ACCOUNT_TYPE"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "BALANCE"
    type = "FLOAT"
  }
  column {
    name = "CURRENCY"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "ACCOUNT_STATUS"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "OPENED_AT"
    type = "NUMBER(38,0)"
  }
  column {
    name = "UPDATED_AT"
    type = "NUMBER(38,0)"
  }
  column {
    name = "CDC_OP"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "INGESTED_AT"
    type = "TIMESTAMP_NTZ(9)"
  }
  column {
    name = "INGESTION_DATE"
    type = "DATE"
  }
}

resource "snowflake_table" "bronze_transaction_legs" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  schema   = snowflake_schema.bronze.name
  name     = "TRANSACTION_LEGS"

  column {
    name = "LEG_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "TRANSACTION_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "DIRECTION"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "ACCOUNT_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "BANK_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "EXTERNAL_ACCOUNT_REFERENCE"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "EXTERNAL_ACCOUNT_NAME"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "AMOUNT"
    type = "FLOAT"
  }
  column {
    name = "CURRENCY"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "CDC_OP"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "INGESTED_AT"
    type = "TIMESTAMP_NTZ(9)"
  }
  column {
    name = "INGESTION_DATE"
    type = "DATE"
  }
}

resource "snowflake_table" "bronze_banks" {
  provider = snowflake.sysadmin
  database = snowflake_database.banking.name
  schema   = snowflake_schema.bronze.name
  name     = "BANKS"

  column {
    name = "BANK_ID"
    type = "NUMBER(38,0)"
  }
  column {
    name = "BANK_NAME"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "COUNTRY"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "SWIFT_CODE"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "CDC_OP"
    type = "VARCHAR(16777216)"
  }
  column {
    name = "INGESTED_AT"
    type = "TIMESTAMP_NTZ(9)"
  }
  column {
    name = "INGESTION_DATE"
    type = "DATE"
  }
}

# ─────────────────────────────────────────
# ROLES
# ─────────────────────────────────────────
resource "snowflake_account_role" "loader" {
  provider = snowflake.securityadmin
  name     = "LOADER_ROLE"
}

resource "snowflake_account_role" "transformer" {
  provider = snowflake.securityadmin
  name     = "TRANSFORMER_ROLE"
}

resource "snowflake_account_role" "reporter" {
  provider = snowflake.securityadmin
  name     = "REPORTER_ROLE"
}

# ─────────────────────────────────────────
# USERS
# ─────────────────────────────────────────
resource "snowflake_user" "airflow" {
  provider          = snowflake.securityadmin
  name              = "AIRFLOW_USER"
  login_name        = "airflow_user"
  default_role      = snowflake_account_role.loader.name
  default_warehouse = snowflake_warehouse.banking.name
  rsa_public_key    = var.airflow_user_public_key
}

resource "snowflake_user" "dbt" {
  provider          = snowflake.securityadmin
  name              = "DBT_USER"
  login_name        = "dbt_user"
  default_role      = snowflake_account_role.transformer.name
  default_warehouse = snowflake_warehouse.banking.name
  rsa_public_key    = var.dbt_user_public_key
}

resource "snowflake_user" "reporter" {
  provider          = snowflake.securityadmin
  name              = "REPORTER_USER"
  login_name        = "reporter_user"
  default_role      = snowflake_account_role.reporter.name
  default_warehouse = snowflake_warehouse.banking.name
  rsa_public_key    = var.reporter_user_public_key
}

# ─────────────────────────────────────────
# GRANT ROLES TO USERS
# ─────────────────────────────────────────
resource "snowflake_grant_account_role" "airflow" {
  provider  = snowflake.securityadmin
  role_name = snowflake_account_role.loader.name
  user_name = snowflake_user.airflow.name
}

resource "snowflake_grant_account_role" "dbt" {
  provider  = snowflake.securityadmin
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_user.dbt.name
}

resource "snowflake_grant_account_role" "reporter" {
  provider  = snowflake.securityadmin
  role_name = snowflake_account_role.reporter.name
  user_name = snowflake_user.reporter.name
}

# ─────────────────────────────────────────
# WAREHOUSE GRANTS
# ─────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_warehouse" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.banking.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_warehouse" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.banking.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "reporter_warehouse" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.reporter.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.banking.name
  }
}

# ─────────────────────────────────────────
# DATABASE GRANTS
# ─────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_database" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.banking.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_database" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.banking.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "reporter_database" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.reporter.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.banking.name
  }
}

# ─────────────────────────────────────────
# SCHEMA GRANTS
# ─────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_bronze_schema" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.bronze.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_bronze_schema" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.bronze.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_silver_schema" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE TABLE"]
  on_schema {
    schema_name = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.silver.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_gold_schema" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE TABLE"]
  on_schema {
    schema_name = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.gold.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_snapshots_schema" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE", "CREATE TABLE"]
  on_schema {
    schema_name = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.snapshots.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "reporter_gold_schema" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.reporter.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.gold.name}\""
  }
}

# ─────────────────────────────────────────
# TABLE GRANTS
# ─────────────────────────────────────────
resource "snowflake_grant_privileges_to_account_role" "loader_bronze_tables" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["INSERT", "SELECT"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.bronze.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_bronze_tables" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.bronze.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "reporter_gold_tables" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.reporter.name
  privileges        = ["SELECT"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.gold.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "loader_stage" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.loader.name
  privileges        = ["USAGE", "READ"]
  on_schema_object {
    object_type = "STAGE"
    object_name = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.bronze.name}\".\"BANKING_S3_STAGE\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_silver_tables" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.silver.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_gold_tables" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.gold.name}\""
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_snapshots_tables" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.banking.name}\".\"${snowflake_schema.snapshots.name}\""
    }
  }
}

# ─────────────────────────────────────────
# OUTPUTS
# ─────────────────────────────────────────
output "snowflake_role_arn" {
  value     = snowflake_storage_integration.s3.storage_aws_role_arn
  sensitive = true
}