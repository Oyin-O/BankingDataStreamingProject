variable "snowflake_iam_user_arn" {
  description = "Snowflake IAM user ARN"
  type        = string
  default     = "arn:aws:iam::000000000000:root"  # placeholder
}

variable "snowflake_external_id" {
  description = "Snowflake external ID"
  type        = string
  default     = "placeholder"
}