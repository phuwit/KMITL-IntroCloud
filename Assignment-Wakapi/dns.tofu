# dns

resource "cloudflare_dns_record" "wakapi_subdomain" {
  zone_id = var.cloudflare_zone_id
  name    = var.wakapi_subdomain
  content = google_compute_address.wakapi_https_ip.address
  type    = "A"
  ttl     = 1
  proxied = true
}