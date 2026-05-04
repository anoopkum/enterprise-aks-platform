# Governance Module - Azure Cost Management Budgets
#
# This file creates budget alerts at 50%, 75%, and 90% thresholds.

#------------------------------------------------------------------------------
# Local Values
#------------------------------------------------------------------------------

locals {
  # Calculate budget start date (first day of current month if not specified)
  budget_start_date = var.budget_start_date != null ? var.budget_start_date : formatdate("YYYY-MM-01", timestamp())
}

#------------------------------------------------------------------------------
# Consumption Budget
#------------------------------------------------------------------------------

resource "azurerm_consumption_budget_subscription" "main" {
  count = var.enable_budget_alerts && length(var.budget_alert_emails) > 0 ? 1 : 0

  name            = "monthly-budget"
  subscription_id = "/subscriptions/${var.subscription_id}"

  amount     = var.monthly_budget
  time_grain = "Monthly"

  time_period {
    start_date = "${local.budget_start_date}T00:00:00Z"
  }

  # 50% threshold notification
  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = var.budget_alert_emails
  }

  # 75% threshold notification
  notification {
    enabled        = true
    threshold      = 75
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = var.budget_alert_emails
  }

  # 90% threshold notification
  notification {
    enabled        = true
    threshold      = 90
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = var.budget_alert_emails
  }

  # 100% forecasted notification
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = var.budget_alert_emails
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to start date after creation
      time_period[0].start_date,
    ]
  }
}
