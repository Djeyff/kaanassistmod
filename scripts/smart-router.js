#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════
// CodexLB Smart Router
// Sits between OpenClaw and codexlb.voz-clara.com
// Auto-routes requests to gpt-5.4-mini or gpt-5.4 based on complexity
// ═══════════════════════════════════════════════════════════════

const http = require('http');
const https = require('https');
const { URL } = require('url');

// ── Config ─────────────────────────────────────────────────────
const PORT = parseInt(process.env.SMART_ROUTER_PORT || '18792');
// UPSTREAM_URL should be the full base including /v1 (e.g., https://codexlb.voz-clara.com/v1)
const UPSTREAM_URL = process.env.SMART_ROUTER_UPSTREAM || 'https://codexlb.voz-clara.com/v1';
const UPSTREAM_API_KEY = process.env.CODEX_LB_API_KEY || process.env.OPENAI_API_KEY || '';
const MODEL_MINI = process.env.SMART_ROUTER_MINI || 'gpt-5.4-mini';
const MODEL_BIG = process.env.SMART_ROUTER_BIG || 'gpt-5.4';
const LOG_ROUTING = process.env.SMART_ROUTER_LOG !== '0';

// Parse upstream once for hostname/port/basePath
const UPSTREAM_PARSED = new URL(UPSTREAM_URL);
const UPSTREAM_HOST = UPSTREAM_PARSED.hostname;
const UPSTREAM_PORT = UPSTREAM_PARSED.port || (UPSTREAM_PARSED.protocol === 'https:' ? 443 : 80);
const UPSTREAM_BASE_PATH = UPSTREAM_PARSED.pathname.replace(/\/$/, ''); // e.g., "/v1"

// Rewrite incoming path to full upstream path
// Incoming: /v1/chat/completions  →  upstream path: /v1/chat/completions
// Incoming: /chat/completions     →  upstream path: /v1/chat/completions
function buildUpstreamPath(incomingPath) {
  // Strip leading /v1 if present (OpenClaw may or may not include it)
  let path = incomingPath.replace(/^\/v1/, '');
  if (!path.startsWith('/')) path = '/' + path;
  return UPSTREAM_BASE_PATH + path;
}

// ── Simplicity heuristics (downgrade to mini) ──────────────────
const SIMPLE_PATTERNS = /^(hi|hello|hey|status|what time|weather|ping|test|\/\w+)$/i;

// Rough token estimate: 1 token ≈ 4 chars for English, slightly more for other languages
function estimateTokens(text) {
  if (!text) return 0;
  return Math.ceil(text.length / 4);
}

function classifyComplexity(body) {
  const messages = body.messages || [];
  const reasons = [];

  const totalText = messages.map(m => {
    if (typeof m.content === 'string') return m.content;
    if (Array.isArray(m.content)) return m.content.map(b => b.text || '').join(' ');
    return '';
  }).join('\n');
  
  const totalTokens = estimateTokens(totalText);

  // Last user message
  const userMessages = messages.filter(m => m.role === 'user');
  const lastUserMsg = userMessages[userMessages.length - 1];
  const lastText = typeof lastUserMsg?.content === 'string' 
    ? lastUserMsg.content 
    : (Array.isArray(lastUserMsg?.content) ? lastUserMsg.content.map(b => b.text || '').join(' ') : '');

  // Check for simple query (downgrade to mini)
  const isSimple = 
    messages.length <= 4 &&
    totalTokens < 2000 &&
    lastText.length < 200 &&
    !lastText.includes('\n') &&
    messages.filter(m => m.role === 'tool' || m.role === 'function').length === 0;

  if (isSimple) reasons.push('simple_query');
  if (SIMPLE_PATTERNS.test(lastText.trim())) reasons.push('greeting_or_command');

  return {
    useMini: reasons.length >= 1,
    reasons,
    totalTokens,
    messageCount: messages.length,
  };
}

