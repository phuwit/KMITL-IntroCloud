variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_domain" {
  type = string
}

variable "wakapi_subdomain" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "bucket_location" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "lb_backend_scheme" {
  type = string
}

variable "lb_scheme" {
  type = string
}

variable "lb_network_tier" {
  type = string
}

variable "database_instance_tier" {
  type = string
}

variable "database_version" {
  type = string
}

variable "alert_cpu_usage_percent_fraction_gt" {
  type = number
}

variable "alert_email_address" {
  type = string
}

variable "WAKAPI_DB_TYPE" {
  type = string
}

variable "WAKAPI_DB_NAME" {
  type = string
}

variable "WAKAPI_DB_USER" {
  type = string
}

variable "WAKAPI_DB_PORT" {
  type = number
}

resource "random_password" "WAKAPI_DB_PASSWORD" {
  length  = 64
  special = false
}

resource "random_password" "WAKAPI_DB_ROOT_PASSWORD" {
  length  = 64
  special = false
}

resource "random_password" "WAKAPI_PASSWORD_SALT" {
  length  = 64
  special = false
}
