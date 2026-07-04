variable "bucket_name" {
  description = "Terraform Remote State Bucket"
  type        = string
  default     = "rahul-monitoring-tfstate-860217763718"
}

variable "dynamodb_table_name" {
  description = "Terraform State Lock Table"
  type        = string
  default     = "terraform-locks"
}
