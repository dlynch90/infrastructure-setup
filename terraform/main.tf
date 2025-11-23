terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "remote" {
    organization = "empathy-first-media"
    workspaces {
      name = "ai-platform"
    }
  }
}

# Cloudflare provider configuration
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Import existing resources (run `cf-terraforming` first)
# This ensures we don't accidentally delete existing resources

# Worker scripts
module "workers" {
  source = "./modules/workers"

  for_each = var.environments

  environment = each.key
  zone_id     = data.cloudflare_zone.main.id
  account_id  = var.cloudflare_account_id

  # Environment-specific configurations
  d1_databases      = each.value.d1_databases
  kv_namespaces     = each.value.kv_namespaces
  r2_buckets        = each.value.r2_buckets
  vectorize_indexes = each.value.vectorize_indexes
  queues           = each.value.queues

  depends_on = [data.cloudflare_zone.main]
}

# Cloudflare Pages (if frontend exists)
module "pages" {
  source = "./modules/pages"
  count  = var.enable_pages ? 1 : 0

  zone_id   = data.cloudflare_zone.main.id
  account_id = var.cloudflare_account_id

  # Pages configuration
  pages_config = var.pages_config
}

# Zero Trust Access policies
module "access" {
  source = "./modules/access"

  zone_id   = data.cloudflare_zone.main.id
  account_id = var.cloudflare_account_id

  # Access policies for each environment
  access_policies = var.access_policies
}

# DNS records
resource "cloudflare_record" "api" {
  for_each = var.environments

  zone_id = data.cloudflare_zone.main.id
  name    = each.key == "production" ? "api" : "api.${each.key}"
  value   = cloudflare_worker_script.main[each.key].id
  type    = "CNAME"
  proxied = true
}

# SSL/TLS settings
resource "cloudflare_zone_settings_override" "main" {
  zone_id = data.cloudflare_zone.main.id

  settings {
    ssl                      = "strict"
    always_use_https        = "on"
    min_tls_version         = "1.2"
    opportunistic_encryption = "on"
    automatic_https_rewrites = "on"
    security_level          = "medium"
  }
}

# Rate limiting
resource "cloudflare_rate_limit" "api" {
  zone_id = data.cloudflare_zone.main.id

  threshold = 100
  period    = 60
  match {
    request {
      url_pattern = "*.empathyfirstmedia.com/api/*"
      schemes     = ["HTTPS"]
      methods     = ["GET", "POST", "PUT", "DELETE"]
    }
  }

  action {
    mode    = "simulate"
    timeout = 60
  }

  correlate {
    by = "nat"
  }
}

# WAF rules
resource "cloudflare_firewall_rule" "block_bad_bots" {
  zone_id = data.cloudflare_zone.main.id

  filter_id = cloudflare_filter.block_bad_bots.id
  action    = "block"
}

resource "cloudflare_filter" "block_bad_bots" {
  zone_id = data.cloudflare_zone.main.id

  expression = "(cf.client.bot) and (cf.bot_management.score lt 30)"
  paused     = false
}

# Data source for existing zone
data "cloudflare_zone" "main" {
  name = "empathyfirstmedia.com"
}

# Outputs
output "worker_urls" {
  description = "Worker deployment URLs"
  value = {
    for env, worker in cloudflare_worker_script.main :
    env => "https://${env == "production" ? "" : "${env}."}api.empathyfirstmedia.com"
  }
}

output "zone_id" {
  description = "Cloudflare zone ID"
  value       = data.cloudflare_zone.main.id
}