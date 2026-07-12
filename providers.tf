terraform {
  # OCI Resource Manager caps Terraform at 1.5.x (HashiCorp BSL license change),
  # so keep the constraint compatible with the versions ORM offers.
  required_version = ">= 1.2.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.22"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

provider "oci" {}
