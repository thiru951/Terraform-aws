terraform {
  backend "s3" {
    bucket         = "thiru-terraform-state-devops"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

