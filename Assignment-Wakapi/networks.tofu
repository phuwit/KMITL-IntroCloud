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

resource "google_compute_subnetwork" "subnet_lb_proxy" {
  name          = "wakapi-subnet-lb-proxy"
  ip_cidr_range = "10.69.2.0/24"
  network       = google_compute_network.wakapi_net.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

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

resource "google_compute_firewall" "allow_http_from_proxy" {
  name    = "allow-http-from-proxy"
  network = google_compute_network.wakapi_net.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [google_compute_subnetwork.subnet_lb_proxy.ip_cidr_range]
  target_tags   = ["allow-http-from-proxy"]
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
