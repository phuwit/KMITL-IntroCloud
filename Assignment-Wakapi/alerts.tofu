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
