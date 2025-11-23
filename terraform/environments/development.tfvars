cloudflare_api_token = "your-development-api-token"
cloudflare_account_id = "your-account-id"
enable_pages = false

# Development environment configuration
environments = {
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
}

access_policies = {
  developers = {
    name = "Development Access"
    include = [{
      email = ["developer@empathyfirstmedia.com"]
    }]
    require = [{
      authentication_method = ["saml"]
    }]
  }
}