variable "environment" {
  description = "Environment name (development/staging/production)"
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

variable "d1_databases" {
  description = "D1 databases configuration"
  type = list(object({
    name = string
    size = optional(string, "10GB")
  }))
  default = []
}

variable "kv_namespaces" {
  description = "KV namespaces configuration"
  type = list(object({
    name = string
    size = optional(string, "10GB")
  }))
  default = []
}

variable "r2_buckets" {
  description = "R2 buckets configuration"
  type = list(object({
    name = string
  }))
  default = []
}

variable "vectorize_indexes" {
  description = "Vectorize indexes configuration"
  type = list(object({
    name      = string
    dimension = number
    metric    = optional(string, "cosine")
  }))
  default = []
}

variable "queues" {
  description = "Queues configuration"
  type = list(object({
    name = string
  }))
  default = []
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
}