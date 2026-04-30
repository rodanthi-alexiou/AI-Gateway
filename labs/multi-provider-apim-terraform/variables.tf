variable "resource_group_name" {
  type    = string
  default = "lab-multi-provider-apim-terraform"
}

variable "resource_group_location" {
  type    = string
  default = "swedencentral"
}

# ---------------------------------------------------------------------------
# OpenAI backend pool: two Foundry instances with priority-based failover
# ---------------------------------------------------------------------------
variable "openai_backends_config" {
  description = "Map of AI Foundry instances for the OpenAI backend pool. Priority 1 = primary, Priority 2 = fallback."
  default = {
    foundry-swc = {
      name     = "foundry-openai-swc"
      location = "swedencentral"
      priority = 1
      weight   = 100
    }
    foundry-eus2 = {
      name     = "foundry-openai-eus2"
      location = "eastus2"
      priority = 2
      weight   = 100
    }
  }
}

# ---------------------------------------------------------------------------
# OpenAI model deployed on every Foundry instance in the backend pool
# ---------------------------------------------------------------------------
variable "openai_model_deployment_name" {
  type    = string
  default = "gpt-4.1-mini"
}

variable "openai_model_name" {
  type    = string
  default = "gpt-4.1-mini"
}

variable "openai_model_version" {
  type    = string
  default = "2025-04-14"
}

variable "openai_model_capacity" {
  type    = number
  default = 20
}

variable "openai_api_spec_url" {
  type    = string
  default = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}

variable "openai_api_version" {
  type    = string
  default = "2024-10-21"
}

# ---------------------------------------------------------------------------
# Anthropic Claude 3.5 Haiku – serverless Marketplace endpoint
# Deployed on the primary (swedencentral) Foundry instance
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Enable or disable Anthropic deployment
# ---------------------------------------------------------------------------
variable "enable_anthropic" {
  description = "Enable Anthropic Claude deployment (set to false if not available in your subscription)"
  type        = bool
  default     = false
}

variable "anthropic_foundry_name" {
  type    = string
  default = "foundry-anthropic-swc"
}

variable "anthropic_foundry_location" {
  type    = string
  default = "swedencentral"
}

variable "anthropic_model_deployment_name" {
  type    = string
  default = "claude-3-5-haiku"
}

variable "anthropic_model_name" {
  type    = string
  default = "claude-3-5-haiku-20241022"
}

variable "anthropic_model_capacity" {
  type    = number
  default = 1
}

variable "anthropic_provider_industry" {
  description = "Industry for Anthropic model provider agreement (e.g. Technology, Healthcare, Finance)"
  type        = string
  default     = "Technology"
}

variable "anthropic_provider_org_name" {
  description = "Organization name for Anthropic model provider agreement"
  type        = string
  default     = "My Organization"
}

variable "anthropic_provider_country_code" {
  description = "Two-letter ISO country code for Anthropic model provider agreement (e.g. US, GB, DE)"
  type        = string
  default     = "US"
}

# ---------------------------------------------------------------------------
# APIM
# ---------------------------------------------------------------------------
variable "apim_resource_name" {
  type    = string
  default = "apim"
}

variable "apim_sku" {
  type        = string
  default     = "BasicV2_1"
  description = "APIM SKU. BasicV2 supports most regions including swedencentral."
}
