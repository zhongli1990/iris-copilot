export type GenericOp = 'discover' | 'query' | 'mutate' | 'execute' | 'govern';

export interface GenericOperateRequest {
  requestId?: string;
  correlationId?: string;
  namespace?: string;
  op: GenericOp;
  target: string;
  action?: string;
  args?: Record<string, unknown>;
  dryRun?: boolean;
  idempotencyKey?: string;
}

export interface GenericOperateResponse {
  status: 'ok' | 'error' | 'denied';
  data?: unknown;
  error?: {
    code: string;
    message: string;
    remediation?: string;
  };
  meta?: {
    capability?: string;
    requiresApproval?: boolean;
    namespace?: string;
    executedBy?: string;
    correlationId?: string;
  };
}

export interface CapabilityEntry {
  capability: string;
  namespace?: string;
  allowed: boolean;
  reason?: string;
}
