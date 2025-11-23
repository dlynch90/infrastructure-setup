/**
 * Empathy First Media Agency - AI Platform Monitoring
 * Client-side analytics and monitoring utilities
 */

// Configuration
const MONITORING_CONFIG = {
  endpoint: '/api/analytics',
  sampleRate: 0.1, // Sample 10% of requests
  batchSize: 10,
  flushInterval: 30000, // 30 seconds
};

// Analytics data collector
class AIAnalytics {
  constructor() {
    this.events = [];
    this.sessionId = this.generateSessionId();
    this.userId = null;
    this.init();
  }

  init() {
    // Start periodic flush
    setInterval(() => this.flush(), MONITORING_CONFIG.flushInterval);

    // Track page visibility
    document.addEventListener('visibilitychange', () => {
      this.track('page_visibility', {
        state: document.visibilityState,
        timestamp: Date.now(),
      });
    });

    // Track errors
    window.addEventListener('error', (event) => {
      this.track('javascript_error', {
        message: event.message,
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno,
        stack: event.error?.stack,
      });
    });

    // Track unhandled promise rejections
    window.addEventListener('unhandledrejection', (event) => {
      this.track('promise_rejection', {
        reason: event.reason?.toString(),
        stack: event.reason?.stack,
      });
    });
  }

