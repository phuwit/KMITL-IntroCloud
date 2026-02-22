terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=7.20.0"
    }
  }
}

variable "project_id" {
  default = "alright4258-test"
}

variable "region" {
  default = "asia-southeast1"
}

variable "zone" {
  default = "asia-southeast1-c"
}

variable "bucket_location" {
  default = "ASIA-SOUTHEAST1"
}

variable "instance_type" {
  default = "e2-medium"
}

variable "database_instance_tier" {
  default = "db-g1-small"
}

variable "database_version" {
  default = "POSTGRES_18"
}

variable "alert_cpu_usage_percent_fraction_gt" {
  default = 0.95
}

variable "alert_email_address" {
  default   = "fakeemail@bigblahaj.com"
  sensitive = true
}

variable "WAKAPI_DB_TYPE" {
  default = "postgres"
}

variable "WAKAPI_DB_NAME" {
  default = "wakapi"
}

variable "WAKAPI_DB_USER" {
  default = "wakapi"
}

variable "WAKAPI_DB_PORT" {
  default = 5432
}

resource "random_password" "WAKAPI_DB_PASSWORD" {
  length  = 64
  special = false
}

resource "random_password" "WAKAPI_DB_ROOT_PASSWORD" {
  length  = 64
  special = false
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_service_account" "compute_script_access" {
  account_id   = "compute-script-access"
  display_name = "Compute Script Access"
}

resource "google_compute_network" "wakapi_net" {
  name                    = "wakapi-net"
  auto_create_subnetworks = false
}

resource "google_compute_network_peering" "wakapi_default_peering" {
  name         = "wakapi-default-peering"
  network      = google_compute_network.wakapi_net.id
  peer_network = "projects/${var.project_id}/global/networks/default"
}

resource "google_compute_network_peering" "default_wakapi_peering" {
  name         = "default-wakapi-peering"
  network      = "projects/${var.project_id}/global/networks/default"
  peer_network = google_compute_network.wakapi_net.id
}

resource "google_compute_subnetwork" "subnet_instances" {
  name          = "wakapi-subnet-instances"
  ip_cidr_range = "10.69.1.0/24"
  network       = google_compute_network.wakapi_net.id
}

# resource "google_compute_subnetwork" "subnet_databases" {
#   name          = "wakapi-subnet-databases"
#   ip_cidr_range = "10.69.0.0/24"
#   network       = google_compute_network.wakapi_net.id
# }

resource "google_compute_global_address" "wakapi_db_ip" {
  name          = "wakapi-db-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  address       = "10.69.0.0"
  network       = google_compute_network.wakapi_net.id
}

resource "google_compute_address" "wakapi_unmanaged_ip" {
  name         = "wakapi-unmanaged-ip"
  subnetwork   = google_compute_subnetwork.subnet_instances.id
  address_type = "INTERNAL"
  address      = "10.69.1.2"
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https"
  network = google_compute_network.wakapi_net.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-http-https"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.wakapi_net.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

resource "google_compute_firewall" "allow_internal_icmp" {
  name    = "allow-internal-icmp"
  network = google_compute_network.wakapi_net.id

  allow {
    protocol = "icmp"
  }

  source_ranges = [google_compute_subnetwork.subnet_instances.ip_cidr_range]
  target_tags   = ["allow-internal-icmp"]
}

resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks"
  network = google_compute_network.wakapi_net.id

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["allow-health-checks"]
}

resource "google_compute_network_endpoint_group" "wakapi" {
  name         = "wakapi-neg"
  network      = google_compute_network.wakapi_net.id
  subnetwork   = google_compute_subnetwork.subnet_instances.id
  default_port = "80"
  zone         = var.zone
}

