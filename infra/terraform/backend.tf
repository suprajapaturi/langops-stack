terraform {
  backend "gcs" {
    bucket = "langops-stack-terraform-state"
    prefix = "terraform/state"
  }
}
