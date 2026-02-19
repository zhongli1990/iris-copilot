/**
 * Approval-gated action execution routes.
 *
 * Phase 2: execute explicit approved actions against IRIS endpoints.
 */

import { Router, Request, Response } from 'express';
import { IRISClient } from '../iris/iris-client.js';
import { config } from '../config.js';

type ActionType =
  | 'approve_deploy_generation'
  | 'reject_generation'
  | 'rollback_version'
  | 'start_production'
  | 'stop_production'
  | 'integration_change_plan';

interface ApprovedAction {
  id?: string;
  type: ActionType | string;
  requiresApproval?: boolean;
  endpoint?: string;
  method?: 'GET' | 'POST';
  payload?: Record<string, unknown>;
}

interface ActionExecutionResult {
  id: string;
  type: string;
  success: boolean;
  status: 'executed' | 'failed' | 'skipped';
  message: string;
  data?: unknown;
}

function getIrisApiBaseUrl(): string {
  const base = config.iris.baseUrl.replace(/\/$/, '');
  if (base.endsWith('/ai')) return base;
  return `${base}/ai`;
}

function unwrapData(raw: unknown): unknown {
  if (!raw || typeof raw !== 'object') return raw;
  const obj = raw as Record<string, unknown>;
  if (obj.status === 'ok' && obj.data !== undefined) return obj.data;
  return raw;
}

function asString(value: unknown): string {
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'number') return String(value);
  return '';
}

const ACTION_ENDPOINT_MAP: Record<string, { endpoint: string; method: 'GET' | 'POST' }> = {
  approve_deploy_generation: { endpoint: '/generate/approve', method: 'POST' },
  reject_generation: { endpoint: '/generate/reject', method: 'POST' },
  rollback_version: { endpoint: '/lifecycle/rollback/:id', method: 'POST' },
  start_production: { endpoint: '/production/start', method: 'POST' },
  stop_production: { endpoint: '/production/stop', method: 'POST' },
  production_status: { endpoint: '/production/status', method: 'GET' },
  production_topology: { endpoint: '/production/topology', method: 'GET' },
  queue_counts: { endpoint: '/production/queues', method: 'GET' },
  event_log: { endpoint: '/production/events', method: 'GET' },
  lookup_tables: { endpoint: '/lookups', method: 'GET' },
};

function resolveActionEndpoint(action: ApprovedAction): { endpoint: string; method: 'GET' | 'POST' } {
  if (action.endpoint && action.method) {
    return { endpoint: action.endpoint, method: action.method };
  }
  const mapped = ACTION_ENDPOINT_MAP[action.type];
  if (!mapped) throw new Error(`Unsupported action type: ${action.type}`);
  return mapped;
}

function applyPathParams(endpoint: string, payload: Record<string, unknown> = {}): string {
  if (!endpoint.includes(':')) return endpoint;
  let resolved = endpoint;
  const matches = endpoint.match(/:[A-Za-z0-9_]+/g) || [];
  for (const token of matches) {
    const key = token.substring(1);
    const value = asString(payload[key]);
    if (!value) throw new Error(`Missing payload.${key}`);
    resolved = resolved.replace(token, encodeURIComponent(value));
  }
  return resolved;
}

export function createActionsRouter(): Router {
  const router = Router();
  const irisClient = new IRISClient(getIrisApiBaseUrl());

  /**
   * POST /api/actions/approve
   * Body: { actions: ApprovedAction[] }
   */
  router.post('/approve', async (req: Request, res: Response) => {
    try {
      const actions = Array.isArray(req.body?.actions) ? (req.body.actions as ApprovedAction[]) : [];
      if (actions.length === 0) {
        res.status(400).json({ error: 'actions[] is required' });
        return;
      }

      const results: ActionExecutionResult[] = [];
      for (const action of actions) {
        const id = action.id || `act-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
        if (action.requiresApproval === false) {
          results.push({
            id,
            type: action.type,
            success: false,
            status: 'skipped',
            message: 'Action is not marked as approval-required; skipped by /approve endpoint.',
          });
          continue;
        }

        try {
          let data: unknown;
          let message = 'Executed';
          if (action.type === 'integration_change_plan') {
            throw new Error('integration_change_plan is a planning artifact and cannot be executed directly.');
          }

          const endpointInfo = resolveActionEndpoint(action);
          const payload = action.payload || {};
          const endpoint = applyPathParams(endpointInfo.endpoint, payload);
          const body = { ...payload };
          // Remove path params from body once inlined.
          for (const token of (endpointInfo.endpoint.match(/:[A-Za-z0-9_]+/g) || [])) {
            delete body[token.substring(1)];
          }
          data = await irisClient.request(endpointInfo.method, endpoint, body);
          message = `${action.type} executed via ${endpointInfo.method} ${endpoint}`;

          results.push({
            id,
            type: action.type,
            success: true,
            status: 'executed',
            message,
            data: unwrapData(data),
          });
        } catch (err) {
          results.push({
            id,
            type: action.type,
            success: false,
            status: 'failed',
            message: err instanceof Error ? err.message : String(err),
          });
        }
      }

      const successCount = results.filter(r => r.success).length;
      const failedCount = results.filter(r => r.status === 'failed').length;
      res.json({
        status: failedCount === 0 ? 'ok' : 'partial',
        executed: successCount,
        failed: failedCount,
        results,
      });
    } catch (err) {
      res.status(500).json({
        status: 'error',
        error: err instanceof Error ? err.message : String(err),
      });
    }
  });

  return router;
}
