variable "cloudflare_api_token" {
  description = "Cloudflare API token with necessary permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "enable_pages" {
  description = "Enable Cloudflare Pages deployment"
  type        = bool
  default     = false
}

variable "environments" {
  description = "Configuration for each environment"
  type = map(object({
    d1_databases = optional(list(object({
      name = string
      size = optional(string, "10GB")
    })), [])

    kv_namespaces = optional(list(object({
      name = string
      size = optional(string, "10GB")
    })), [])

    r2_buckets = optional(list(object({
      name = string
    })), [])

    vectorize_indexes = optional(list(object({
      name     = string
      dimension = number
      metric   = optional(string, "cosine")
    })), [])

    queues = optional(list(object({
      name = string
    })), [])
  }))

  default = {
    development = {
      d1_databases = [{
        name = "agency-ai-sessions-dev"
      }]
      kv_namespaces = [{
        name = "agency-ai-cache-dev"
      }]
      r2_buckets = [{
        name = "agency-generated-content-dev"
      }]
      vectorize_indexes = [{
        name      = "agency-knowledge-base-dev"
        dimension = 768
      }]
      queues = [{
        name = "agency-ai-jobs-dev"
      }]
    }

    staging = {
      d1_databases = [{
        name = "agency-ai-sessions-staging"
      }]
      kv_namespaces = [{
        name = "agency-ai-cache-staging"
      }]
      r2_buckets = [{
        name = "agency-generated-content-staging"
      }]
      vectorize_indexes = [{
        name      = "agency-knowledge-base-staging"
        dimension = 768
      }]
      queues = [{
        name = "agency-ai-jobs-staging"
      }]
    }

    production = {
      d1_databases = [{
        name = "agency-ai-sessions-prod"
      }]
      kv_namespaces = [{
        name = "agency-ai-cache-prod"
      }]
      r2_buckets = [{
        name = "agency-generated-content-prod"
      }]
      vectorize_indexes = [{
        name      = "agency-knowledge-base-prod"
        dimension = 768
      }]
      queues = [{
        name = "agency-ai-jobs-prod"
      }]
    }
  }
}

variable "pages_config" {
  description = "Cloudflare Pages configuration"
  type = object({
    name         = string
    source_dir   = optional(string, "dist")
    build_command = optional(string, "npm run build")
    destination_dir = optional(string, "dist")
  })

  default = {
    name = "ai-platform-frontend"
  }
}

variable "access_policies" {
  description = "Zero Trust access policies"
  type = map(object({
    name = string
    include = list(object({
      email = optional(list(string))
      group = optional(list(string))
      device_posture = optional(list(string))
      ip = optional(list(string))
    }))
    require = optional(list(object({
      authentication_method = optional(list(string))
      device_posture = optional(list(string))
      ip = optional(list(string))
    })), [])
  }))

  default = {
    developers = {
      name = "Developer Access"
      include = [{
        group = ["developers"]
      }]
      require = [{
        authentication_method = ["saml"]
        device_posture = ["compliant"]
      }]
    }

    staging = {
      name = "Staging Access"
      include = [{
        group = ["developers", "qa"]
      }]
      require = [{
        authentication_method = ["saml"]
      }]
    }

    production = {
      name = "Production Access"
      include = [{
        group = ["admins"]
      }]
      require = [{
        authentication_method = ["saml", "mfa"]
      }]
    }
  }
}