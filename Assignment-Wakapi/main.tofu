terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=7.20.0"
    }
  }
}

provider "google" {
  project = "alright4258"
  region  = "asia-southeast1"
}

resource "google_compute_network" "wakapi-net" {
  name                    = "wakapi-net"
  auto_create_subnetworks = false
}

module "peering1" {
  source        = "terraform-google-modules/network/google//modules/network-peering"
  version       = ">= 13.1.0"
  local_network = google_compute_network.wakapi-net.id
  peer_network  = "projects/alright4258/global/networks/default"
}

# resource "google_compute_subnetwork" "subnet-unmanaged-instances" {
#   name          = "wakapi-subnet-unmanaged-instances"
#   ip_cidr_range = "10.69.1.0/24"
#   network       = google_compute_network.wakapi-net.id
# }

# resource "google_compute_subnetwork" "subnet-managed-instances" {
#   name          = "wakapi-subnet-managed-instances"
#   ip_cidr_range = "10.69.2.0/24"
#   network       = google_compute_network.wakapi-net.id
# }

resource "google_compute_subnetwork" "subnet-instances" {
  name          = "wakapi-subnet-instances"
  ip_cidr_range = "10.69.2.0/24"
  network       = google_compute_network.wakapi-net.id
}

resource "google_compute_subnetwork" "subnet-databases" {
  name          = "wakapi-subnet-databases"
  ip_cidr_range = "10.69.0.0/24"
  network       = google_compute_network.wakapi-net.id
}

resource "google_compute_firewall" "allow-http-https" {
  name    = "allow-http-https"
  network = google_compute_network.wakapi-net.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-http-https"]
}

resource "google_compute_firewall" "allow-ssh" {
  name    = "allow-ssh"
  network = google_compute_network.wakapi-net.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

resource "google_compute_network_endpoint_group" "neg" {
  name         = "wakapi-neg"
  network      = google_compute_network.wakapi-net.id
  subnetwork   = google_compute_subnetwork.subnet-instances.id
  default_port = "80"
  zone         = "asia-southeast1-a"
}


resource "google_storage_bucket" "scripts" {
  name          = "alright4258-scripts"
  location      = "ASIA-SOUTHEAST1"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "startup-wakapi" {
  name = "startup-wakapi.sh"
  # Use `source` or `content`
  source = "./startup-wakapi.sh"
  # content      = "Data as string to be uploaded"
  content_type = "text/plain"
  bucket       = google_storage_bucket.scripts.id
}

resource "google_compute_instance_template" "wakapi-template" {
  name         = "wakapi-template"
  machine_type = "e2-medium"
  tags         = [google_compute_firewall.allow-ssh.name, google_compute_firewall.allow-http-https.name]

  disk {
    source_image = "debian-cloud/debian-13"
  }

  network_interface {
    network    = google_compute_network.wakapi-net.id
    subnetwork = google_compute_subnetwork.subnet-instances.id
    access_config {
    }
  }

  metadata_startup_script = "${google_storage_bucket.scripts.url}/${google_storage_bucket_object.startup-wakapi.name}"
}

resource "google_compute_instance_from_template" "wakapi-unmanaged-instance" {
  name                     = "wakapi-unmanaged-instance"
  source_instance_template = google_compute_instance_template.wakapi-template.self_link_unique
  zone                     = "asia-southeast1-a"

  network_interface {
    network    = google_compute_network.wakapi-net.id
    subnetwork = google_compute_subnetwork.subnet-instances.id
    network_ip = "10.69.1.2"
    access_config {
    }
  }
}

resource "google_compute_region_autoscaler" "wakapi-autoscaler" {
  name   = "wakapi-autoscaler"
  target = google_compute_region_instance_group_manager.wakapi-igm.id

  autoscaling_policy {
    max_replicas    = 2
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.95
    }
  }
}

resource "google_compute_target_pool" "wakapi-pool" {
  name      = "wakapi-pool"
  instances = ["${google_compute_instance_from_template.wakapi-unmanaged-instance.zone}/${google_compute_instance_from_template.wakapi-unmanaged-instance.name}"]
}

resource "google_compute_region_instance_group_manager" "wakapi-igm" {
  name = "wakapi-igm"

  version {
    instance_template = google_compute_instance_template.wakapi-template.id
    name              = "primary"
  }

  target_pools       = [google_compute_target_pool.wakapi-pool.id]
  base_instance_name = "wakapi-igm"
}