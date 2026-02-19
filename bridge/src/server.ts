/**
 * IRIS AI Agent Bridge — Express server.
 * Bridges AI SDKs (Claude, Codex, Azure, Google) to IRIS via REST.
 * Runs on port 3100 by default.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import express from 'express';
import cors from 'cors';
import { config, isAzureConfigured } from './config.js';
import { RunnerRegistry } from './runners/runner-registry.js';
import { ClaudeRunner } from './runners/claude-agent-sdk/index.js';
import { OpenAIRunner } from './runners/openai-codex/index.js';
import { OpenAICodexSDKRunner } from './runners/openai-codex-sdk/index.js';
import { AzureOpenAIRunner } from './runners/azure-openai/index.js';
import { createChatRouter } from './routes/chat.js';
import { createRunnersRouter } from './routes/runners.js';
import { createHealthRouter } from './routes/health.js';
import { createActionsRouter } from './routes/actions.js';
import { createIrisGatewayRouter } from './routes/iris-gateway.js';

// Initialize the runner registry
const registry = new RunnerRegistry();

// Register available runners based on configuration
if (config.openai.apiKey && config.codexNative.enabled) {
  registry.register(new OpenAICodexSDKRunner({
    model: config.codexNative.model,
    workspaceRoot: config.codexNative.workspaceRoot,
    additionalDirectories: config.codexNative.additionalDirectories,
    sandboxMode: config.codexNative.sandbox,
    approvalPolicy: config.codexNative.approvalPolicy,
  }));
  console.log('[Server] OpenAI Codex SDK runner registered');
}

if (config.anthropic.apiKey) {
  registry.register(new ClaudeRunner(config.anthropic.apiKey, config.anthropic.model));
  console.log('[Server] Claude Agent SDK runner registered');
}

if (config.openai.apiKey) {
  registry.register(new OpenAIRunner(config.openai.apiKey, config.openai.model));
  console.log('[Server] OpenAI runner registered');
}

if (isAzureConfigured()) {
  registry.register(new AzureOpenAIRunner({
    endpoint: config.azureOpenai.endpoint,
    apiKey: config.azureOpenai.apiKey,
    deploymentName: config.azureOpenai.deployment,
    apiVersion: config.azureOpenai.apiVersion,
  }));
  console.log('[Server] Azure OpenAI runner registered');
}

if (registry.getAll().length === 0) {
  console.warn('[Server] WARNING: No AI API keys configured. Set ANTHROPIC_API_KEY or OPENAI_API_KEY in .env');
}

// Create Express app
const app = express();

// Middleware
app.use(cors({
  origin: [
    'http://localhost',
    /^http:\/\/localhost:\d+$/,
    /\.nhs\.uk$/,
    /\.bradfordhospitals\./,
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '10mb' }));

// Request logging
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Routes
app.use('/api/chat', createChatRouter(registry));
app.use('/api/runners', createRunnersRouter(registry));
app.use('/api/actions', createActionsRouter());
app.use('/api/iris', createIrisGatewayRouter());
app.use('/api', createHealthRouter(registry));

// Global error handler
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[Server] Unhandled error:', err.message);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

// Start server
const PORT = config.port;
app.listen(PORT, () => {
  console.log(`
================================================================
  IRIS AI Agent Bridge — Running on port ${PORT}
================================================================
  Registered runners: ${registry.getAll().map(r => r.id).join(', ') || 'NONE'}
  IRIS base URL:      ${config.iris.baseUrl}
  Press Ctrl+C to stop
================================================================
  `);
});

export { app, registry };
