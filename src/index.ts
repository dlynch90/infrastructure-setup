import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { rateLimiter } from 'hono/rate-limiter';
import { Ai } from '@cloudflare/ai';
import { createWorkersAI } from 'workers-ai-provider';
import { streamText } from 'ai';
import { z } from 'zod';

// Types
interface Env {
  AI: Ai;
  DB: D1Database;
  VECTORIZE: VectorizeIndex;
  R2_CONTENT: R2Bucket;
  KV_CACHE: KVNamespace;
  AI_QUEUE: Queue;
  CLOUDFLARE_API_TOKEN: string;
  ENVIRONMENT: string;
  AI_GATEWAY_ENABLED: boolean;
  RATE_LIMIT_REQUESTS_PER_MINUTE: number;
  RATE_LIMIT_TOKENS_PER_HOUR: number;
}

type Variables = {
  userId: string;
  clientId: string;
  requestId: string;
};

// Model configurations for different use cases
const MODELS = {
  // Content Generation - High quality, creative writing
  CONTENT_GEN: '@cf/meta/llama-3.3-70b-instruct-fp8-fast',

  // Code Generation - Technical, precise
  CODE_GEN: '@cf/deepseek-ai/deepseek-r1-distill-qwen-32b',

  // Chat/Conversational - Fast, context-aware
  CHAT: '@cf/meta/llama-3.1-8b-instruct-awq',

  // Embeddings - High quality vector representations
  EMBEDDINGS: '@cf/baai/bge-large-en-v1.5',

  // Text-to-Speech - Natural voice synthesis
  TTS: '@cf/deepgram/aura-2-en',

  // Speech Recognition - Accurate transcription
  STT: '@cf/openai/whisper-large-v3-turbo',

  // Image Generation - Creative visual content
  IMAGE_GEN: '@cf/black-forest-labs/flux-1-schnell',
} as const;

// Security middleware
const securityHeaders = async (c: any, next: any) => {
  await next();

  c.header('X-Content-Type-Options', 'nosniff');
  c.header('X-Frame-Options', 'DENY');
  c.header('X-XSS-Protection', '1; mode=block');
  c.header('Referrer-Policy', 'strict-origin-when-cross-origin');
  c.header('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
};

// Rate limiting middleware
const createRateLimiter = (requests: number, windowMs: number) => {
  return rateLimiter({
    windowMs,
    limit: requests,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (c) => `${c.var.clientId || 'anonymous'}:${c.req.path}`,
  });
};

// Authentication middleware
const authMiddleware = async (c: any, next: any) => {
  const authHeader = c.req.header('Authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Missing or invalid authorization header' }, 401);
  }

  const token = authHeader.slice(7);

  // Verify JWT token (implement your JWT verification logic)
  try {
    const payload = await verifyJWT(token, c.env);
    c.set('userId', payload.userId);
    c.set('clientId', payload.clientId);
    await next();
  } catch (error) {
    return c.json({ error: 'Invalid token' }, 401);
  }
};

// Request ID middleware
const requestIdMiddleware = async (c: any, next: any) => {
  const requestId = crypto.randomUUID();
  c.set('requestId', requestId);
  c.header('X-Request-ID', requestId);
  await next();
};

// Initialize Hono app
const app = new Hono<{ Bindings: Env; Variables: Variables }>();

// Global middleware
app.use('*', cors({
  origin: ['https://empathyfirstmedia.com', 'https://*.empathyfirstmedia.com'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  credentials: true,
}));

app.use('*', logger());
app.use('*', securityHeaders);
app.use('*', requestIdMiddleware);

// Rate limiting for AI endpoints
app.use('/api/ai/*', createRateLimiter(100, 60 * 1000)); // 100 requests per minute
app.use('/api/ai/generate/*', createRateLimiter(20, 60 * 1000)); // 20 generation requests per minute

// Authentication for protected routes
app.use('/api/ai/*', authMiddleware);

// Health check
app.get('/health', (c) => c.json({
  status: 'healthy',
  timestamp: new Date().toISOString(),
  environment: c.env.ENVIRONMENT,
}));

// AI Chat endpoint with streaming
app.post('/api/ai/chat', async (c) => {
  try {
    const body = await c.req.json();
    const { messages, model = MODELS.CHAT, stream = true, temperature = 0.7 } = body;

    // Validate input
    const schema = z.object({
      messages: z.array(z.object({
        role: z.enum(['user', 'assistant', 'system']),
        content: z.string(),
      })),
      model: z.string().optional(),
      stream: z.boolean().optional(),
      temperature: z.number().min(0).max(2).optional(),
    });

    const validated = schema.parse({ messages, model, stream, temperature });

    // Check token usage limits
    const userId = c.var.userId;
    const tokenKey = `tokens:${userId}:${new Date().toISOString().slice(0, 13)}`;
    const currentTokens = parseInt(await c.env.KV_CACHE.get(tokenKey) || '0');

    if (currentTokens >= c.env.RATE_LIMIT_TOKENS_PER_HOUR) {
      return c.json({ error: 'Token limit exceeded' }, 429);
    }

    if (stream) {
      // Streaming response
      const workersai = createWorkersAI({ binding: c.env.AI });

      const result = await streamText({
        model: workersai(model),
        messages: validated.messages,
        temperature: validated.temperature,
      });

      // Update token usage (approximate)
      const estimatedTokens = validated.messages.reduce((acc, msg) => acc + msg.content.length, 0) * 0.25;
      await c.env.KV_CACHE.put(tokenKey, (currentTokens + estimatedTokens).toString(), {
        expirationTtl: 3600, // 1 hour
      });

      return result.toTextStreamResponse({
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'X-Request-ID': c.var.requestId,
        },
      });
    } else {
      // Non-streaming response
      const response = await c.env.AI.run(model, {
        messages: validated.messages,
        temperature: validated.temperature,
      });

      // Update token usage
      const estimatedTokens = validated.messages.reduce((acc, msg) => acc + msg.content.length, 0) * 0.25;
      await c.env.KV_CACHE.put(tokenKey, (currentTokens + estimatedTokens).toString(), {
        expirationTtl: 3600,
      });

      // Store conversation in D1
      await c.env.DB.prepare(
        'INSERT INTO conversations (user_id, request_id, messages, response, created_at) VALUES (?, ?, ?, ?, ?)'
      ).bind(
        userId,
        c.var.requestId,
        JSON.stringify(validated.messages),
        response.response,
        new Date().toISOString()
      ).run();

      return c.json({
        response: response.response,
        requestId: c.var.requestId,
        usage: { estimatedTokens },
      });
    }
  } catch (error) {
    console.error('Chat error:', error);
    return c.json({ error: 'Internal server error' }, 500);
  }
});