// ── Proxy handler ──────────────────────────────────────────────
async function handleRequest(req, res) {
  // Pass through non-completions endpoints directly
  const isCompletions = req.url.includes('/chat/completions');
  
  if (!isCompletions) {
    return proxyRaw(req, res);
  }

  // Buffer the request body
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const rawBody = Buffer.concat(chunks);

  let body;
  try {
    body = JSON.parse(rawBody.toString());
  } catch {
    return proxyWithBody(req, res, rawBody);
  }

  // Check if model was explicitly set by the user
  const requestedModel = body.model || '';
  const isExplicit = requestedModel === MODEL_BIG || requestedModel === MODEL_MINI;

  // Detect heartbeat — system-only or no new user message, force mini
  const userMessages = body.messages?.filter(m => m.role === 'user') || [];
  const lastUserMsg = userMessages[userMessages.length - 1];
  const lastText = typeof lastUserMsg?.content === 'string' 
    ? lastUserMsg.content 
    : (Array.isArray(lastUserMsg?.content) ? lastUserMsg.content.map(b => b.text || '').join(' ') : '');
  
  const isHeartbeat = !lastUserMsg || 
    /heartbeat|health.?check|status.?check|^\s*$/i.test(lastText) ||
    (body.messages?.length > 50 && userMessages.length <= 1);
  
  if (isHeartbeat) {
    body.model = MODEL_MINI;
    if (LOG_ROUTING) {
      console.log(`[${new Date().toISOString()}] [smart-router] → mini (heartbeat detected) | msgs:${body.messages?.length || 0}`);
    }
    const newBody = Buffer.from(JSON.stringify(body));
    return proxyWithBody(req, res, newBody);
  }

  // DEFAULT TO BIG — classify complexity and downgrade to mini only for simple queries
  // (Override OpenClaw's explicit mini request — we know better)
  const classification = classifyComplexity(body);
  const selectedModel = classification.useMini ? MODEL_MINI : MODEL_BIG;
  
  if (LOG_ROUTING) {
    const ts = new Date().toISOString();
    const wasExplicit = isExplicit ? ` [was:${requestedModel}]` : '';
    const routeInfo = classification.useMini 
      ? `→ mini (${classification.reasons.join(', ')})${wasExplicit}` 
      : `→ BIG (default)${wasExplicit}`;
    console.log(`[${ts}] [smart-router] ${routeInfo} | msgs:${classification.messageCount} tokens:~${classification.totalTokens}`);
  }

  body.model = selectedModel;

  const newBody = Buffer.from(JSON.stringify(body));
  return proxyWithBody(req, res, newBody);
}

// ── Raw proxy (non-completions) ────────────────────────────────
function proxyRaw(clientReq, clientRes) {
  const upstreamPath = buildUpstreamPath(clientReq.url);
  const options = {
    hostname: UPSTREAM_HOST,
    port: UPSTREAM_PORT,
    path: upstreamPath,
    method: clientReq.method,
    headers: { ...clientReq.headers, host: UPSTREAM_HOST },
  };
  // Inject codexlb auth
  if (UPSTREAM_API_KEY) {
    options.headers['authorization'] = `Bearer ${UPSTREAM_API_KEY}`;
  }

  if (LOG_ROUTING) {
    console.log(`[${new Date().toISOString()}] [smart-router] raw → ${UPSTREAM_HOST}${upstreamPath}`);
  }

  const proxy = https.request(options, (upstreamRes) => {
    clientRes.writeHead(upstreamRes.statusCode, upstreamRes.headers);
    upstreamRes.pipe(clientRes);
  });

  proxy.on('error', (err) => {
    console.error(`[smart-router] raw upstream error: ${err.message}`);
    clientRes.writeHead(502, { 'Content-Type': 'application/json' });
    clientRes.end(JSON.stringify({ error: { message: 'Smart router upstream error', details: err.message } }));
  });

  clientReq.pipe(proxy);
}

// ── Proxy with buffered auto-retry (catches stream disconnections) ──
const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 2000;

