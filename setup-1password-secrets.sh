#!/bin/bash

# 1Password Secret Setup Script for GCP Service Accounts
# This script documents how to securely store GCP service account keys in 1Password

echo "=== 1PASSWORD GCP SERVICE ACCOUNT SETUP ==="
echo ""
echo "🔐 SERVICE ACCOUNT KEYS TO STORE IN 1PASSWORD:"
echo ""

echo "1. AI Production Vertex SA"
echo "   - File: ai-prod-vertex-sa-key.json"
echo "   - 1Password Path: op://Development/GCP_AI_Agency/Vertex_SA_Key"
echo "   - Purpose: Vertex AI model training and predictions"
echo ""

echo "2. Data Production BigQuery SA"
echo "   - File: data-prod-bigquery-sa-key.json"
echo "   - 1Password Path: op://Development/GCP_AI_Agency/BigQuery_SA_Key"
echo "   - Purpose: BigQuery data analytics and queries"
echo ""

echo "3. Web Production Drive SA"
echo "   - File: web-prod-drive-sa-key.json"
echo "   - 1Password Path: op://Development/GCP_AI_Agency/Drive_SA_Key"
echo "   - Purpose: Google Drive file management and sharing"
echo ""

echo "4. API Production Calendar SA"
echo "   - File: api-prod-calendar-sa-key.json"
echo "   - 1Password Path: op://Development/GCP_AI_Agency/Calendar_SA_Key"
echo "   - Purpose: Google Calendar event management"
echo ""

echo "5. AI Agency Main SA (existing)"
echo "   - File: ai-agency-key.json"
echo "   - 1Password Path: op://Development/GCP_AI_Agency/Main_SA_Key"
echo "   - Purpose: General GCP resource access"
echo ""

echo ""
echo "📋 1PASSWORD STORAGE INSTRUCTIONS:"
echo "1. Create a new vault called 'GCP AI Agency' in 1Password"
echo "2. For each service account key:"
echo "   a. Create a new 'API Credential' item"
echo "   b. Set the vault to 'GCP AI Agency'"
echo "   c. Name it descriptively (e.g., 'Vertex AI Production SA')"
echo "   d. Upload the .json key file"
echo "   e. Add tags: gcp, service-account, ai-agency"
echo "   f. Add notes with purpose and permissions"
echo ""

echo "🔒 SECURITY NOTES:"
echo "- Never commit service account keys to version control"
echo "- Rotate keys every 90 days"
echo "- Use different keys for different environments"
echo "- Monitor key usage in Cloud Audit Logs"
echo ""

echo "✅ SETUP COMPLETE - Ready for 1Password integration"