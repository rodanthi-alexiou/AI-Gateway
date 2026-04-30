# ============================================================================
# RANDOM SUFFIX — appended to every resource name for uniqueness
# ============================================================================
resource "random_string" "random" {
  length  = 8
  lower   = true
  upper   = false
  special = false
}

# ============================================================================
# RESOURCE GROUP
# ============================================================================
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

data "azurerm_client_config" "current" {}

# ============================================================================
# LOG ANALYTICS + APPLICATION INSIGHTS
# ============================================================================
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${random_string.random.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appinsights" {
  name                = "appinsights-${random_string.random.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
}

# ============================================================================
# AZURE API MANAGEMENT
# ============================================================================
resource "azurerm_api_management" "apim" {
  name                          = "${var.apim_resource_name}-${random_string.random.result}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  publisher_name                = "My Company"
  publisher_email               = "noreply@microsoft.com"
  sku_name                      = var.apim_sku
  virtual_network_type          = "None"
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

# Wire Application Insights into APIM logger
resource "azurerm_api_management_logger" "appinsights_logger" {
  name                = "appinsights-logger"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  application_insights {
    instrumentation_key = azurerm_application_insights.appinsights.instrumentation_key
  }
}

# ============================================================================
# AI FOUNDRY — OpenAI backend pool instances (for_each over openai_backends_config)
# ============================================================================
resource "azapi_resource" "openai-ai-services" {
  for_each = var.openai_backends_config

  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  parent_id = azurerm_resource_group.rg.id
  name      = "${each.value.name}-${random_string.random.result}"
  location  = each.value.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = "${lower(each.value.name)}-${random_string.random.result}"
      disableLocalAuth       = false
      publicNetworkAccess    = "Enabled"
    }
  }
}

resource "azapi_resource" "openai-ai-project" {
  for_each = var.openai_backends_config

  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  parent_id = azapi_resource.openai-ai-services[each.key].id
  name      = "ai-project-${each.key}"
  location  = each.value.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {}
  }
}

# gpt-4.1-mini deployed to every Foundry instance in the OpenAI pool
resource "azurerm_cognitive_deployment" "gpt-4-1-mini" {
  for_each = var.openai_backends_config

  name                 = var.openai_model_deployment_name
  cognitive_account_id = azapi_resource.openai-ai-services[each.key].id

  sku {
    name     = "GlobalStandard"
    capacity = var.openai_model_capacity
  }

  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }
}

# RBAC: APIM managed identity → Cognitive Services User on each OpenAI Foundry instance
resource "azurerm_role_assignment" "openai-cognitive-services-user" {
  for_each = var.openai_backends_config

  scope                = azapi_resource.openai-ai-services[each.key].id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

# RBAC: current CLI user → Azure AI Project Manager on each OpenAI Foundry instance
resource "azurerm_role_assignment" "openai-ai-project-manager" {
  for_each = var.openai_backends_config

  scope                = azapi_resource.openai-ai-services[each.key].id
  role_definition_name = "Azure AI Project Manager"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================================================
# AI FOUNDRY — Anthropic Claude serverless endpoint (single instance)
# Only created if enable_anthropic = true
# ============================================================================
resource "azapi_resource" "anthropic-ai-services" {
  count = var.enable_anthropic ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  parent_id = azurerm_resource_group.rg.id
  name      = "${var.anthropic_foundry_name}-${random_string.random.result}"
  location  = var.anthropic_foundry_location

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = "${lower(var.anthropic_foundry_name)}-${random_string.random.result}"
      disableLocalAuth       = false
      publicNetworkAccess    = "Enabled"
    }
  }
}

resource "azapi_resource" "anthropic-ai-project" {
  count = var.enable_anthropic ? 1 : 0
  
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  parent_id = azapi_resource.anthropic-ai-services[0].id
  name      = "ai-project-anthropic"
  location  = var.anthropic_foundry_location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {}
  }
}

# Claude 3.5 Haiku serverless deployment via Marketplace
# azapi_resource is required because azurerm_cognitive_deployment does not yet
# expose modelProviderData, which Anthropic deployments require.
resource "azapi_resource" "claude-3-5-haiku" {
  count = var.enable_anthropic ? 1 : 0
  
  type                      = "Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview"
  parent_id                 = azapi_resource.anthropic-ai-services[0].id
  name                      = var.anthropic_model_deployment_name
  schema_validation_enabled = false

  body = {
    sku = {
      name     = "GlobalStandard"
      capacity = var.anthropic_model_capacity
    }
    properties = {
      model = {
        format  = "Anthropic"
        name    = var.anthropic_model_name
        version = "1"
      }
      modelProviderData = {
        industry         = var.anthropic_provider_industry
        organizationName = var.anthropic_provider_org_name
        countryCode      = var.anthropic_provider_country_code
      }
    }
  }
}