  generateSessionId() {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  setUserId(userId) {
    this.userId = userId;
  }

  track(eventName, properties = {}) {
    // Sample events based on sample rate
    if (Math.random() > MONITORING_CONFIG.sampleRate) {
      return;
    }

    const event = {
      event: eventName,
      properties: {
        ...properties,
        timestamp: Date.now(),
        sessionId: this.sessionId,
        userId: this.userId,
        userAgent: navigator.userAgent,
        url: window.location.href,
        referrer: document.referrer,
        viewport: {
          width: window.innerWidth,
          height: window.innerHeight,
        },
        performance: this.getPerformanceMetrics(),
      },
    };

    this.events.push(event);

    // Flush if batch size reached
    if (this.events.length >= MONITORING_CONFIG.batchSize) {
      this.flush();
    }
  }

  getPerformanceMetrics() {
    if (!performance.timing) return null;

    const timing = performance.timing;
    return {
      dns: timing.domainLookupEnd - timing.domainLookupStart,
      tcp: timing.connectEnd - timing.connectStart,
      ssl: timing.connectEnd - timing.secureConnectionStart,
      ttfb: timing.responseStart - timing.requestStart,
      domLoad: timing.domContentLoadedEventEnd - timing.navigationStart,
      pageLoad: timing.loadEventEnd - timing.navigationStart,
    };
  }

  async flush() {
    if (this.events.length === 0) return;

    const events = [...this.events];
    this.events = [];

    try {
      const response = await fetch(MONITORING_CONFIG.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.getAuthToken()}`,
        },
        body: JSON.stringify({
          events,
          clientVersion: '1.0.0',
          clientType: 'web',
        }),
      });

      if (!response.ok) {
        console.warn('Analytics flush failed:', response.status);
        // Re-queue events for retry
        this.events.unshift(...events);
      }
    } catch (error) {
      console.warn('Analytics flush error:', error);
      // Re-queue events for retry
      this.events.unshift(...events);
    }
  }

  getAuthToken() {
    // Get token from localStorage, cookie, or other storage
    return localStorage.getItem('auth_token') || '';
  }
}

// AI-specific tracking
class AITracking extends AIAnalytics {
  trackAIRequest(endpoint, requestData, responseData, duration) {
    this.track('ai_request', {
      endpoint,
      model: requestData.model,
      requestSize: JSON.stringify(requestData).length,
      responseSize: responseData ? JSON.stringify(responseData).length : 0,
      duration,
      success: !responseData?.error,
      error: responseData?.error,
      tokensUsed: responseData?.usage?.totalTokens,
      streaming: requestData.stream || false,
    });
  }

  trackAIError(endpoint, error, context) {
    this.track('ai_error', {
      endpoint,
      error: error.message,
      stack: error.stack,
      context,
      userImpact: this.assessUserImpact(error),
    });
  }

  assessUserImpact(error) {
    // Assess how critical this error is to user experience
    if (error.message.includes('rate_limit')) return 'high';
    if (error.message.includes('auth')) return 'critical';
    if (error.message.includes('timeout')) return 'medium';
    return 'low';
  }

  trackContentGeneration(type, prompt, success, duration) {
    this.track('content_generation', {
      type, // 'article', 'social', 'email', etc.
      promptLength: prompt.length,
      success,
      duration,
      wordCount: success ? this.estimateWordCount(prompt) : 0,
    });
  }

  estimateWordCount(text) {
    return text.split(/\s+/).filter(word => word.length > 0).length;
  }
}

// Performance monitoring
class PerformanceMonitor {
  constructor() {
    this.metrics = {};
    this.init();
  }

  init() {
    // Monitor Core Web Vitals
    this.observeCoreWebVitals();

    // Monitor API calls
    this.interceptFetch();
  }

  observeCoreWebVitals() {
    // Largest Contentful Paint
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const lastEntry = entries[entries.length - 1];
      this.recordMetric('lcp', lastEntry.startTime);
    }).observe({ entryTypes: ['largest-contentful-paint'] });

    // First Input Delay
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry) => {
        this.recordMetric('fid', entry.processingStart - entry.startTime);
      });
    }).observe({ entryTypes: ['first-input'] });

    // Cumulative Layout Shift
    new PerformanceObserver((list) => {
      let clsValue = 0;
      const entries = list.getEntries();
      entries.forEach((entry) => {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
        }
      });
      this.recordMetric('cls', clsValue);
    }).observe({ entryTypes: ['layout-shift'] });
  }

  interceptFetch() {
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      const startTime = Date.now();
      const url = args[0] instanceof Request ? args[0].url : args[0];

      try {
        const response = await originalFetch(...args);
        const duration = Date.now() - startTime;

        // Track API performance
        if (url.includes('/api/ai/')) {
          this.recordMetric('api_response_time', duration, { endpoint: url });
        }

        return response;
      } catch (error) {
        const duration = Date.now() - startTime;
        this.recordMetric('api_error', duration, {
          endpoint: url,
          error: error.message
        });
        throw error;
      }
    };
  }

  recordMetric(name, value, tags = {}) {
    if (!this.metrics[name]) {
      this.metrics[name] = [];
    }

    this.metrics[name].push({
      value,
      timestamp: Date.now(),
      tags,
    });

    // Keep only last 100 metrics per type
    if (this.metrics[name].length > 100) {
      this.metrics[name] = this.metrics[name].slice(-100);
    }

    // Send to analytics if available
    if (window.aiAnalytics) {
      window.aiAnalytics.track('performance_metric', {
        name,
        value,
        tags: JSON.stringify(tags),
      });
    }
  }

  getMetrics(name, timeRange = 3600000) { // 1 hour default
    const cutoff = Date.now() - timeRange;
    return this.metrics[name]?.filter(metric => metric.timestamp > cutoff) || [];
  }

  getAverageMetric(name, timeRange = 3600000) {
    const metrics = this.getMetrics(name, timeRange);
    if (metrics.length === 0) return 0;

    const sum = metrics.reduce((acc, metric) => acc + metric.value, 0);
    return sum / metrics.length;
  }
}

// Error boundary for React components
class AIErrorBoundary {
  constructor(componentName) {
    this.componentName = componentName;
    this.errorCount = 0;
  }

  catchError(error, errorInfo) {
    this.errorCount++;

    // Track error
    if (window.aiAnalytics) {
      window.aiAnalytics.trackAIError(
        'component_error',
        error,
        {
          component: this.componentName,
          errorCount: this.errorCount,
          errorInfo,
        }
      );
    }

    // Log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.error(`Error in ${this.componentName}:`, error, errorInfo);
    }

    // Show user-friendly error message
    this.showErrorToast(error);
  }

  showErrorToast(error) {
    // Implement toast notification
    const toast = document.createElement('div');
    toast.className = 'error-toast';
    toast.innerHTML = `
      <div class="error-content">
        <h4>Something went wrong</h4>
        <p>${this.getErrorMessage(error)}</p>
        <button onclick="this.parentElement.parentElement.remove()">Dismiss</button>
      </div>
    `;
    document.body.appendChild(toast);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentElement) {
        toast.remove();
      }
    }, 5000);
  }

  getErrorMessage(error) {
    if (error.message.includes('rate_limit')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (error.message.includes('network')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

// Initialize monitoring
const aiAnalytics = new AITracking();
const performanceMonitor = new PerformanceMonitor();

// Make globally available
window.aiAnalytics = aiAnalytics;
window.performanceMonitor = performanceMonitor;

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    AIAnalytics,
    AITracking,
    PerformanceMonitor,
    AIErrorBoundary,
  };
}