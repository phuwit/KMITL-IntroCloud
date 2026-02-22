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
