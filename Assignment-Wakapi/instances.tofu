resource "google_service_account" "compute_script_access" {
  account_id   = "compute-script-access"
  display_name = "Compute Script Access"
}

resource "google_storage_bucket" "scripts" {
  name          = var.bucket_name
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
  source = "./startup-wakapi.sh"
  # content      = "Data as string to be uploaded"
  content_type = "text/plain"
  bucket       = google_storage_bucket.scripts.id
}

resource "google_compute_instance_template" "wakapi_template" {
  name         = "wakapi-template"
  machine_type = var.instance_type
  tags = setunion(
    google_compute_firewall.allow_ssh.target_tags,
    google_compute_firewall.allow_http_from_proxy.target_tags,
    google_compute_firewall.allow_health_checks.target_tags,
    google_compute_firewall.allow_internal_icmp.target_tags
  )

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
    startup-script-url   = "${google_storage_bucket.scripts.url}/${google_storage_bucket_object.startup_wakapi.name}"
    WAKAPI_DB_TYPE       = var.WAKAPI_DB_TYPE
    WAKAPI_DB_NAME       = var.WAKAPI_DB_NAME
    WAKAPI_DB_USER       = var.WAKAPI_DB_USER
    WAKAPI_DB_PORT       = var.WAKAPI_DB_PORT
    WAKAPI_DB_PASSWORD   = random_password.WAKAPI_DB_PASSWORD.result
    WAKAPI_PASSWORD_SALT = random_password.WAKAPI_PASSWORD_SALT.result
    WAKAPI_DB_HOST       = google_sql_database_instance.wakapi_db.ip_address.0.ip_address
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