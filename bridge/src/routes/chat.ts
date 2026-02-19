/**
 * Chat routes: POST /api/chat and POST /api/chat/stream (SSE).
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import { Router, Request, Response } from 'express';
import type { RunnerRegistry } from '../runners/runner-registry.js';
import { Orchestrator } from '../agents/orchestrator.js';

export function createChatRouter(registry: RunnerRegistry): Router {
  const router = Router();
  const orchestrator = new Orchestrator(registry);

  /**
   * POST /api/chat — Send a message, get full response.
   * Body: { conversationId, message, namespace, productionStatus }
   * Returns: { response, agent, runner, generation? }
   */
  router.post('/', async (req: Request, res: Response) => {
    try {
      const { conversationId, message, namespace, productionStatus, preferredRunner } = req.body;
      if (!message) {
        res.status(400).json({ error: 'Message is required' });
        return;
      }

      const result = await orchestrator.processMessage({
        conversationId: conversationId || 'default',
        message,
        namespace: namespace || 'USER',
        productionStatus,
        preferredRunner,
      });

      res.json(result);
    } catch (err) {
      console.error('[Chat] Error:', err);
      res.status(500).json({
        error: 'Chat processing failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });

  /**
   * POST /api/chat/stream — Send a message, stream response as SSE.
   * Body: { conversationId, message, namespace, productionStatus }
   * Response: Server-Sent Events stream
   */
  router.post('/stream', async (req: Request, res: Response) => {
    try {
      const { conversationId, message, namespace, productionStatus, preferredRunner } = req.body;
      if (!message) {
        res.status(400).json({ error: 'Message is required' });
        return;
      }

      // Set SSE headers
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      res.flushHeaders();

      // Stream tokens
      const stream = orchestrator.processMessageStream({
        conversationId: conversationId || 'default',
        message,
        namespace: namespace || 'USER',
        productionStatus,
        preferredRunner,
      });

      for await (const chunk of stream) {
        res.write(`data: ${JSON.stringify(chunk)}\n\n`);
      }

      // End stream
      res.write(`data: ${JSON.stringify({ token: '', done: true })}\n\n`);
      res.end();
    } catch (err) {
      console.error('[Chat/Stream] Error:', err);
      res.write(`data: ${JSON.stringify({ error: String(err), done: true })}\n\n`);
      res.end();
    }
  });

  return router;
}
