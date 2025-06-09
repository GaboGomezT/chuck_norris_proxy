terraform {
  backend "s3" {
    bucket         = "chuck-norris-proxy-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"  # You may want to change this to your preferred region
    dynamodb_table = "chuck-norris-proxy-terraform-locks"
    encrypt        = true
  }
} 