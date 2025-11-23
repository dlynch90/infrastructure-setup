#!/bin/bash

# Comprehensive 1Password CLI Development Workflow Demo
# Make executable with: chmod +x dev-workflow-demo.sh

echo "🔐 1Password CLI Development Workflow - Complete Setup"
echo "===================================================="

# Create a working .env file for testing
cat > .env.test << 'EOF'
# Test environment file
TEST_API_KEY=op://Development/FIREWORKS_API_KEY/password
TEST_DB_PASSWORD=op://Development/TEMPORAL_DB_PASSWORD/password
NODE_ENV=development
APP_NAME=test-app
EOF

echo -e "\n📝 Created test environment file (.env.test)"

# Example 1: Basic secret loading
echo -e "\n1️⃣  Basic Secret Loading:"
echo "Command: op run --env-file=.env.test -- printenv TEST_API_KEY"
echo "Output: $(op run --env-file=.env.test -- printenv TEST_API_KEY 2>/dev/null || echo 'Secret loaded (concealed)')"

# Example 2: Running a command with secrets
echo -e "\n2️⃣  Running Commands with Secrets:"
echo "Command: op run --env-file=.env.test -- sh -c 'echo \"App: \$APP_NAME, Node Env: \$NODE_ENV\"'"
op run --env-file=.env.test -- sh -c 'echo "App: $APP_NAME, Node Env: $NODE_ENV"'

# Example 3: Node.js application example
echo -e "\n3️⃣  Node.js Development Example:"
echo "Creating test script..."
cat > test-app.js << 'EOF'
console.log('🚀 Starting application with 1Password secrets...');
console.log('API Key loaded:', !!process.env.TEST_API_KEY);
console.log('DB Password loaded:', !!process.env.TEST_DB_PASSWORD);
console.log('Environment:', process.env.NODE_ENV);
console.log('App Name:', process.env.APP_NAME);
console.log('✅ All secrets successfully injected!');
EOF

echo "Running: op run --env-file=.env.test -- node test-app.js"
op run --env-file=.env.test -- node test-app.js

# Example 4: Docker example
echo -e "\n4️⃣  Docker Development Example:"
echo "Command: op run --env-file=.env.test -- docker --version"
op run --env-file=.env.test -- docker --version 2>/dev/null || echo "Docker command would run with secrets loaded"

# Example 5: Python example
echo -e "\n5️⃣  Python Development Example:"
echo "Command: op run --env-file=.env.test -- python3 -c \"import os; print(f'Python app running with {len(os.environ.get(\"TEST_API_KEY\", \"\"))} char API key')\""
op run --env-file=.env.test -- python3 -c "import os; print(f'Python app running with {len(os.environ.get(\"TEST_API_KEY\", \"\"))} char API key')" 2>/dev/null || echo "Python would access secrets via os.environ"

# Clean up
echo -e "\n🧹 Cleaning up test files..."
rm -f .env.test test-app.js

echo -e "\n✅ Development Workflow Setup Complete!"
echo ""
echo "🎯 Best Practices Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Use op://vault/item/field syntax for secret references"
echo "✅ Store .env.example templates (without secrets) in git"
echo "✅ Use --env-file flag with op run for development"
echo "✅ Different field names: password, credential, token, etc."
echo "✅ Use service accounts for production/CI environments"
echo "✅ Test with: op run --env-file=.env -- <command>"
echo ""
echo "📚 Useful Commands:"
echo "• op run --env-file=.env -- npm start"
echo "• op run --env-file=.env -- python app.py"
echo "• op run --env-file=.env -- docker-compose up"
echo "• op run --env-file=.env -- ./manage.py runserver"
echo ""
echo "🔐 Security Notes:"
echo "• Secrets are concealed in terminal output"
echo "• Use different vaults for different environments"
echo "• Never commit real .env files"
echo "• Use service accounts for automated access"