// Content generation endpoint
app.post('/api/ai/generate', async (c) => {
  try {
    const body = await c.req.json();
    const {
      prompt,
      model = MODELS.CONTENT_GEN,
      type = 'article',
      length = 'medium',
      style = 'professional'
    } = body;

    // Queue for async processing if content is complex
    if (length === 'long' || type === 'book') {
      await c.env.AI_QUEUE.send({
        type: 'content_generation',
        prompt,
        model,
        type,
        length,
        style,
        userId: c.var.userId,
        requestId: c.var.requestId,
      });

      return c.json({
        status: 'queued',
        requestId: c.var.requestId,
        message: 'Content generation started. Check status endpoint for results.',
      });
    }

    // Direct generation for simpler content
    const systemPrompt = `You are a professional content writer for ${style} audiences. Generate ${type} content that is engaging, well-structured, and informative.`;

    const response = await c.env.AI.run(model, {
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: prompt },
      ],
      temperature: 0.8,
    });

    // Store in R2 if it's an image or large content
    if (type === 'image' || response.response.length > 10000) {
      const key = `${c.var.userId}/${c.var.requestId}/generated-content.txt`;
      await c.env.R2_CONTENT.put(key, response.response, {
        httpMetadata: {
          contentType: 'text/plain',
          cacheControl: 'public, max-age=31536000', // 1 year
        },
      });

      return c.json({
        status: 'stored',
        url: `https://content.empathyfirstmedia.com/${key}`,
        requestId: c.var.requestId,
      });
    }

    return c.json({
      content: response.response,
      requestId: c.var.requestId,
      metadata: { type, length, style, model },
    });
  } catch (error) {
    console.error('Generation error:', error);
    return c.json({ error: 'Content generation failed' }, 500);
  }
});

// RAG endpoint for knowledge base queries
app.post('/api/ai/rag', async (c) => {
  try {
    const body = await c.req.json();
    const { query, topK = 5 } = body;

    // Generate embedding for the query
    const embedding = await c.env.AI.run(MODELS.EMBEDDINGS, {
      text: query,
    });

    // Search vector database
    const vectors = await c.env.VECTORIZE.query(embedding.data[0], {
      topK,
      returnValues: true,
      returnMetadata: true,
    });

    // Get relevant context from D1
    const contextIds = vectors.matches?.map(match => match.id) || [];
    if (contextIds.length === 0) {
      return c.json({ answer: 'No relevant information found in knowledge base.' });
    }

    const placeholders = contextIds.map(() => '?').join(',');
    const contextQuery = `SELECT content FROM knowledge_base WHERE id IN (${placeholders})`;
    const contextResults = await c.env.DB.prepare(contextQuery).bind(...contextIds).all();

    const context = contextResults.results?.map(row => row.content).join('\n\n') || '';

    // Generate answer with context
    const response = await c.env.AI.run(MODELS.CHAT, {
      messages: [
        {
          role: 'system',
          content: `You are a helpful assistant. Use the provided context to answer the user's question accurately. If the context doesn't contain relevant information, say so.`
        },
        {
          role: 'user',
          content: `Context:\n${context}\n\nQuestion: ${query}`
        },
      ],
    });

    return c.json({
      answer: response.response,
      sources: contextIds.length,
      confidence: vectors.matches?.[0]?.score || 0,
    });
  } catch (error) {
    console.error('RAG error:', error);
    return c.json({ error: 'Knowledge base query failed' }, 500);
  }
});

// Queue consumer for async processing
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    return app.fetch(request, env, ctx);
  },

  async queue(batch: MessageBatch, env: Env, ctx: ExecutionContext) {
    for (const message of batch.messages) {
      try {
        const { type, prompt, model, userId, requestId, ...params } = message.body as any;

        if (type === 'content_generation') {
          // Process content generation
          const systemPrompt = `You are a professional content writer. Generate high-quality ${params.type} content.`;

          const response = await env.AI.run(model, {
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: prompt },
            ],
            temperature: 0.8,
          });

          // Store result in R2
          const key = `${userId}/${requestId}/generated-content.txt`;
          await env.R2_CONTENT.put(key, response.response);

          // Update status in KV
          await env.KV_CACHE.put(`status:${requestId}`, 'completed', {
            expirationTtl: 86400, // 24 hours
          });
        }
      } catch (error) {
        console.error('Queue processing error:', error);
        // Handle error - could send notification, retry, etc.
      }
    }
  },
};

// Helper functions
async function verifyJWT(token: string, env: Env): Promise<any> {
  // Implement JWT verification logic here
  // This is a placeholder - implement proper JWT verification
  return { userId: 'user-123', clientId: 'client-456' };
}