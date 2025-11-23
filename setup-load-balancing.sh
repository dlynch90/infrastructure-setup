#!/bin/bash

# Cloudflare Load Balancing Setup for Global Distribution
# This script configures load balancing pools and monitors for your application

set -e

echo "Setting up Cloudflare Load Balancing for global scaling..."

# Load Balancing Pool Configuration
# These would be configured in the Cloudflare dashboard, but here's the structure:

cat > load-balancing-config.json << 'EOF'
{
  "pools": [
    {
      "name": "ai-worker-pool-us-east",
      "origins": [
        {
          "name": "worker-1-us-east",
          "address": "ai-worker-1.yourdomain.com",
          "weight": 1,
          "header": {
            "Host": ["ai-worker-1.yourdomain.com"]
          }
        },
        {
          "name": "worker-2-us-east",
          "address": "ai-worker-2.yourdomain.com",
          "weight": 1,
          "header": {
            "Host": ["ai-worker-2.yourdomain.com"]
          }
        }
      ],
      "latitude": 39.0438,
      "longitude": -77.4874,
      "load_shedding": {
        "default_percent": 0,
        "default_policy": "random",
        "session_percent": 0,
        "session_policy": "hash"
      },
      "notification_email": "admin@yourdomain.com",
      "origin_steering": {
        "policy": "random"
      }
    },
    {
      "name": "ai-worker-pool-eu-west",
      "origins": [
        {
          "name": "worker-1-eu-west",
          "address": "ai-worker-eu-1.yourdomain.com",
          "weight": 1
        }
      ],
      "latitude": 50.1109,
      "longitude": 8.6821
    }
  ],
  "monitors": [
    {
      "expected_codes": "200",
      "method": "GET",
      "timeout": 5,
      "path": "/health",
      "interval": 60,
      "retries": 2,
      "follow_redirects": true,
      "expected_body": "healthy",
      "header": {
        "Host": ["yourdomain.com"],
        "User-Agent": ["Cloudflare Load Balancer"]
      },
      "allow_insecure": false,
      "consecutive_up": 1,
      "consecutive_down": 3
    }
  ],
  "load_balancers": [
    {
      "name": "ai-platform-lb",
      "fallback_pool": "ai-worker-pool-us-east",
      "default_pools": [
        "ai-worker-pool-us-east",
        "ai-worker-pool-eu-west"
      ],
      "description": "Global load balancer for AI platform",
      "ttl": 30,
      "steering_policy": "geo",
      "proxied": true,
      "session_affinity": "cookie",
      "session_affinity_attributes": {
        "samesite": "Auto",
        "secure": "Auto",
        "drain_duration": 100
      },
      "rules": [
        {
          "name": "EU Traffic to EU Pool",
          "condition": "(ip.geoip.country eq \"GB\") or (ip.geoip.country eq \"DE\") or (ip.geoip.country eq \"FR\")",
          "overrides": {
            "default_pools": ["ai-worker-pool-eu-west"],
            "fallback_pool": "ai-worker-pool-eu-west"
          }
        },
        {
          "name": "High Load Shedding",
          "condition": "http.request.uri.path contains \"/api/ai/generate\"",
          "overrides": {
            "load_shedding": {
              "default_percent": 50,
              "default_policy": "random"
            }
          }
        }
      ]
    }
  ]
}
EOF

echo "Load balancing configuration template created."
echo ""
echo "Dashboard Setup Steps:"
echo "1. Go to Cloudflare Dashboard > Traffic > Load Balancing"
echo "2. Create monitors for health checks"
echo "3. Create origin pools for your worker instances"
echo "4. Create load balancer with geo-based routing"
echo "5. Configure session affinity for AI conversations"
echo "6. Set up custom rules for traffic steering"
echo ""
echo "For production scaling:"
echo "- Deploy workers across multiple regions (US, EU, Asia)"
echo "- Use health checks to automatically route around failures"
echo "- Implement geo-steering for latency optimization"
echo "- Configure session affinity for stateful AI conversations"