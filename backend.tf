terraform {
  backend "s3" {
    bucket       = "terraform-vijay-state"
    key          = "eks/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}