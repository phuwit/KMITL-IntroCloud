# unmanaged net

resource "google_compute_network" "wakapi_unmanaged_net" {
  name                    = "wakapi-unmanaged-net"
  auto_create_subnetworks = false
}

resource "google_compute_network_peering" "wakapi_unmanaged_default_peering" {
  name         = "wakapi-unmanaged-default-peering"
  network      = google_compute_network.wakapi_unmanaged_net.id
  peer_network = google_compute_network.default.id
}

resource "google_compute_network_peering" "wakapi_unmanaged_managed_peering" {
  name         = "wakapi-unmanaged-managed-peering"
  network      = google_compute_network.wakapi_unmanaged_net.id
  peer_network = google_compute_network.wakapi_managed_net.id
}

resource "google_compute_network_peering" "wakapi_unmanaged_proxy_peering" {
  name         = "wakapi-unmanaged-proxy-peering"
  network      = google_compute_network.wakapi_unmanaged_net.id
  peer_network = google_compute_network.wakapi_proxy_net.id
}

resource "google_compute_subnetwork" "unmanaged_instances" {
  name          = "unmanaged-instances"
  ip_cidr_range = "10.69.10.0/24"
  network       = google_compute_network.wakapi_unmanaged_net.id
}

resource "google_compute_address" "wakapi_unmanaged_ip" {
  name         = "wakapi-unmanaged-ip"
  subnetwork   = google_compute_subnetwork.unmanaged_instances.id
  address_type = "INTERNAL"
  address      = "10.69.10.2"
}

resource "google_compute_firewall" "unmanaged_allow_internet_ssh" {
  name    = "wakapi-unmanaged-allow-internet-ssh"
  network = google_compute_network.wakapi_unmanaged_net.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

resource "google_compute_firewall" "unmanaged_allow_internal_icmp" {
  name    = "wakapi-unmanaged-allow-internal-icmp"
  network = google_compute_network.wakapi_unmanaged_net.id

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    google_compute_subnetwork.unmanaged_instances.ip_cidr_range,
    google_compute_subnetwork.managed_instances.ip_cidr_range,
    google_compute_subnetwork.lb_proxy.ip_cidr_range,
  ]
  target_tags = ["allow-internal-icmp"]
}

resource "google_compute_firewall" "unmanaged_allow_http_from_proxy" {
  name    = "wakapi-unmanaged-allow-http-from-proxy"
  network = google_compute_network.wakapi_unmanaged_net.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [google_compute_subnetwork.lb_proxy.ip_cidr_range]
  target_tags   = ["allow-http-from-proxy"]
}

resource "google_compute_firewall" "unmanaged_allow_health_checks" {
  name    = "wakapi-unmanaged-allow-health-checks"
  network = google_compute_network.wakapi_unmanaged_net.id

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["allow-health-checks"]
}

resource "google_network_connectivity_service_connection_policy" "unmanaged_db" {
  name          = "unmanaged-connectivity-policy"
  location      = var.region
  service_class = "google-cloud-sql"
  network       = google_compute_network.wakapi_unmanaged_net.id
  psc_config {
    subnetworks = [
      google_compute_subnetwork.unmanaged_instances.id,
    ]
  }
}

resource "google_compute_subnetwork" "unmanaged_db" {
  name          = "unmanaged-db"
  ip_cidr_range = "10.69.20.0/24"
  network       = google_compute_network.wakapi_unmanaged_net.id
}

resource "google_compute_address" "unmanaged_db" {
  name         = "unmanaged-db"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.unmanaged_db.id
  address      = "10.69.20.2"
}

resource "google_compute_forwarding_rule" "unmanaged_db_rule" {
  name                    = "unmanaged-db-rule"
  network                 = google_compute_network.wakapi_unmanaged_net.id
  ip_address              = google_compute_address.unmanaged_db.self_link
  load_balancing_scheme   = ""
  target                  = google_sql_database_instance.wakapi_db.psc_service_attachment_link
  allow_psc_global_access = false
}

# managed net

resource "google_compute_network" "wakapi_managed_net" {
  name                    = "wakapi-managed-net"
  auto_create_subnetworks = false
}

resource "google_compute_network_peering" "wakapi_managed_default_peering" {
  name         = "wakapi-managed-default-peering"
  network      = google_compute_network.wakapi_managed_net.id
  peer_network = google_compute_network.default.id
}

resource "google_compute_network_peering" "wakapi_managed_unmanaged_peering" {
  name         = "wakapi-managed-managed-peering"
  network      = google_compute_network.wakapi_managed_net.id
  peer_network = google_compute_network.wakapi_unmanaged_net.id
}