resource "google_storage_bucket" "scripts" {
  name          = "alright4258-scripts-test"
  location      = var.bucket_location
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "compute_script_access" {
  bucket = google_storage_bucket.scripts.name
  role   = "roles/storage.objectViewer"

  members = [
    google_service_account.compute_script_access.member,
  ]
}

resource "google_storage_bucket_object" "startup_wakapi" {
  name = "startup-wakapi.sh"
  # Use `source` or `content`
  source = "../Assignment-Wakapi/startup-wakapi.sh"
  # content      = "Data as string to be uploaded"
  content_type = "text/plain"
  bucket       = google_storage_bucket.scripts.id
}

resource "google_compute_instance_template" "wakapi_template" {
  name         = "wakapi-template"
  machine_type = var.instance_type
  tags         = setunion(google_compute_firewall.allow_ssh.target_tags, google_compute_firewall.allow_http_https.target_tags, google_compute_firewall.allow_health_checks.target_tags, google_compute_firewall.allow_internal_icmp.target_tags)

  disk {
    source_image = "debian-cloud/debian-13"
  }

  network_interface {
    network    = google_compute_network.wakapi_net.id
    subnetwork = google_compute_subnetwork.subnet_instances.id
    access_config {
    }
  }

  service_account {
    email = google_service_account.compute_script_access.email
    scopes = ["compute-ro",
      "logging-write",
      "monitoring-write",
      "storage-ro",
    "trace"]
  }

  metadata = {
    startup-script-url = "${google_storage_bucket.scripts.url}/${google_storage_bucket_object.startup_wakapi.name}",
    WAKAPI_DB_TYPE     = var.WAKAPI_DB_TYPE
    WAKAPI_DB_NAME     = var.WAKAPI_DB_NAME
    WAKAPI_DB_USER     = var.WAKAPI_DB_USER
    WAKAPI_DB_PORT     = var.WAKAPI_DB_PORT
    WAKAPI_DB_PASSWORD = random_password.WAKAPI_DB_PASSWORD.result
    WAKAPI_DB_HOST     = google_sql_database_instance.wakapi_db.ip_address.0.ip_address
  }
}

# unmanaged instance

resource "google_compute_instance_from_template" "wakapi_unmanaged" {
  name                     = "wakapi-unmanaged"
  source_instance_template = google_compute_instance_template.wakapi_template.self_link_unique

  network_interface {
    network    = google_compute_network.wakapi_net.id
    subnetwork = google_compute_subnetwork.subnet_instances.id
    network_ip = google_compute_address.wakapi_unmanaged_ip.address
    access_config {
    }
  }
}

resource "google_compute_instance_group" "wakapi_unmanaged" {
  name = "wakapi-unmanaged"

  instances = [
    google_compute_instance_from_template.wakapi_unmanaged.id,
  ]

  named_port {
    name = "http"
    port = "80"
  }
}

# managed instance groups

resource "google_compute_region_autoscaler" "wakapi_autoscaler" {
  name   = "wakapi-autoscaler"
  target = google_compute_region_instance_group_manager.wakapi_mig.id

  autoscaling_policy {
    max_replicas    = 2
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.95
    }
  }
}

resource "google_compute_region_instance_group_manager" "wakapi_mig" {
  name = "wakapi-mig"

  version {
    instance_template = google_compute_instance_template.wakapi_template.id
    name              = "primary"
  }

  # target_pools       = [google_compute_target_pool.wakapi_pool.id]
  base_instance_name = "wakapi-mig"

  depends_on = [google_compute_instance_template.wakapi_template]

  named_port {
    name = "http"
    port = "80"
  }
}

# managed sql

resource "google_service_networking_connection" "wakapi_db_vpc_connection" {
  network                 = google_compute_network.wakapi_net.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.wakapi_db_ip.name]
}

