---
name: "Multi-Provider APIM Gateway (Terraform)"
architectureDiagram: images/multi-provider-apim-terraform.gif
categories:
  - Platform Capabilities
services:
  - Azure AI Foundry
  - Azure OpenAI
  - Anthropic Claude
shortDescription: Place Azure AI Foundry behind APIM with OpenAI and Anthropic support using Terraform IaC.
detailedDescription: Demonstrates how to place Azure AI Foundry behind Azure API Management for high availability and unified multi-provider access. Deploys two Foundry instances for gpt-4.1-mini with priority-based failover (Sweden Central → East US 2), adds Anthropic Claude 3.5 Haiku via Foundry Marketplace, and wires up circuit breakers, retry policies, and built-in LLM token logging — all using Terraform (azurerm + azapi providers).
tags: []
authors:
  - ralexiou
---

# APIM ❤️ Microsoft Foundry

## [Multi-Provider APIM Gateway lab](multi-provider-apim-terraform.ipynb) (with Terraform)

[![flow](../../images/multi-provider-apim-terraform.gif)](multi-provider-apim-terraform.ipynb)

Demonstrates how to place **Azure AI Foundry** behind **Azure API Management** for high availability, priority-based load balancing, and unified access to **both OpenAI and Anthropic Claude** models — using **Terraform** as infrastructure-as-code.

**This lab was designed for customers who need:**
- A single APIM gateway in front of existing Foundry instances (HA / load balancing)
- Support for OpenAI *and* Anthropic models under the same Foundry resource
- A fully reproducible Terraform deployment with no manual steps

### Architecture

```
                           ┌──────────────────────────────────────┐
                           │         Azure API Management         │
                           │                                       │
  Client ──────────────▶  │  /openai  ──▶ Backend Pool           │
  (api-key auth)           │               ├─ Foundry SWC (pri 1) │
                           │               └─ Foundry EUS2 (pri 2) │
                           │                                       │
                           │  /anthropic ──▶ Foundry SWC          │
                           │               └─ Claude 3.5 Haiku     │
                           └──────────────────────────────────────┘
```

### Key capabilities

| Feature | Detail |
|---------|--------|
| **Priority failover** | Sweden Central (priority 1) → East US 2 (priority 2); automatic, transparent to callers |
| **Circuit breaker** | Trips on HTTP 429 for 60 s per backend; respects `Retry-After` header |
| **Retry policy** | APIM retries up to 3× on 429/503 before returning an error |
| **Anthropic Claude** | Claude 3.5 Haiku via Foundry Marketplace under `/anthropic` path |
| **LLM token logging** | `azure-openai-emit-token-metric` for OpenAI; `emit-metric` for Anthropic → Application Insights |
| **Managed identity auth** | APIM → Foundry using system-assigned identity (no keys stored) |
| **Terraform IaC** | `azurerm` ≥ 4.36.0 + `azapi` ≥ 2.3.0; all resources in `main.tf` |

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [Python environment](https://code.visualstudio.com/docs/python/environments#_creating-environments) with the [requirements.txt](../../../requirements.txt) or run `pip install -r requirements.txt` in your terminal
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)
- [Terraform CLI](https://developer.hashicorp.com/terraform/install) installed
- Anthropic model access enabled in your Azure subscription ([request access](https://aka.ms/oai/access))

### 🚀 Get started

Proceed by opening the [Jupyter notebook](multi-provider-apim-terraform.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