function proxyWithBody(clientReq, clientRes, body) {
  const parsedBody = JSON.parse(body.toString());
  const isStreaming = parsedBody.stream === true;
  const isCompletions = clientReq.url.includes('/chat/completions');
  
  // For non-completions or non-streaming: pass through directly
  if (!isCompletions || !isStreaming) {
    return proxyDirect(clientReq, clientRes, body);
  }

  // For streaming completions: buffer, validate, retry on failure
  proxyBuffered(clientReq, body, parsedBody, 0, (err, result) => {
    if (err) {
      console.error(`[${new Date().toISOString()}] [smart-router] all attempts failed: ${err.message}`);
      if (!clientRes.headersSent) {
        clientRes.writeHead(502, { 'Content-Type': 'application/json' });
      }
      clientRes.end(JSON.stringify({ 
        error: { message: 'Smart router: upstream failed after retry', details: err.message }
      }));
      return;
    }
    
    // Send buffered result
    if (!clientRes.headersSent) {
      clientRes.writeHead(result.statusCode, result.headers);
    }
    clientRes.end(result.body);
  });
}

function proxyBuffered(clientReq, originalBody, parsedBody, attempt, callback) {
  const upstreamPath = buildUpstreamPath(clientReq.url);
  
  // On retry: force stream=false for guaranteed completion
  let requestBody;
  if (attempt > 0) {
    const retryBody = { ...parsedBody, stream: false };
    requestBody = Buffer.from(JSON.stringify(retryBody));
    console.log(`[${new Date().toISOString()}] [smart-router] retry #${attempt} with stream=false`);
  } else {
    requestBody = originalBody;
  }

  const headers = { ...clientReq.headers, host: UPSTREAM_HOST };
  headers['content-length'] = Buffer.byteLength(requestBody);
  if (UPSTREAM_API_KEY) {
    headers['authorization'] = `Bearer ${UPSTREAM_API_KEY}`;
  }
  delete headers['transfer-encoding'];

  const options = {
    hostname: UPSTREAM_HOST,
    port: UPSTREAM_PORT,
    path: upstreamPath,
    method: 'POST',
    headers,
    timeout: 600000, // 10 min timeout
  };

  if (LOG_ROUTING && attempt === 0) {
    console.log(`[${new Date().toISOString()}] [smart-router] → ${UPSTREAM_HOST}${upstreamPath}`);
  }

  const chunks = [];
  let statusCode = 200;
  let responseHeaders = {};

  const proxy = https.request(options, (upstreamRes) => {
    statusCode = upstreamRes.statusCode;
    responseHeaders = upstreamRes.headers;

    upstreamRes.on('data', (chunk) => chunks.push(chunk));

    upstreamRes.on('end', () => {
      const fullBody = Buffer.concat(chunks);
      const bodyStr = fullBody.toString();
      
      // Check for stream completion
      const isSSE = responseHeaders['content-type']?.includes('text/event-stream');
      
      // Detect codexlb/upstream error responses (small JSON with "error" key)
      const isUpstreamError = fullBody.length < 500 && bodyStr.includes('"error"');
      
      let streamComplete;
      if (isUpstreamError) {
        // Small error response from codexlb — NOT a valid completion
        streamComplete = false;
        console.warn(`[${new Date().toISOString()}] [smart-router] ⚠️ upstream error response (${fullBody.length} bytes): ${bodyStr.slice(0, 200)}`);
      } else if (isSSE) {
        // SSE: must have [DONE] or finish_reason
        streamComplete = bodyStr.includes('data: [DONE]') || bodyStr.includes('"finish_reason"');
      } else {
        // Non-SSE: must be 2xx AND contain valid completion data (choices/content)
        streamComplete = statusCode >= 200 && statusCode < 300 && 
          (bodyStr.includes('"choices"') || bodyStr.includes('"content"') || fullBody.length > 500);
      }

      if (streamComplete) {
        console.log(`[${new Date().toISOString()}] [smart-router] response complete (attempt ${attempt + 1}, ${fullBody.length} bytes)`);
        callback(null, { statusCode, headers: responseHeaders, body: fullBody });
      } else if (statusCode >= 400) {
        // Hard server error — don't retry, pass through
        console.warn(`[${new Date().toISOString()}] [smart-router] upstream HTTP ${statusCode} (${fullBody.length} bytes) — not retrying`);
        callback(null, { statusCode, headers: responseHeaders, body: fullBody });
      } else if (attempt < MAX_RETRIES) {
        // Incomplete or error — retry
        console.warn(`[${new Date().toISOString()}] [smart-router] ⚠️ incomplete/error (attempt ${attempt + 1}, ${fullBody.length} bytes) — retrying in ${RETRY_DELAY_MS}ms`);
        setTimeout(() => {
          proxyBuffered(clientReq, originalBody, parsedBody, attempt + 1, callback);
        }, RETRY_DELAY_MS);
      } else {
        // All retries exhausted — pass through whatever we have
        console.error(`[${new Date().toISOString()}] [smart-router] ✗ all ${attempt + 1} attempts failed (${fullBody.length} bytes)`);
        callback(null, { statusCode, headers: responseHeaders, body: fullBody });
      }
    });
  });

  proxy.on('timeout', () => {
    proxy.destroy();
    if (attempt < MAX_RETRIES) {
      console.warn(`[${new Date().toISOString()}] [smart-router] ⚠️ timeout (attempt ${attempt + 1}) — retrying`);
      setTimeout(() => {
        proxyBuffered(clientReq, originalBody, parsedBody, attempt + 1, callback);
      }, RETRY_DELAY_MS);
    } else {
      callback(new Error('upstream timeout after retry'));
    }
  });

  proxy.on('error', (err) => {
    if (attempt < MAX_RETRIES) {
      console.warn(`[${new Date().toISOString()}] [smart-router] ⚠️ error (attempt ${attempt + 1}): ${err.message} — retrying`);
      setTimeout(() => {
        proxyBuffered(clientReq, originalBody, parsedBody, attempt + 1, callback);
      }, RETRY_DELAY_MS);
    } else {
      callback(err);
    }
  });

  proxy.write(requestBody);
  proxy.end();
}