resource "google_sql_database_instance" "wakapi_db" {
  name                = "wakapi-db"
  region              = var.region
  database_version    = var.database_version
  root_password       = random_password.WAKAPI_DB_ROOT_PASSWORD.result
  deletion_protection = false

  depends_on = [google_service_networking_connection.wakapi_db_vpc_connection]

  settings {
    tier              = var.database_instance_tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_size         = 10
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.wakapi_net.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
}

resource "google_sql_user" "wakapi" {
  name     = var.WAKAPI_DB_USER
  password = random_password.WAKAPI_DB_PASSWORD.result
  instance = google_sql_database_instance.wakapi_db.name
}

resource "google_sql_database" "wakapi" {
  name     = var.WAKAPI_DB_NAME
  instance = google_sql_database_instance.wakapi_db.name
}

# load balancer

resource "google_compute_health_check" "http_health_check" {
  name = "http-health-check"

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "wakapi_backend" {
  name                  = "wakapi-backend"
  enable_cdn            = false
  health_checks         = [google_compute_health_check.http_health_check.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    group           = google_compute_instance_group.wakapi_unmanaged.id
  }

  backend {
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    group           = google_compute_region_instance_group_manager.wakapi_mig.instance_group
  }
}

resource "google_compute_url_map" "wakapi_http_lb" {
  name            = "wakapi-http-lb"
  default_service = google_compute_backend_service.wakapi_backend.self_link
}

resource "google_compute_target_http_proxy" "wakapi_http_lb_proxy" {
  name    = "wakapi-http-lb-target-proxy"
  url_map = google_compute_url_map.wakapi_http_lb.self_link
}

resource "google_compute_global_forwarding_rule" "wakapi_http_ip_lb_frontend" {
  name                  = "wakapi-http-ip-lb-frontend"
  target                = google_compute_target_http_proxy.wakapi_http_lb_proxy.self_link
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}

resource "google_compute_ssl_certificate" "cloudflare_bigblahaj" {
  name_prefix = "cloudflare-bigblahaj-"
  private_key = file("../Certificates/cloudflare-bigblahaj-com.key")
  certificate = file("../Certificates/cloudflare-bigblahaj-com.pem")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_global_address" "wakapi_bigblahaj_com" {
  name = "wakapi-bigblahaj-com-ip"
}

resource "google_compute_target_https_proxy" "wakapi_bigblahaj_com" {
  name             = "wakapi-bigblahaj-https-proxy"
  url_map          = google_compute_url_map.wakapi_http_lb.id
  ssl_certificates = [google_compute_ssl_certificate.cloudflare_bigblahaj.id]
}

resource "google_compute_global_forwarding_rule" "wakapi_https_bigblahaj_lb_frontend" {
  name                  = "wakapi-https-bigblahaj-lb-frontend"
  provider              = google
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
  port_range            = "443"
  target                = google_compute_target_https_proxy.wakapi_bigblahaj_com.id
  ip_address            = google_compute_global_address.wakapi_bigblahaj_com.id
}

# alerts

resource "google_monitoring_notification_channel" "notification_email" {
  display_name = "Wakapi Email Notification Channel"
  type         = "email"
  labels = {
    email_address = var.alert_email_address
  }
}

resource "google_monitoring_alert_policy" "wakapi_cpu_alert" {
  display_name = "Wakapi Instances CPU Utilization > ${var.alert_cpu_usage_percent_fraction_gt}"
  documentation {
    content = "The $${metric.display_name} of the $${resource.type} $${resource.label.instance_id} in $${resource.project} has exceeded ${var.alert_cpu_usage_percent_fraction_gt} for over 1 minute."
  }
  combiner = "OR"
  conditions {
    display_name = "Condition 1"
    condition_threshold {
      comparison      = "COMPARISON_GT"
      duration        = "60s"
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\" AND metric.labels.instance_name = starts_with(\"wakapi\")"
      threshold_value = var.alert_cpu_usage_percent_fraction_gt
      aggregations {
        alignment_period   = "60s"
        cross_series_reducer = "REDUCE_MEAN"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.notification_email.name]

  user_labels = {
    severity = "warning"
  }
}
