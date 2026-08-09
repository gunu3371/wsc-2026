terraform { required_version = ">= 1.7.0"
required_providers { keycloak = { source = "keycloak/keycloak", version = "~> 5.0" } } }
provider "keycloak" { client_id = "admin-cli"
username = var.admin_username
password = var.admin_password
url = var.keycloak_url }
variable "keycloak_url" { type = string }
variable "admin_username" { type = string
default = "admin" }
variable "admin_password" { type = string
sensitive = true }
variable "dev_password" { type = string
sensitive = true
default = "Skills_dev53%$%" }
variable "infra_password" { type = string
sensitive = true
default = "Skills_infra53#@#" }
variable "dev_role_arn" { type = string }
variable "infra_role_arn" { type = string }
variable "saml_provider_arn" { type = string }
