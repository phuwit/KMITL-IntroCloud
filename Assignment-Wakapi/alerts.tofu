# alerts

resource "google_monitoring_notification_channel" "notification_email" {
  display_name = "Wakapi Email Notification Channel"
  type         = "email"
  labels = {
    email_address = var.alert_email_address
  }
}

resource "google_monitoring_alert_policy" "wakapi_cpu_alert" {
  display_name = "Wakapi Instances CPU Load (1m) > ${var.alert_cpu_usage_percent_fraction_gt}"
  documentation {
    content = "The $${metric.display_name} of the $${resource.type} in $${resource.project} has exceeded ${var.alert_cpu_usage_percent_fraction_gt} for over 1 minute."
  }
  combiner = "OR"
  conditions {
    display_name = "CPU Load (1m)"
    condition_threshold {
      comparison      = "COMPARISON_GT"
      duration        = "60s"
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/cpu/load_1m\""
      threshold_value = var.alert_cpu_usage_percent_fraction_gt
      aggregations {
        alignment_period     = "60s"
        cross_series_reducer = "REDUCE_MEAN"
        per_series_aligner   = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.notification_email.name]

  user_labels = {
    severity = "warning"
  }
  severity = "WARNING"
}
