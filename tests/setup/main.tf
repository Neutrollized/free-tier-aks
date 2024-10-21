terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}



resource "random_pet" "cluster_name_prefix" {
  length = 2
}

output "cluster_name_prefix" {
  value = random_pet.cluster_name_prefix.id
}

resource "random_integer" "cluster_id" {
  min = 1
  max = 500
}

output "cluster_id" {
  value = random_integer.cluster_id.id
}
