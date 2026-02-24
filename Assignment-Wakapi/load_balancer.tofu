# load balancer

resource "google_compute_region_health_check" "http_health_check" {
  name = "http-health-check"

  http_health_check {
    port = 80
  }
}

resource "google_compute_region_backend_service" "wakapi_backend" {
  name                  = "wakapi-backend"
  enable_cdn            = false
  health_checks         = [google_compute_region_health_check.http_health_check.id]
  load_balancing_scheme = var.lb_backend_scheme
  session_affinity      = "GENERATED_COOKIE"

  backend {
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    group           = google_compute_instance_group.wakapi_unmanaged.id
    capacity_scaler = 1.0
  }

  backend {
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    group           = google_compute_region_instance_group_manager.wakapi_mig.instance_group
    capacity_scaler = 1.0
  }

  lifecycle {
    replace_triggered_by = [google_compute_instance_template.wakapi_template]
  }

  depends_on = [
    google_compute_instance_template.wakapi_template,
    google_compute_instance_group.wakapi_unmanaged,
    google_compute_region_instance_group_manager.wakapi_mig
  ]
}

resource "google_compute_region_url_map" "wakapi_lb" {
  name            = "wakapi-http-lb"
  default_service = google_compute_region_backend_service.wakapi_backend.self_link

  lifecycle {
    replace_triggered_by = [google_compute_instance_template.wakapi_template]
  }
}

resource "google_compute_region_target_http_proxy" "wakapi_http_lb_proxy" {
  name    = "wakapi-http-lb-target-proxy"
  url_map = google_compute_region_url_map.wakapi_lb.self_link

  lifecycle {
    replace_triggered_by = [google_compute_instance_template.wakapi_template]
  }
}

resource "google_compute_forwarding_rule" "wakapi_http_ip_lb_frontend" {
  name                  = "wakapi-http-ip-lb-frontend"
  ip_protocol           = "TCP"
  load_balancing_scheme = var.lb_scheme
  network_tier          = var.lb_network_tier
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.wakapi_http_lb_proxy.self_link
  network               = google_compute_network.wakapi_proxy_net.id

  depends_on = [google_compute_subnetwork.lb_proxy]

  lifecycle {
    replace_triggered_by = [google_compute_instance_template.wakapi_template]
  }
}

resource "google_compute_region_ssl_certificate" "cloudflare_bigblahaj" {
  name_prefix = "cloudflare-bigblahaj-"
  private_key = file("../Certificates/cloudflare-bigblahaj-com.key")
  certificate = file("../Certificates/cloudflare-bigblahaj-com.pem")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_address" "wakapi_https_ip" {
  name         = "wakapi-bigblahaj-com-ip"
  network_tier = var.lb_network_tier
}

resource "google_compute_region_target_https_proxy" "wakapi_https_proxy" {
  name             = "wakapi-bigblahaj-https-proxy"
  url_map          = google_compute_region_url_map.wakapi_lb.id
  ssl_certificates = [google_compute_region_ssl_certificate.cloudflare_bigblahaj.id]

  lifecycle {
    replace_triggered_by = [google_compute_instance_template.wakapi_template]
  }
}

resource "google_compute_forwarding_rule" "wakapi_https_bigblahaj_lb_frontend" {
  name                  = "wakapi-https-bigblahaj-lb-frontend"
  ip_protocol           = "TCP"
  load_balancing_scheme = var.lb_scheme
  network_tier          = var.lb_network_tier
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.wakapi_https_proxy.id
  network               = google_compute_network.wakapi_proxy_net.id
  ip_address            = google_compute_address.wakapi_https_ip.id

  depends_on = [google_compute_subnetwork.lb_proxy]

  lifecycle {
    replace_triggered_by = [google_compute_instance_template.wakapi_template]
  }
}