# RBAC: APIM managed identity → Cognitive Services User on Anthropic Foundry instance
resource "azurerm_role_assignment" "anthropic-cognitive-services-user" {
  count = var.enable_anthropic ? 1 : 0
  
  scope                = azapi_resource.anthropic-ai-services[0].id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

# RBAC: current CLI user → Azure AI Project Manager on Anthropic Foundry instance
resource "azurerm_role_assignment" "anthropic-ai-project-manager" {
  count = var.enable_anthropic ? 1 : 0
  
  scope                = azapi_resource.anthropic-ai-services[0].id
  role_definition_name = "Azure AI Project Manager"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================================================
# APIM BACKENDS — OpenAI individual backends with circuit breaker
# ============================================================================
resource "azapi_resource" "apim-openai-backend" {
  for_each = var.openai_backends_config

  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  parent_id = azurerm_api_management.apim.id
  name      = "backend-openai-${each.key}"

  body = {
    properties = {
      url         = "${azapi_resource.openai-ai-services[each.key].output.properties.endpoint}openai"
      protocol    = "http"
      description = "OpenAI Foundry backend — ${each.value.location}"

      circuitBreaker = {
        rules = [
          {
            failureCondition = {
              count        = 1
              errorReasons = ["Server errors"]
              interval     = "PT5M"
              statusCodeRanges = [
                {
                  min = 429
                  max = 429
                }
              ]
            }
            name             = "OpenAIBreakerRule"
            tripDuration     = "PT1M"
            acceptRetryAfter = true
          }
        ]
      }
    }
  }
}

# Priority-based backend pool for OpenAI (primary priority 1 → fallback priority 2)
resource "azapi_resource" "apim-openai-backend-pool" {
  type                      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  name                      = "apim-openai-backend-pool"
  parent_id                 = azurerm_api_management.apim.id
  schema_validation_enabled = false

  body = {
    properties = {
      description = "Priority-based OpenAI backend pool: swedencentral (primary) → eastus2 (fallback)"
      type        = "Pool"

      pool = {
        services = [
          for k, v in var.openai_backends_config : {
            id       = azapi_resource.apim-openai-backend[k].id
            priority = v.priority
            weight   = v.weight
          }
        ]
      }
    }
  }
}

# ============================================================================
# APIM BACKENDS — Anthropic backend with circuit breaker
# Only created if enable_anthropic = true
# ============================================================================
resource "azapi_resource" "apim-anthropic-backend" {
  count = var.enable_anthropic ? 1 : 0
  
  type      = "Microsoft.ApiManagement/service/backends@2024-06-01-preview"
  parent_id = azurerm_api_management.apim.id
  name      = "backend-anthropic"

  body = {
    properties = {
      url         = "${azapi_resource.anthropic-ai-services[0].output.properties.endpoint}models"
      protocol    = "http"
      description = "Anthropic Claude backend via Azure AI Foundry Marketplace"

      circuitBreaker = {
        rules = [
          {
            failureCondition = {
              count        = 1
              errorReasons = ["Server errors"]
              interval     = "PT5M"
              statusCodeRanges = [
                {
                  min = 429
                  max = 429
                }
              ]
            }
            name             = "AnthropicBreakerRule"
            tripDuration     = "PT1M"
            acceptRetryAfter = true
          }
        ]
      }
    }
  }
}

# ============================================================================
# APIM APIs
# ============================================================================

# --- OpenAI API (Azure OpenAI inference spec) ---
resource "azurerm_api_management_api" "apim-api-openai" {
  name                  = "apim-api-openai"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  description           = "Azure OpenAI Chat Completions API routed through APIM with priority-based backend pool"
  display_name          = "OpenAI"
  path                  = "openai"
  protocols             = ["https"]
  service_url           = null
  subscription_required = false
  api_type              = "http"

  import {
    content_format = "openapi-link"
    content_value  = var.openai_api_spec_url
  }

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}

# --- Anthropic API (pass-through — Anthropic Messages API format) ---
resource "azurerm_api_management_api" "apim-api-anthropic" {
  count = var.enable_anthropic ? 1 : 0
  
  name                  = "apim-api-anthropic"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  description           = "Anthropic Claude API via Azure AI Foundry Marketplace, exposed through APIM"
  display_name          = "Anthropic"
  path                  = "anthropic"
  protocols             = ["https"]
  service_url           = null
  subscription_required = false
  api_type              = "http"

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }
}

# Anthropic API — catch-all operation (pass-through to Foundry models endpoint)
resource "azurerm_api_management_api_operation" "anthropic-messages" {
  count = var.enable_anthropic ? 1 : 0
  
  operation_id        = "messages"
  api_name            = azurerm_api_management_api.apim-api-anthropic[0].name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Messages"
  method              = "POST"
  url_template        = "/{model}/chat/completions"
  description         = "Send a message to an Anthropic Claude model"

  template_parameter {
    name     = "model"
    required = true
    type     = "string"
  }

  response {
    status_code = 200
    description = "Successful response"
  }
}

# ============================================================================
# APIM POLICIES
# ============================================================================
resource "azurerm_api_management_api_policy" "openai-policy" {
  api_name            = azurerm_api_management_api.apim-api-openai.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = replace(
    replace(file("openai-policy.xml"), "{backend-id}", azapi_resource.apim-openai-backend-pool.name),
    "{logger-id}", azurerm_api_management_logger.appinsights_logger.name
  )
}

resource "azurerm_api_management_api_policy" "anthropic-policy" {
  count = var.enable_anthropic ? 1 : 0
  
  api_name            = azurerm_api_management_api.apim-api-anthropic[0].name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = replace(
    replace(file("anthropic-policy.xml"), "{backend-id}", azapi_resource.apim-anthropic-backend[0].name),
    "{logger-id}", azurerm_api_management_logger.appinsights_logger.name
  )
}

# ============================================================================
# APIM SUBSCRIPTIONS
# ============================================================================
resource "azurerm_api_management_subscription" "apim-subscription-openai" {
  display_name        = "OpenAI Subscription"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = replace(azurerm_api_management_api.apim-api-openai.id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}

resource "azurerm_api_management_subscription" "apim-subscription-anthropic" {
  count = var.enable_anthropic ? 1 : 0
  
  display_name        = "Anthropic Subscription"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = replace(azurerm_api_management_api.apim-api-anthropic[0].id, "/;rev=.*/", "")
  allow_tracing       = true
  state               = "active"
}