// Direct passthrough (non-completions, non-streaming)
function proxyDirect(clientReq, clientRes, body) {
  const upstreamPath = buildUpstreamPath(clientReq.url);
  const headers = { ...clientReq.headers, host: UPSTREAM_HOST };
  headers['content-length'] = Buffer.byteLength(body);
  if (UPSTREAM_API_KEY) {
    headers['authorization'] = `Bearer ${UPSTREAM_API_KEY}`;
  }
  delete headers['transfer-encoding'];

  const options = {
    hostname: UPSTREAM_HOST,
    port: UPSTREAM_PORT,
    path: upstreamPath,
    method: clientReq.method,
    headers,
  };

  if (LOG_ROUTING) {
    console.log(`[${new Date().toISOString()}] [smart-router] direct → ${UPSTREAM_HOST}${upstreamPath}`);
  }

  const proxy = https.request(options, (upstreamRes) => {
    clientRes.writeHead(upstreamRes.statusCode, upstreamRes.headers);
    upstreamRes.pipe(clientRes);
  });

  proxy.on('error', (err) => {
    console.error(`[smart-router] direct upstream error: ${err.message}`);
    clientRes.writeHead(502, { 'Content-Type': 'application/json' });
    clientRes.end(JSON.stringify({ error: { message: 'Smart router upstream error', details: err.message } }));
  });

  proxy.write(body);
  proxy.end();
}

// ── Start server ───────────────────────────────────────────────
const server = http.createServer(handleRequest);

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[smart-router] listening on 127.0.0.1:${PORT}`);
  console.log(`[smart-router] upstream: ${UPSTREAM_URL}`);
  console.log(`[smart-router] models: ${MODEL_BIG} (default) / ${MODEL_MINI} (simple queries)`);
  console.log(`[smart-router] auto-retry: buffers streaming completions, retries with stream=false on failure`);
  console.log(`[smart-router] heartbeat: detected and forced to mini`);
});

server.on('error', (err) => {
  console.error(`[smart-router] server error: ${err.message}`);
  process.exit(1);
});
