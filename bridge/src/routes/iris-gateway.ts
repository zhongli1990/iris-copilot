/**
 * Generic capability gateway routes (additive, feature-flagged).
 */

import { Router, Request, Response } from 'express';
import { IRISClient } from '../iris/iris-client.js';
import { config } from '../config.js';
import type { GenericOperateRequest } from '../iris/operate-contract.js';

function getIrisApiBaseUrl(): string {
  const base = config.iris.baseUrl.replace(/\/$/, '');
  if (base.endsWith('/ai')) return base;
  return `${base}/ai`;
}

export function createIrisGatewayRouter(): Router {
  const router = Router();
  const irisClient = new IRISClient(getIrisApiBaseUrl());

  router.get('/capabilities', async (req: Request, res: Response) => {
    if (!config.genericOperate.enabled) {
      res.status(503).json({
        status: 'disabled',
        message: 'Generic operate gateway disabled by configuration.',
        remediation: 'Set GENERIC_OPERATE_ENABLED=1 in bridge/.env and restart bridge.',
      });
      return;
    }
    try {
      const namespace = typeof req.query.namespace === 'string' ? req.query.namespace : undefined;
      const data = await irisClient.getCapabilities(namespace);
      res.json(data);
    } catch (err) {
      res.status(500).json({
        status: 'error',
        error: err instanceof Error ? err.message : String(err),
      });
    }
  });

  router.post('/operate', async (req: Request, res: Response) => {
    if (!config.genericOperate.enabled) {
      res.status(503).json({
        status: 'disabled',
        message: 'Generic operate gateway disabled by configuration.',
        remediation: 'Set GENERIC_OPERATE_ENABLED=1 in bridge/.env and restart bridge.',
      });
      return;
    }
    try {
      const body = (req.body || {}) as GenericOperateRequest;
      if (!body.op || !body.target) {
        res.status(400).json({ status: 'error', error: 'Fields op and target are required.' });
        return;
      }
      const data = await irisClient.operate(body);
      res.json(data);
    } catch (err) {
      res.status(500).json({
        status: 'error',
        error: err instanceof Error ? err.message : String(err),
      });
    }
  });

  return router;
}
