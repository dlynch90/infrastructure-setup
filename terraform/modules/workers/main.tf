resource "cloudflare_worker_script" "main" {
  account_id = var.account_id
  name       = "empathy-agency-ai-${var.environment}"
  content    = file("${path.root}/../../src/index.ts")

  # D1 Databases
  dynamic "d1_database_binding" {
    for_each = var.d1_databases
    content {
      name        = "DB"
      database_id = cloudflare_d1_database.databases[d1_database_binding.key].id
    }
  }

  # KV Namespaces
  dynamic "kv_namespace_binding" {
    for_each = var.kv_namespaces
    content {
      name         = "KV_CACHE"
      namespace_id = cloudflare_kv_namespace.namespaces[kv_namespace_binding.key].id
    }
  }

  # R2 Buckets
  dynamic "r2_bucket_binding" {
    for_each = var.r2_buckets
    content {
      name       = "R2_CONTENT"
      bucket_name = cloudflare_r2_bucket.buckets[r2_bucket_binding.key].name
    }
  }

  # Vectorize Indexes
  dynamic "vectorize_binding" {
    for_each = var.vectorize_indexes
    content {
      name     = "VECTORIZE"
      index_name = cloudflare_vectorize.indexes[vectorize_binding.key].name
    }
  }

  # Queues
  dynamic "queue_binding" {
    for_each = var.queues
    content {
      name      = "AI_QUEUE"
      queue_name = cloudflare_queue.queues[queue_binding.key].name
    }
  }

  # AI Binding
  ai_binding {
    name = "AI"
  }

  # Environment variables
  plain_text_binding {
    name = "ENVIRONMENT"
    text = var.environment
  }

  # Secrets (set via wrangler secret put or terraform)
  secret_text_binding {
    name = "OPENAI_API_KEY"
    text = var.openai_api_key
  }

  secret_text_binding {
    name = "ANTHROPIC_API_KEY"
    text = var.anthropic_api_key
  }
}

# D1 Databases
resource "cloudflare_d1_database" "databases" {
  for_each   = { for idx, db in var.d1_databases : idx => db }
  account_id = var.account_id
  name       = each.value.name
}

# KV Namespaces
resource "cloudflare_kv_namespace" "namespaces" {
  for_each   = { for idx, ns in var.kv_namespaces : idx => ns }
  account_id = var.account_id
  title      = each.value.name
}

# R2 Buckets
resource "cloudflare_r2_bucket" "buckets" {
  for_each   = { for idx, bucket in var.r2_buckets : idx => bucket }
  account_id = var.account_id
  name       = each.value.name
  location   = "ENAM"  # Eastern North America
}

# Vectorize Indexes
resource "cloudflare_vectorize" "indexes" {
  for_each   = { for idx, index in var.vectorize_indexes : idx => index }
  account_id = var.account_id
  name       = each.value.name
  dimension  = each.value.dimension
  metric     = each.value.metric

  description = "AI knowledge base for ${var.environment} environment"
}

# Queues
resource "cloudflare_queue" "queues" {
  for_each   = { for idx, queue in var.queues : idx => queue }
  account_id = var.account_id
  name       = each.value.name
}