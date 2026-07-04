terraform {
  backend "s3" {
    bucket         = "rahul-monitoring-tfstate-860217763718"
    key            = "monitoring/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
