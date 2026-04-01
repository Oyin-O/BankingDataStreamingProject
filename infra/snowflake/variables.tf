variable "snowflake_account_name" {
  description = "Snowflake account identifier"
  type        = string
  sensitive   = true
}

variable "snowflake_user" {
  description = "Snowflake username"
  type        = string
  sensitive   = true
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "snowflake_role_arn" {
  description = "AWS IAM role ARN for Snowflake"
  type        = string
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "snowflake_private_key_path" {
  description = "Path to Terraform private key"
  type        = string
}

variable "snowflake_organization" {
  description = "Snowflake organization name"
  type        = string
}

variable "dbt_user_public_key" {
  description = "Public key for dbt user"
  type        = string
  sensitive   = true
}

variable "airflow_user_public_key" {
  description = "Public key for Airflow user"
  type        = string
  sensitive   = true
}

variable "reporter_user_public_key" {
  description = "Public key for reporter user"
  type        = string
  sensitive   = true
}