resource "google_compute_network_peering" "wakapi_managed_proxy_peering" {
  name         = "wakapi-managed-proxy-peering"
  network      = google_compute_network.wakapi_managed_net.id
  peer_network = google_compute_network.wakapi_proxy_net.id
}

resource "google_compute_subnetwork" "managed_instances" {
  name          = "managed-instances"
  ip_cidr_range = "10.69.11.0/24"
  network       = google_compute_network.wakapi_managed_net.id
}

resource "google_compute_firewall" "managed_allow_internet_ssh" {
  name    = "wakapi-allow-internet-ssh"
  network = google_compute_network.wakapi_managed_net.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

resource "google_compute_firewall" "managed_allow_internal_icmp" {
  name    = "wakapi-managed-allow-internal-icmp"
  network = google_compute_network.wakapi_managed_net.id

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    google_compute_subnetwork.unmanaged_instances.ip_cidr_range,
    google_compute_subnetwork.managed_instances.ip_cidr_range,
    google_compute_subnetwork.lb_proxy.ip_cidr_range,
  ]
  target_tags = ["allow-internal-icmp"]
}

resource "google_compute_firewall" "managed_allow_http_from_proxy" {
  name    = "wakapi-managed-allow-http-from-proxy"
  network = google_compute_network.wakapi_managed_net.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [google_compute_subnetwork.lb_proxy.ip_cidr_range]
  target_tags   = ["allow-http-from-proxy"]
}

resource "google_compute_firewall" "managed_allow_health_checks" {
  name    = "wakapi-managed-allow-health-checks"
  network = google_compute_network.wakapi_managed_net.id

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["allow-health-checks"]
}

resource "google_network_connectivity_service_connection_policy" "managed_db" {
  name          = "managed-connectivity-policy"
  location      = var.region
  service_class = "google-cloud-sql"
  network       = google_compute_network.wakapi_managed_net.id
  psc_config {
    subnetworks = [
      google_compute_subnetwork.managed_instances.id,
    ]
  }
}

resource "google_compute_subnetwork" "managed_db" {
  name          = "managed-db"
  ip_cidr_range = "10.69.21.0/24"
  network       = google_compute_network.wakapi_managed_net.id
}

resource "google_compute_address" "managed_db" {
  name         = "managed-db"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.managed_db.id
  address      = "10.69.21.2"
}

resource "google_compute_forwarding_rule" "managed_db_rule" {
  name                    = "managed-db-rule"
  network                 = google_compute_network.wakapi_managed_net.id
  ip_address              = google_compute_address.managed_db.self_link
  load_balancing_scheme   = ""
  target                  = google_sql_database_instance.wakapi_db.psc_service_attachment_link
  allow_psc_global_access = false
}

# proxy net

resource "google_compute_network" "wakapi_proxy_net" {
  name                    = "wakapi-proxy-net"
  auto_create_subnetworks = false
}

resource "google_compute_network_peering" "wakapi_proxy_default_peering" {
  name         = "wakapi-proxy-default-peering"
  network      = google_compute_network.wakapi_proxy_net.id
  peer_network = google_compute_network.default.id
}

resource "google_compute_network_peering" "wakapi_proxy_unmanaged_peering" {
  name         = "wakapi-proxy-unmanaged-peering"
  network      = google_compute_network.wakapi_proxy_net.id
  peer_network = google_compute_network.wakapi_unmanaged_net.id
}

resource "google_compute_network_peering" "wakapi_proxy_managed_peering" {
  name         = "wakapi-proxy-managed-peering"
  network      = google_compute_network.wakapi_proxy_net.id
  peer_network = google_compute_network.wakapi_managed_net.id
}

resource "google_compute_subnetwork" "lb_proxy" {
  name          = "wakapi-managed-subnet-lb-proxy"
  ip_cidr_range = "10.69.1.0/24"
  network       = google_compute_network.wakapi_proxy_net.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# default network peering

import {
  id = "default"
  to = google_compute_network.default
}

resource "google_compute_network" "default" {
  name        = "default"
  description = "Default network for the project"
}

resource "google_compute_network_peering" "default_wakapi_managed_peering" {
  name         = "default-wakapi-managed-peering"
  network      = google_compute_network.default.id
  peer_network = google_compute_network.wakapi_managed_net.id
}

resource "google_compute_network_peering" "default_wakapi_unmanaged_peering" {
  name         = "default-wakapi-unmanaged-peering"
  network      = google_compute_network.default.id
  peer_network = google_compute_network.wakapi_unmanaged_net.id
}

resource "google_compute_network_peering" "default_wakapi_proxy_peering" {
  name         = "default-wakapi-proxy-peering"
  network      = google_compute_network.default.id
  peer_network = google_compute_network.wakapi_proxy_net.id
}