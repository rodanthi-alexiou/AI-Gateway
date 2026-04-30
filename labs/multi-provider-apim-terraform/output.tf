output "apim_resource_gateway_url" {
  description = "APIM gateway URL — base URL for all API calls"
  value       = azurerm_api_management.apim.gateway_url
}

output "apim_openai_subscription_key" {
  description = "Subscription key for the OpenAI API"
  value       = azurerm_api_management_subscription.apim-subscription-openai.primary_key
  sensitive   = true
}

output "apim_anthropic_subscription_key" {
  description = "Subscription key for the Anthropic API (only if enable_anthropic = true)"
  value       = var.enable_anthropic ? azurerm_api_management_subscription.apim-subscription-anthropic[0].primary_key : "N/A - Anthropic disabled"
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace customer ID for KQL queries"
  value       = azurerm_log_analytics_workspace.law.workspace_id
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.appinsights.connection_string
  sensitive   = true
}
