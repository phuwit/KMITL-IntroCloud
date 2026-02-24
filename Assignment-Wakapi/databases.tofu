# managed sql

resource "google_sql_database_instance" "wakapi_db" {
  name                = "wakapi-db"
  region              = var.region
  database_version    = var.database_version
  root_password       = random_password.WAKAPI_DB_ROOT_PASSWORD.result
  deletion_protection = false

  settings {
    tier              = var.database_instance_tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_size         = 10
    ip_configuration {
      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]
      }
      ipv4_enabled = false
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
