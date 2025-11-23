# 🤖 Empathy First Media Agency AI Platform

A comprehensive AI-powered platform built on Cloudflare Workers, featuring multi-modal capabilities, RAG (Retrieval Augmented Generation), content generation, and enterprise-grade security.

## 🌟 Features

- **Multi-Modal AI**: Text generation, image creation, speech synthesis, and transcription
- **RAG Implementation**: Knowledge base with vector search for contextual responses
- **Enterprise Security**: Rate limiting, authentication, and compliance features
- **Real-time Streaming**: WebSocket support for real-time AI interactions
- **Scalable Architecture**: Built on Cloudflare's global network
- **Comprehensive Monitoring**: Analytics, performance metrics, and error tracking

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Wrangler CLI (`npm install -g wrangler`)
- Cloudflare account with Workers AI enabled

### Installation

1. **Clone and setup**:
   ```bash
   git clone <repository-url>
   cd empathy-agency-ai-platform
   npm install
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Deploy infrastructure**:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

### Authentication Setup

1. **Create API Token** in Cloudflare Dashboard:
   - Go to Profile → API Tokens → Create Token
   - Select "Create Custom Token"
   - Enable permissions: Workers, AI, D1, R2, KV, Queues

2. **Set environment variables**:
   ```bash
   export CLOUDFLARE_API_TOKEN="your_api_token_here"
   export CLOUDFLARE_ACCOUNT_ID="5f837f5b7ca9c06d0053bacdd2d32370"
   ```

## 📚 API Documentation

### Authentication

All API requests require Bearer token authentication:

```bash
curl -H "Authorization: Bearer your_jwt_token" \
     https://api.empathyfirstmedia.com/api/ai/chat
```

### Endpoints

#### POST `/api/ai/chat`
Real-time conversational AI with streaming support.

**Request:**
```json
{
  "messages": [
    {"role": "user", "content": "Hello, how can you help me?"}
  ],
  "model": "@cf/meta/llama-3.3-70b-instruct-fp8-fast",
  "stream": true,
  "temperature": 0.7
}
```

**Response:**
```json
{
  "response": "Hello! I can help you with content creation, research, analysis, and various AI-powered tasks...",
  "requestId": "req_12345",
  "usage": {"estimatedTokens": 25}
}
```

#### POST `/api/ai/generate`
Content generation with multiple output formats.

**Request:**
```json
{
  "prompt": "Write a blog post about AI in marketing",
  "type": "article",
  "length": "medium",
  "style": "professional",
  "model": "@cf/meta/llama-3.3-70b-instruct-fp8-fast"
}
```

#### POST `/api/ai/rag`
Knowledge base queries with retrieval augmentation.

**Request:**
```json
{
  "query": "What are the best practices for AI content generation?",
  "topK": 5
}
```

#### GET `/health`
Health check endpoint.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Client Apps   │────│  Cloudflare     │
│                 │    │   Workers       │
└─────────────────┘    └─────────────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
            ┌───────▼───┐ ┌───▼───┐ ┌───▼───┐
            │ Workers AI │ │   D1  │ │  R2   │
            │  Models    │ │Database│ │Storage│
            └───────────┘ └───────┘ └───────┘
                    │         │         │
            ┌───────▼───┐ ┌───▼───┐ ┌───▼───┐
            │ Vectorize  │ │   KV  │ │Queues │
            │   Index    │ │ Cache │ │Async  │
            └───────────┘ └───────┘ └───────┘
```

## 🔒 Security & Compliance

### Rate Limiting
- **API Requests**: 100 per minute per user
- **Token Usage**: 10,000 tokens per hour per user
- **Content Generation**: 20 requests per minute

### Authentication
- JWT-based authentication
- API token validation
- Client identification and tracking

### Data Protection
- End-to-end encryption
- GDPR compliance
- Data retention policies
- Audit logging

## 📊 Monitoring & Analytics

### Real-time Metrics
- Response times and latency
- Token usage and costs
- Error rates and types
- User engagement metrics

### Performance Monitoring
- Core Web Vitals tracking
- API performance metrics
- Error boundary reporting
- Client-side analytics

## 🛠️ Development

### Local Development
```bash
npm run dev
```

### Testing
```bash
npm test
npm run test:watch
```

### Code Quality
```bash
npm run lint
npm run format
npm run typecheck
```

### Database Management
```bash
npm run db:migrate
npm run db:seed
```

## 🚀 Deployment

### Automated Deployment
```bash
./deploy.sh
```

### Manual Deployment
```bash
wrangler deploy
```

### Environment Management
```bash
wrangler secret put CLOUDFLARE_API_TOKEN
wrangler secret put DATABASE_URL
```

## 📈 Performance Optimization

### Caching Strategy
- **KV Cache**: Frequently accessed data (24h TTL)
- **R2 Storage**: Generated content (1 year TTL)
- **D1 Queries**: Optimized with indexes

### Model Selection Guide
- **Fast Responses**: `@cf/meta/llama-3.1-8b-instruct-awq`
- **High Quality**: `@cf/meta/llama-3.3-70b-instruct-fp8-fast`
- **Creative Tasks**: `@cf/black-forest-labs/flux-1-schnell`
- **Code Generation**: `@cf/deepseek-ai/deepseek-r1-distill-qwen-32b`

## 🔧 Configuration

### Environment Variables
```env
CLOUDFLARE_API_TOKEN=your_api_token
CLOUDFLARE_ACCOUNT_ID=your_account_id
ENVIRONMENT=production
AI_GATEWAY_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=100
RATE_LIMIT_TOKENS_PER_HOUR=10000
```

### Wrangler Configuration
See `wrangler.toml` for complete configuration including:
- Worker bindings
- Rate limiting rules
- Environment variables
- Queue consumers

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

### Development Guidelines
- TypeScript for all code
- Comprehensive error handling
- Security-first approach
- Performance optimization
- Extensive logging and monitoring

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

- **Documentation**: [docs.empathyfirstmedia.com](https://docs.empathyfirstmedia.com)
- **Issues**: [GitHub Issues](https://github.com/empathyfirstmedia/ai-platform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/empathyfirstmedia/ai-platform/discussions)

## 🎯 Roadmap

- [ ] Voice agent integration
- [ ] Multi-language support
- [ ] Advanced RAG with hybrid search
- [ ] Custom model fine-tuning
- [ ] Real-time collaboration features
- [ ] Advanced analytics dashboard
- [ ] Integration with popular CMS platforms

---

Built with ❤️ by Empathy First Media Agency using Cloudflare Workers AI