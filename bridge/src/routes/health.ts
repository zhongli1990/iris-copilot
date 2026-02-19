/**
 * System health check route.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import { Router, Request, Response } from 'express';
import type { RunnerRegistry } from '../runners/runner-registry.js';
import { IRISClient } from '../iris/iris-client.js';
import { config } from '../config.js';

export function createHealthRouter(registry: RunnerRegistry): Router {
  const router = Router();
  const irisClient = new IRISClient(config.iris.baseUrl);

  /** GET /api/health — Full system health check */
  router.get('/health', async (_req: Request, res: Response) => {
    try {
      // Check IRIS connectivity
      let irisHealthy = false;
      let irisError = '';
      try {
        const irisHealth = await irisClient.healthCheck();
        irisHealthy = irisHealth.status === 'ok';
      } catch (err) {
        irisError = err instanceof Error ? err.message : String(err);
      }

      // Check runners
      const healthMap = await registry.healthCheckAll();
      const runners: Record<string, string> = {};
      for (const [id, health] of healthMap.entries()) {
        runners[id] = health.healthy ? 'healthy' : `unhealthy: ${health.error || 'unknown'}`;
      }

      const allHealthy = irisHealthy && Array.from(healthMap.values()).some(h => h.healthy);

      res.json({
        status: allHealthy ? 'ok' : 'degraded',
        iris: irisHealthy,
        irisError: irisError || undefined,
        bridge: true,
        runners,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      res.status(500).json({
        status: 'error',
        bridge: true,
        error: String(err),
      });
    }
  });

  return router;
}
