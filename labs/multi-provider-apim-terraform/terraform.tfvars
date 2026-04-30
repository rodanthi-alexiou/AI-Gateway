resource_group_name          = "lab-multi-provider-apim-terraform"
resource_group_location      = "swedencentral"
apim_sku                     = "BasicV2_1"
openai_model_deployment_name = "gpt-4.1-mini"
openai_model_name            = "gpt-4.1-mini"
openai_model_version         = "2025-04-14"
openai_model_capacity        = 1
openai_api_version           = "2024-10-21"
anthropic_foundry_name           = "foundry-anthropic-swc"
anthropic_foundry_location       = "swedencentral"
anthropic_model_deployment_name  = "claude-3-5-haiku"
anthropic_model_name             = "claude-3-5-haiku-20241022"
anthropic_model_capacity         = 1
enable_anthropic                 = false
openai_backends_config           = {
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

