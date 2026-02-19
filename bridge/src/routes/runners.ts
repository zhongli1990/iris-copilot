/**
 * Runner management routes.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import { Router, Request, Response } from 'express';
import type { RunnerRegistry } from '../runners/runner-registry.js';

export function createRunnersRouter(registry: RunnerRegistry): Router {
  const router = Router();

  /** GET /api/runners — List all registered runners with health status */
  router.get('/', async (_req: Request, res: Response) => {
    try {
      const summary = await registry.getSummary();
      res.json(summary);
    } catch (err) {
      res.status(500).json({ error: String(err) });
    }
  });

  /** GET /api/runners/health — Health check all runners */
  router.get('/health', async (_req: Request, res: Response) => {
    try {
      const healthMap = await registry.healthCheckAll();
      const result: Record<string, object> = {};
      for (const [id, health] of healthMap.entries()) {
        result[id] = health;
      }
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: String(err) });
    }
  });

  return router;
}
