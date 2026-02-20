/**
 * Master Orchestrator Agent.
 * Classifies user intent, selects the right AI runner, and coordinates
 * the multi-step workflow (requirements → design → generate → review).
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import type { RunnerRegistry } from '../runners/runner-registry.js';
import type { AIRunnerAdapter, RunnerChatRequest, RunnerStreamChunk } from '../runners/runner-interface.js';
import { config } from '../config.js';
import { IRISClient } from '../iris/iris-client.js';

export interface ChatInput {
  conversationId: string;
  message: string;
  namespace: string;
  productionStatus?: object;
  history?: Array<{ role: 'user' | 'assistant' | 'system'; content: string }>;
  preferredRunner?: string;
}

export interface ChatOutput {
  response: string;
  agent: string;
  runner: string;
  actions?: ActionProposal[];
  actionExecution?: {
    mode: 'direct-read' | 'approval-required';
    executedCount: number;
  };
  generation?: {
    description: string;
    classes: Array<{ className: string; classType: string; source: string }>;
  };
}

export interface ActionProposal {
  id: string;
  type: string;
  op?: 'discover' | 'query' | 'mutate' | 'execute' | 'govern';
  target?: string;
  summary: string;
  requiresApproval: boolean;
  status: 'executed' | 'pending-approval';
  endpoint?: string;
  method?: 'GET' | 'POST';
  payload?: Record<string, unknown>;
}

interface ActionCatalogEntry {
  type: string;
  op?: 'discover' | 'query' | 'mutate' | 'execute' | 'govern';
  target?: string;
  endpoint: string;
  method: 'GET' | 'POST';
  requiresApproval: boolean;
  description: string;
}

interface PlannerDecision {
  mode: 'respond' | 'actions';
  response: string;
  actions?: ActionProposal[];
}

/**
 * Intent categories the orchestrator can classify.
 */
type Intent =
  | 'new_integration'    // User wants to build a new integration route
  | 'modify_integration' // User wants to change an existing integration
  | 'monitor'            // User wants to check health/status/errors
  | 'explain'            // User wants to understand existing code/config
  | 'test'               // User wants to run or create tests
  | 'rollback'           // User wants to undo a deployment
  | 'general'            // General question or conversation
  ;

export class Orchestrator {
  private registry: RunnerRegistry;
  private irisClient: IRISClient;

  constructor(registry: RunnerRegistry) {
    this.registry = registry;
    this.irisClient = new IRISClient(this.getIrisApiBaseUrl());
  }

  /**
   * Process a user message and return the full response.
   */
  async processMessage(input: ChatInput): Promise<ChatOutput> {
    // Select the best available runner for chat
    const preferred = input.preferredRunner || config.defaultRunner;
    const runner = this.registry.select({ capability: 'chat', preferred })
                || this.registry.select({ capability: 'chat' });

    if (!runner) {
      return {
        response: 'No AI runners are available. Please configure at least one API key (Anthropic or OpenAI) in the bridge configuration.',
        agent: 'orchestrator',
        runner: 'none',
      };
    }

    // Classify intent to enrich the system prompt
    const intent = this.classifyIntent(input.message);

    // Deterministic direct operations first for explicit actionable asks
    // (e.g., dry-run host mutations, class catalog queries with patterns).
    if (this.parseDirectGenericAction(input.message)) {
      const direct = await this.tryHandleActionableRequest(input);
      if (direct) return direct;
    }

    // Model-first action planning: use Claude/Codex to decide actions or plain response.
    const planned = await this.tryModelPlannedActions(input, intent, runner);
    if (planned) {
      return planned;
    }

    // Fallback deterministic action handling (legacy safety net).
    const actionResult = await this.tryHandleActionableRequest(input);
    if (actionResult) {
      return actionResult;
    }

    // Build the request with IRIS context
    const request: RunnerChatRequest = {
      message: input.message,
      systemPrompt: this.buildSystemPrompt(intent, input),
      history: input.history || [],
    };

    // Get response from AI
    const response = await runner.chat(request);

    const output: ChatOutput = {
      response: response.content,
      agent: `orchestrator/${intent}`,
      runner: runner.id,
    };

    // If the intent suggests code generation, check if the response contains ObjectScript
    if ((intent === 'new_integration' || intent === 'modify_integration') && this.containsCode(response.content)) {
      const classes = this.extractClasses(response.content);
      if (classes.length > 0) {
        output.generation = {
          description: `Generated ${classes.length} class(es) for: ${input.message.substring(0, 100)}`,
          classes,
        };
      }
    }

    return output;
  }

  /**
   * Process a message and stream the response token by token.
   */
  async *processMessageStream(input: ChatInput): AsyncGenerator<RunnerStreamChunk> {
    const preferred = input.preferredRunner || config.defaultRunner;
    const runner = this.registry.select({ capability: 'chat', preferred })
                || this.registry.select({ capability: 'chat' });

    if (!runner) {
      yield { token: 'No AI runners available. Configure API keys in .env.', done: true };
      return;
    }

    const intent = this.classifyIntent(input.message);

    if (this.parseDirectGenericAction(input.message)) {
      const direct = await this.tryHandleActionableRequest(input);
      if (direct) {
        yield { token: '', done: false, runner: direct.runner };
        yield { token: direct.response, done: false };
        yield { token: '', done: true };
        return;
      }
    }

    const planned = await this.tryModelPlannedActions(input, intent, runner);
    if (planned) {
      yield { token: '', done: false, runner: planned.runner };
      yield { token: planned.response, done: false };
      yield { token: '', done: true };
      return;
    }

    const actionResult = await this.tryHandleActionableRequest(input);
    if (actionResult) {
      yield { token: '', done: false, runner: actionResult.runner };
      yield { token: actionResult.response, done: false };
      yield { token: '', done: true };
      return;
    }
    // Emit runner attribution first so UI can show exactly which runner is active.
    yield { token: '', done: false, runner: runner.id };
    const request: RunnerChatRequest = {
      message: input.message,
      systemPrompt: this.buildSystemPrompt(intent, input),
      history: input.history || [],
    };

    yield* runner.chatStream(request);
  }

  private async tryModelPlannedActions(input: ChatInput, intent: Intent, runner: AIRunnerAdapter): Promise<ChatOutput | null> {
    try {
      const plannerRequest: RunnerChatRequest = {
        message: this.buildPlannerUserPrompt(input),
        history: [],
        systemPrompt: await this.buildPlannerSystemPrompt(intent, input),
      };
      const raw = await runner.chat(plannerRequest);
      const parsed = this.parsePlannerDecision(raw.content);
      if (!parsed || parsed.mode !== 'actions' || !parsed.actions || parsed.actions.length === 0) {
        return null;
      }

      const normalized = this.normalizePlannedActions(parsed.actions);
      if (normalized.length === 0) return null;

      let executedCount = 0;
      const executedNotes: string[] = [];
      const executedBlocks: string[] = [];
      for (const action of normalized) {
        if (action.requiresApproval) {
          action.status = 'pending-approval';
          continue;
        }
        const canDirectRead = action.op === 'query' || action.op === 'discover' || action.method === 'GET';
        if (canDirectRead && (action.target || action.endpoint)) {
          try {
            let data: unknown;
            if (config.genericOperate.enabled && action.target && (action.op === 'query' || action.op === 'discover')) {
              const opResult = await this.irisClient.operate({
                namespace: input.namespace,
                op: action.op,
                target: action.target,
                action: 'read',
                args: action.payload || {},
                dryRun: false,
              });
              data = this.unwrapData(opResult);
            } else if (action.endpoint) {
              data = this.unwrapData(await this.irisClient.request('GET', action.endpoint));
            } else {
              throw new Error('No target or endpoint available for direct read action.');
            }
            action.status = 'executed';
            executedCount++;
            const summary = this.summarizeReadResult(action.type, action.target, data);
            if (summary) executedNotes.push(summary);
            const block = this.buildReadResponseBlock(action.type, action.target, data, input.message);
            if (block) executedBlocks.push(block);
          } catch (err) {
            action.status = 'pending-approval';
            const label = action.target || action.type;
            executedNotes.push(`Read action failed (${label}): ${err instanceof Error ? err.message : String(err)}`);
          }
        }
      }

      const responseLines: string[] = [];
      if (parsed.response?.trim()) {
        responseLines.push(parsed.response.trim());
      } else {
        responseLines.push('Action plan generated from your request.');
      }
      if (executedBlocks.length > 0) {
        responseLines.push('');
        responseLines.push(...executedBlocks);
      }
      if (executedNotes.length > 0) {
        responseLines.push('');
        responseLines.push('Execution results:');
        responseLines.push(...executedNotes.map(s => `- ${s}`));
      }
      if (normalized.some(a => a.requiresApproval)) {
        responseLines.push('');
        responseLines.push('Pending approval actions are ready for `/api/actions/approve`.');
      }

      return {
        response: this.cleanMechanicalPrompting(responseLines.join('\n')),
        agent: 'orchestrator/model-action-broker',
        runner: runner.id,
        actions: normalized,
        actionExecution: {
          mode: normalized.some(a => a.requiresApproval) ? 'approval-required' : 'direct-read',
          executedCount,
        },
      };
    } catch {
      return null;
    }
  }

  private getIrisApiBaseUrl(): string {
    const base = config.iris.baseUrl.replace(/\/$/, '');
    if (base.endsWith('/ai')) return base;
    return `${base}/ai`;
  }

  private async tryHandleActionableRequest(input: ChatInput): Promise<ChatOutput | null> {
    const parsedGeneric = this.parseDirectGenericAction(input.message);
    if (parsedGeneric?.action.op && parsedGeneric.action.target) {
      const isRead = parsedGeneric.action.op === 'query' || parsedGeneric.action.op === 'discover';
      const dryRun = parsedGeneric.dryRun;
      if (isRead || dryRun) {
        try {
          const opResult = await this.irisClient.operate({
            namespace: input.namespace,
            op: parsedGeneric.action.op,
            target: parsedGeneric.action.target,
            action: isRead ? 'read' : 'apply',
            args: (parsedGeneric.action.payload?.args || parsedGeneric.action.payload || {}) as Record<string, unknown>,
            dryRun,
          });
          const data = this.unwrapData(opResult);
          const lines: string[] = [];
          if (dryRun && !isRead) {
            lines.push('Dry-run executed. No production mutation was applied.');
            lines.push('');
            lines.push(`Result:\n\`\`\`json\n${JSON.stringify(data, null, 2)}\n\`\`\``);
          } else {
            const block = this.buildReadResponseBlock(parsedGeneric.action.type, parsedGeneric.action.target, data, input.message);
            lines.push(block || `Action executed: ${parsedGeneric.action.target}`);
            const summary = this.summarizeReadResult(parsedGeneric.action.type, parsedGeneric.action.target, data);
            if (summary) {
              lines.push('');
              lines.push('Execution results:');
              lines.push(`- ${summary}`);
            }
          }
          return {
            response: lines.join('\n'),
            agent: 'orchestrator/action-broker',
            runner: 'orchestrator-action-broker',
            actions: [{
              ...parsedGeneric.action,
              requiresApproval: false,
              status: 'executed',
            }],
            actionExecution: { mode: 'direct-read', executedCount: 1 },
          };
        } catch (err) {
          return {
            response: `I could not execute the requested operation. Error: ${err instanceof Error ? err.message : String(err)}`,
            agent: 'orchestrator/action-broker',
            runner: 'orchestrator-action-broker',
          };
        }
      }

      return {
        response: [
          'Execution plan prepared. No production changes were executed yet.',
          'Human approval is required before applying this mutation.',
          'Proposed actions:',
          `- ${parsedGeneric.action.summary}`,
        ].join('\n'),
        agent: 'orchestrator/action-broker',
        runner: 'orchestrator-action-broker',
        actions: [{
          ...parsedGeneric.action,
          requiresApproval: true,
          status: 'pending-approval',
        }],
        actionExecution: { mode: 'approval-required', executedCount: 0 },
      };
    }

    const action = this.detectAction(input.message);
    if (!action) return null;

    try {
      if (action === 'production_topology') {
        const raw = await this.irisClient.getProductionTopology();
        const data = this.unwrapData(raw);
        const hosts = this.extractHosts(data);
        const lines: string[] = [];
        lines.push(`Current production has ${hosts.length} configured host(s).`);
        for (const h of hosts.slice(0, 150)) {
          lines.push(`- ${h.name} | ${h.className} | ${h.category} | ${h.enabled ? 'Enabled' : 'Disabled'}`);
        }
        if (hosts.length > 150) {
          lines.push(`... ${hosts.length - 150} more host(s) not shown.`);
        }
        return {
          response: lines.join('\n'),
          agent: 'orchestrator/action-broker',
          runner: 'orchestrator-action-broker',
          actions: [{
            id: this.actionId(),
            type: 'production_topology',
            summary: 'Listed current production items from live IRIS topology endpoint.',
            requiresApproval: false,
            status: 'executed',
            endpoint: '/production/topology',
            method: 'GET',
          }],
          actionExecution: { mode: 'direct-read', executedCount: 1 },
        };
      }

      if (action === 'production_status') {
        const raw = await this.irisClient.getProductionStatus();
        const data = this.unwrapData(raw) as Record<string, unknown>;
        const summary = [
          `Production: ${String(data.productionName || 'Unknown')}`,
          `Status: ${String(data.statusText || data.status || 'Unknown')}`,
          `Namespace: ${String(data.namespace || input.namespace || 'Unknown')}`,
        ].join('\n');
        return {
          response: summary,
          agent: 'orchestrator/action-broker',
          runner: 'orchestrator-action-broker',
          actions: [{
            id: this.actionId(),
            type: 'production_status',
            summary: 'Fetched live production status from IRIS.',
            requiresApproval: false,
            status: 'executed',
            endpoint: '/production/status',
            method: 'GET',
          }],
          actionExecution: { mode: 'direct-read', executedCount: 1 },
        };
      }

      if (action === 'queue_counts') {
        const raw = await this.irisClient.getQueueCounts();
        const data = this.unwrapData(raw);
        const rows = this.extractQueueRows(data);
        const lines: string[] = [`Current queue counts (${rows.length} host(s)):`];
        for (const r of rows.slice(0, 150)) {
          lines.push(`- ${r.name}: ${r.count}`);
        }
        if (rows.length > 150) {
          lines.push(`... ${rows.length - 150} more host(s) not shown.`);
        }
        return {
          response: lines.join('\n'),
          agent: 'orchestrator/action-broker',
          runner: 'orchestrator-action-broker',
          actions: [{
            id: this.actionId(),
            type: 'queue_counts',
            summary: 'Fetched live queue depths from IRIS.',
            requiresApproval: false,
            status: 'executed',
            endpoint: '/production/queues',
            method: 'GET',
          }],
          actionExecution: { mode: 'direct-read', executedCount: 1 },
        };
      }

      if (action === 'event_log') {
        const raw = await this.irisClient.getEventLog(30);
        const data = this.unwrapData(raw);
        const events = this.extractEvents(data);
        const lines: string[] = [`Recent production events (${events.length} row(s)):`];
        for (const ev of events.slice(0, 30)) {
          lines.push(`- ${ev.when} | ${ev.level} | ${ev.source} | ${ev.message}`);
        }
        return {
          response: lines.join('\n'),
          agent: 'orchestrator/action-broker',
          runner: 'orchestrator-action-broker',
          actions: [{
            id: this.actionId(),
            type: 'event_log',
            summary: 'Fetched recent production events from IRIS.',
            requiresApproval: false,
            status: 'executed',
            endpoint: '/production/events',
            method: 'GET',
          }],
          actionExecution: { mode: 'direct-read', executedCount: 1 },
        };
      }

      if (action === 'lookup_tables') {
        const raw = await this.irisClient.listLookupTables();
        const data = this.unwrapData(raw);
        const tables = this.extractLookupTables(data);
        const lines: string[] = [`Lookup tables (${tables.length}):`];
        for (const t of tables.slice(0, 100)) {
          lines.push(`- ${t}`);
        }
        if (tables.length > 100) {
          lines.push(`... ${tables.length - 100} more table(s) not shown.`);
        }
        return {
          response: lines.join('\n'),
          agent: 'orchestrator/action-broker',
          runner: 'orchestrator-action-broker',
          actions: [{
            id: this.actionId(),
            type: 'lookup_tables',
            summary: 'Fetched lookup table list from IRIS.',
            requiresApproval: false,
            status: 'executed',
            endpoint: '/lookups',
            method: 'GET',
          }],
          actionExecution: { mode: 'direct-read', executedCount: 1 },
        };
      }

      if (action === 'approval_required') {
        const proposals = this.buildApprovalProposals(input.message);
        return {
          response: [
            'Execution plan prepared. No production changes were executed yet.',
            'Human approval is required before deployment or runtime mutations.',
            'Proposed actions:',
            ...proposals.map(p => `- ${p.summary}`),
          ].join('\n'),
          agent: 'orchestrator/action-broker',
          runner: 'orchestrator-action-broker',
          actions: proposals,
          actionExecution: { mode: 'approval-required', executedCount: 0 },
        };
      }
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      return {
        response: `I could not execute the requested IRIS action. Error: ${detail}`,
        agent: 'orchestrator/action-broker',
        runner: 'orchestrator-action-broker',
      };
    }

    return null;
  }

  private detectAction(message: string):
    | 'production_topology'
    | 'production_status'
    | 'queue_counts'
    | 'event_log'
    | 'lookup_tables'
    | 'approval_required'
    | null {
    const lower = message.toLowerCase();

    if ((/(list|show|get).*(production items|production hosts|production topology|all hosts)/.test(lower))
      || (/(current production items|list current production)/.test(lower))) {
      return 'production_topology';
    }
    if (/(production status|is .*production.*running|current production status)/.test(lower)) {
      return 'production_status';
    }
    if (/\b(queue|queues|queue depth|backlog)\b/.test(lower)) {
      return 'queue_counts';
    }
    if (/(recent errors|event log|production events|last .* errors)/.test(lower)) {
      return 'event_log';
    }
    if (/(lookup tables|list lookups|show lookups)/.test(lower)) {
      return 'lookup_tables';
    }

    if (
      /\b(approve|deploy|rollback|roll back|start production|stop production)\b/.test(lower)
      || /(create|add|connect|wire|modify|change|update).*(business service|business process|business operation|router|routing rule|transform|dtl|production|host|integration|route)/.test(lower)
    ) {
      return 'approval_required';
    }

    return null;
  }

  private buildApprovalProposals(message: string): ActionProposal[] {
    const lower = message.toLowerCase();
    const parsedGeneric = this.parseDirectGenericAction(message);
    if (parsedGeneric && parsedGeneric.action.requiresApproval) {
      return [{
        ...parsedGeneric.action,
        status: 'pending-approval',
      }];
    }
    const proposals: ActionProposal[] = [];

      if (/\b(approve|deploy)\b/.test(lower)) {
        proposals.push({
          id: this.actionId(),
          type: 'approve_deploy_generation',
          summary: 'Approve the pending generation and deploy to IRIS production.',
          requiresApproval: true,
          status: 'pending-approval',
          endpoint: '/generate/approve',
          method: 'POST',
          payload: {},
        });
      }
      if (/\b(rollback|roll back|revert|undo)\b/.test(lower)) {
        proposals.push({
          id: this.actionId(),
        type: 'rollback_version',
        summary: 'Rollback production to a selected previous version snapshot.',
          requiresApproval: true,
          status: 'pending-approval',
          endpoint: '/lifecycle/rollback/:id',
          method: 'POST',
          payload: {},
        });
      }
      if (/\b(start production)\b/.test(lower)) {
        proposals.push({
        id: this.actionId(),
        type: 'start_production',
        summary: 'Start the target production.',
          requiresApproval: true,
          status: 'pending-approval',
          endpoint: '/production/start',
          method: 'POST',
          payload: {},
        });
      }
      if (/\b(stop production)\b/.test(lower)) {
        proposals.push({
        id: this.actionId(),
        type: 'stop_production',
        summary: 'Stop the target production.',
          requiresApproval: true,
          status: 'pending-approval',
          endpoint: '/production/stop',
          method: 'POST',
          payload: {},
        });
      }
    if (proposals.length === 0) {
      proposals.push({
        id: this.actionId(),
        type: 'integration_change_plan',
        summary: 'Prepare integration change plan and require explicit approval before apply/deploy.',
        requiresApproval: true,
        status: 'pending-approval',
      });
    }
    return proposals;
  }

  private parseDirectGenericAction(message: string): { action: ActionProposal; dryRun: boolean } | null {
    const text = message || '';
    const lower = text.toLowerCase();
    const dryRun = /\bdry[- ]run(?:\s+only)?\b|\bplan only\b|\bpreview\b/.test(lower);

    const lookupMatch = text.match(/\blookup table\s+([A-Za-z0-9_.-]+)/i);
    if ((/\b(show|get|list)\b/.test(lower)) && lookupMatch && /\b(content|entries|values|table)\b/.test(lower)) {
      const tableName = lookupMatch[1];
      return {
        dryRun: false,
        action: {
          id: this.actionId(),
          type: 'lookup_read',
          op: 'query',
          target: `lookup/${tableName}`,
          summary: `Read lookup table '${tableName}' entries.`,
          requiresApproval: false,
          status: 'executed',
          payload: { args: {} },
        },
      };
    }

    const classMetaMatch = text.match(/\b(?:class\s+metadata\s+for|metadata\s+for\s+class|metadata\s+for|class)\s+([A-Za-z0-9_.%]+)/i);
    if (/\bmetadata\b/.test(lower) && classMetaMatch) {
      const className = classMetaMatch[1];
      return {
        dryRun: false,
        action: {
          id: this.actionId(),
          type: 'class_meta_read',
          op: 'query',
          target: `classmeta/${className}`,
          summary: `Read metadata for class '${className}'.`,
          requiresApproval: false,
          status: 'executed',
          payload: { args: {} },
        },
      };
    }

    if (/\b(invoke policy|invocation policy)\b/.test(lower)) {
      return {
        dryRun: false,
        action: {
          id: this.actionId(),
          type: 'invoke_policy_read',
          op: 'discover',
          target: 'invoke-policy',
          summary: 'Read current generic class invocation policy.',
          requiresApproval: false,
          status: 'executed',
          payload: { args: {} },
        },
      };
    }

    if (/\blist classes\b|\bshow classes\b|\bclass list\b/.test(lower)) {
      const pattern = this.extractClassPattern(text);
      return {
        dryRun: false,
        action: {
          id: this.actionId(),
          type: 'dictionary_classes_read',
          op: 'query',
          target: 'dictionary/classes',
          summary: `List classes matching pattern '${pattern}'.`,
          requiresApproval: false,
          status: 'executed',
          payload: { args: { pattern, maxRows: 500 } },
        },
      };
    }

    const hostNameMatch = text.match(/\b(?:named|called)\s+([A-Za-z0-9_.-]+)/i);
    if (/\badd\b.*\bbusiness host\b/.test(lower) && hostNameMatch) {
      const hostName = hostNameMatch[1];
      let className = 'Ens.BusinessService';
      if (/\bbusiness process\b|\bprocess\b/.test(lower)) className = 'Ens.BusinessProcessBPL';
      if (/\bbusiness operation\b|\boperation\b/.test(lower)) className = 'Ens.BusinessOperation';
      const enabled = !/\bdisabled\b/.test(lower);
      return {
        dryRun,
        action: {
          id: this.actionId(),
          type: 'add_production_host',
          op: 'mutate',
          target: 'production/host/add',
          summary: `Add host '${hostName}' (${className}), enabled=${enabled ? 'true' : 'false'}.`,
          requiresApproval: true,
          status: 'pending-approval',
          payload: {
            args: {
              config: {
                name: hostName,
                className,
                category: 'AIGenerated',
                enabled,
              },
            },
          },
        },
      };
    }

    if ((/\bremove\b|\bdelete\b/.test(lower)) && /\bbusiness host\b/.test(lower) && hostNameMatch) {
      const hostName = hostNameMatch[1];
      return {
        dryRun,
        action: {
          id: this.actionId(),
          type: 'remove_production_host',
          op: 'mutate',
          target: 'production/host/remove',
          summary: `Remove host '${hostName}'.`,
          requiresApproval: true,
          status: 'pending-approval',
          payload: { args: { name: hostName } },
        },
      };
    }

    return null;
  }

  private extractClassPattern(message: string): string {
    const pkgMatch = message.match(/\b(?:in|under|from)\s+(?:the\s+)?([A-Za-z0-9_.%*]+)\s*(?:packages?|package)?/i);
    if (!pkgMatch) return 'AIAgent.%';
    let raw = pkgMatch[1].trim();
    raw = raw.replace(/\*/g, '%');
    if (!raw.includes('%')) {
      raw = raw.endsWith('.') ? `${raw}%` : `${raw}.%`;
    }
    return raw;
  }

  private actionId(): string {
    return `act-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  }

  private unwrapData(raw: unknown): unknown {
    let current: unknown = raw;
    for (let i = 0; i < 4; i++) {
      if (!current || typeof current !== 'object') break;
      const obj = current as Record<string, unknown>;
      if (obj.status === 'ok' && obj.data !== undefined) {
        current = obj.data;
        continue;
      }
      // Generic /ai/operate envelope shape: { data: <payload>, meta: {...}, dryRun: ... }
      if (obj.data !== undefined && (obj.meta !== undefined || obj.dryRun !== undefined)) {
        current = obj.data;
        continue;
      }
      break;
    }
    return current;
  }

  private extractHosts(raw: unknown): Array<{ name: string; className: string; category: string; enabled: boolean }> {
    const arr = this.extractArray(raw, ['hosts', 'items', 'productionItems', 'businessHosts']);
    return arr.map((item: unknown) => {
      const it = (item || {}) as Record<string, unknown>;
      return {
        name: String(it.name || it.Name || it.configName || 'Unknown'),
        className: String(it.className || it.ClassName || 'Unknown'),
        category: String(it.category || it.Category || it.businessType || 'Unknown'),
        enabled: Boolean(it.enabled ?? it.Enabled ?? false),
      };
    });
  }

  private extractQueueRows(raw: unknown): Array<{ name: string; count: number }> {
    const arr = this.extractArray(raw, ['queues', 'items', 'hosts']);
    return arr.map((item: unknown) => {
      const it = (item || {}) as Record<string, unknown>;
      const countRaw = it.count ?? it.queueCount ?? it.depth ?? it.QueueCount ?? 0;
      const parsed = Number(countRaw);
      return {
        name: String(it.name || it.Name || it.host || 'Unknown'),
        count: Number.isFinite(parsed) ? parsed : 0,
      };
    });
  }

  private extractEvents(raw: unknown): Array<{ when: string; level: string; source: string; message: string }> {
    const arr = this.extractArray(raw, ['events', 'items', 'rows']);
    return arr.map((item: unknown) => {
      const it = (item || {}) as Record<string, unknown>;
      return {
        when: String(it.time || it.timestamp || it.TimeLogged || ''),
        level: String(it.level || it.severity || it.Type || ''),
        source: String(it.source || it.host || it.Source || ''),
        message: String(it.message || it.text || it.Description || ''),
      };
    });
  }

  private extractLookupTables(raw: unknown): string[] {
    const arr = this.extractArray(raw, ['tables', 'items', 'lookups']);
    return arr.map((item: unknown) => {
      if (typeof item === 'string') return item;
      const it = (item || {}) as Record<string, unknown>;
      return String(it.name || it.tableName || it.Name || 'Unknown');
    });
  }

  private extractArray(raw: unknown, keys: string[]): unknown[] {
    if (Array.isArray(raw)) return raw;
    if (!raw || typeof raw !== 'object') return [];
    const obj = raw as Record<string, unknown>;
    for (const key of keys) {
      const candidate = obj[key];
      if (Array.isArray(candidate)) return candidate;
    }
    return [];
  }

  private async buildPlannerSystemPrompt(intent: Intent, input: ChatInput): Promise<string> {
    let capabilities = '';
    if (config.genericOperate.enabled) {
      try {
        const cap = await this.irisClient.getCapabilities(input.namespace);
        capabilities = JSON.stringify(this.unwrapData(cap));
      } catch {
        capabilities = '';
      }
    }
    return [
      'You are IRIS Copilot action planner.',
      'Decide whether to respond conversationally or output executable action proposals.',
      'Return ONLY JSON. No markdown, no prose outside JSON.',
      'JSON schema:',
      '{"mode":"respond|actions","response":"string","actions":[{"id":"string","type":"string","op":"discover|query|mutate|execute|govern","target":"string","summary":"string","requiresApproval":true|false,"endpoint":"/path","method":"GET|POST","payload":{}}]}',
      'Rules:',
      '- Use actions only when the user asks for real environment operations.',
      '- For read-only queries, prefer actions with op=query or op=discover and a concrete target.',
      '- For mutating/deployment actions, requiresApproval=true.',
      '- Do NOT ask for extra confirmation for read-only actions; execute via action broker immediately.',
      '- Prefer generic op+target actions. Endpoint/method are optional compatibility fields.',
      `Intent: ${intent}`,
      `Namespace: ${input.namespace}`,
      capabilities ? `Capabilities: ${capabilities}` : '',
      `Action catalog: ${JSON.stringify(ACTION_CATALOG)}`,
    ].join('\n');
  }

  private buildPlannerUserPrompt(input: ChatInput): string {
    const history = (input.history || []).slice(-8)
      .map(h => `${h.role.toUpperCase()}: ${h.content}`)
      .join('\n');
    return [
      `User request: ${input.message}`,
      history ? `Recent conversation:\n${history}` : '',
    ].filter(Boolean).join('\n\n');
  }

  private parsePlannerDecision(text: string): PlannerDecision | null {
    const trimmed = (text || '').trim();
    if (!trimmed) return null;
    const direct = this.tryParseJson(trimmed);
    if (direct) return direct;
    const first = trimmed.indexOf('{');
    const last = trimmed.lastIndexOf('}');
    if (first !== -1 && last > first) {
      const extracted = trimmed.substring(first, last + 1);
      return this.tryParseJson(extracted);
    }
    return null;
  }

  private tryParseJson(text: string): PlannerDecision | null {
    try {
      const obj = JSON.parse(text) as PlannerDecision;
      if (!obj || typeof obj !== 'object') return null;
      if (obj.mode !== 'respond' && obj.mode !== 'actions') return null;
      if (typeof obj.response !== 'string') obj.response = '';
      return obj;
    } catch {
      return null;
    }
  }

  private normalizePlannedActions(actions: ActionProposal[]): ActionProposal[] {
    const normalized: ActionProposal[] = [];
    const validOps = new Set(['discover', 'query', 'mutate', 'execute', 'govern']);
    for (const a of actions) {
      const endpoint = a.endpoint || '';
      const method = (a.method || 'GET') as 'GET' | 'POST';
      const entry = ACTION_CATALOG.find(e =>
        (a.type && e.type === a.type) || (endpoint && e.endpoint === endpoint && e.method === method)
      );
      const op = a.op || entry?.op;
      const target = a.target || entry?.target;
      const hasGenericShape = !!(op && validOps.has(op) && target && target.trim().length > 0);
      if (!entry && !hasGenericShape) continue;

      const requiresApproval = hasGenericShape
        ? (op === 'mutate' || op === 'execute' || op === 'govern')
        : !!entry?.requiresApproval;

      normalized.push({
        id: a.id || this.actionId(),
        type: a.type || entry?.type || `${op}:${target}`,
        op,
        target,
        summary: a.summary || entry?.description || `${op}:${target}`,
        requiresApproval,
        status: requiresApproval ? 'pending-approval' : 'executed',
        endpoint: a.endpoint || entry?.endpoint,
        method: a.method || entry?.method,
        payload: a.payload || {},
      });
    }
    return normalized;
  }

  private summarizeReadResult(type: string, target: string | undefined, data: unknown): string {
    const resolvedType = this.resolveReadType(type, target);
    switch (resolvedType) {
      case 'production_status': {
        const d = (data || {}) as Record<string, unknown>;
        return `Production status: ${String(d.statusText || d.status || 'unknown')} (${String(d.productionName || 'unknown')})`;
      }
      case 'production_topology': {
        const hosts = this.extractHosts(data);
        return `Production topology read: ${hosts.length} host(s).`;
      }
      case 'queue_counts': {
        const rows = this.extractQueueRows(data);
        return `Queue snapshot read: ${rows.length} host(s).`;
      }
      case 'event_log': {
        const rows = this.extractEvents(data);
        return `Recent event log read: ${rows.length} row(s).`;
      }
      case 'lookup_tables': {
        const rows = this.extractLookupTables(data);
        return `Lookup table list read: ${rows.length} table(s).`;
      }
      case 'hl7schemas_read': {
        const rows = this.extractArray(data, ['items', 'schemas', 'data']);
        return `HL7 schema catalog read: ${rows.length} schema item(s).`;
      }
      case 'sql_read': {
        const d = (data || {}) as Record<string, unknown>;
        const rowCount = Number(d.rowCount || this.extractArray(d.rows, ['rows']).length || 0);
        return `SQL read executed: ${rowCount} row(s).`;
      }
      case 'class_meta_read': {
        const d = (data || {}) as Record<string, unknown>;
        const m = this.extractArray(d.methods, ['methods']).length;
        const p = this.extractArray(d.properties, ['properties']).length;
        return `Class metadata read: ${String(d.className || 'unknown')} (${m} method(s), ${p} propert(ies)).`;
      }
      case 'dictionary_classes_read': {
        const rows = this.extractArray(data, ['items', 'rows', 'data']);
        return `Dictionary class catalog read: ${rows.length} class(es).`;
      }
      case 'invoke_policy_read': {
        return 'Invocation policy read.';
      }
      default:
        return `${target || type} executed.`;
    }
  }

  private buildReadResponseBlock(type: string, target: string | undefined, data: unknown, userMessage: string): string {
    const resolvedType = this.resolveReadType(type, target);
    const lower = (userMessage || '').toLowerCase();
    if (resolvedType === 'production_topology') {
      const hosts = this.extractHosts(data);
      if (hosts.length === 0) return 'No production hosts were returned.';
      const namesOnly = /\b(names?|host names?|just.*names?)\b/.test(lower);
      const fullDetails = /\b(full|detail|all fields|full detail)\b/.test(lower);
      const lines: string[] = [];
      lines.push(`Production hosts (${hosts.length}):`);
      for (const h of hosts) {
        if (namesOnly && !fullDetails) {
          lines.push(`- ${h.name}`);
        } else {
          lines.push(`- ${h.name} | ${h.className} | ${h.category} | ${h.enabled ? 'Enabled' : 'Disabled'}`);
        }
      }
      return lines.join('\n');
    }
    if (resolvedType === 'production_status') {
      const d = (data || {}) as Record<string, unknown>;
      return [
        'Production status:',
        `- Name: ${String(d.productionName || 'Unknown')}`,
        `- Status: ${String(d.statusText || d.status || 'Unknown')}`,
        `- Namespace: ${String(d.namespace || 'Unknown')}`,
      ].join('\n');
    }
    if (resolvedType === 'queue_counts') {
      const rows = this.extractQueueRows(data);
      if (rows.length === 0) return 'No queue rows were returned.';
      const lines: string[] = [`Queue counts (${rows.length} host(s)):`];
      for (const r of rows) lines.push(`- ${r.name}: ${r.count}`);
      return lines.join('\n');
    }
    if (resolvedType === 'event_log') {
      const rows = this.extractEvents(data);
      if (rows.length === 0) return 'No recent event rows were returned.';
      const lines: string[] = [`Recent events (${rows.length}):`];
      for (const e of rows.slice(0, 50)) {
        lines.push(`- ${e.when} | ${e.level} | ${e.source} | ${e.message}`);
      }
      return lines.join('\n');
    }
    if (resolvedType === 'lookup_tables') {
      const rows = this.extractLookupTables(data);
      if (rows.length === 0) return 'No lookup tables were returned.';
      const lines: string[] = [`Lookup tables (${rows.length}):`];
      for (const t of rows) lines.push(`- ${t}`);
      return lines.join('\n');
    }
    if (resolvedType === 'lookup_read') {
      const d = (data || {}) as Record<string, unknown>;
      const tableName = String(d.tableName || 'Unknown');
      const entries = this.extractArray(d.entries, ['items']);
      if (entries.length === 0) return `Lookup table ${tableName} has no entries.`;
      const lines: string[] = [`Lookup table ${tableName} entries (${entries.length}):`];
      for (const e of entries.slice(0, 300)) {
        const it = (e || {}) as Record<string, unknown>;
        lines.push(`- ${String(it.name || it.key || it.Name || '')} => ${String(it.value || it.Value || '')}`);
      }
      return lines.join('\n');
    }
    if (resolvedType === 'hl7schemas_read') {
      const rows = this.extractArray(data, ['items', 'schemas', 'data']);
      if (rows.length === 0) return 'No HL7 schemas were returned.';
      const lines: string[] = [`HL7 schemas (${rows.length}):`];
      for (const r of rows.slice(0, 300)) {
        if (typeof r === 'string') {
          lines.push(`- ${r}`);
        } else {
          const it = (r || {}) as Record<string, unknown>;
          lines.push(`- ${String(it.name || it.schema || it.SchemaName || 'Unknown')}`);
        }
      }
      return lines.join('\n');
    }
    if (resolvedType === 'sql_read') {
      const d = (data || {}) as Record<string, unknown>;
      const rows = this.extractArray(d.rows, ['rows', 'items', 'data']);
      const rowCount = Number(d.rowCount || rows.length || 0);
      if (rows.length === 0) return `SQL query returned ${rowCount} row(s).`;
      const lines: string[] = [`SQL result (${rowCount} row(s)):`];
      for (const r of rows.slice(0, 25)) {
        lines.push(`- ${JSON.stringify(r)}`);
      }
      if (rows.length > 25) lines.push(`... ${rows.length - 25} more row(s) omitted.`);
      return lines.join('\n');
    }
    if (resolvedType === 'class_meta_read') {
      const d = (data || {}) as Record<string, unknown>;
      const methods = this.extractArray(d.methods, ['methods']);
      const properties = this.extractArray(d.properties, ['properties']);
      const parameters = this.extractArray(d.parameters, ['parameters']);
      const lines: string[] = [
        `Class metadata: ${String(d.className || 'Unknown')}`,
        `- Super: ${String(d.super || '')}`,
        `- Methods: ${methods.length}`,
        `- Properties: ${properties.length}`,
        `- Parameters: ${parameters.length}`,
      ];
      for (const m of methods.slice(0, 30)) {
        const it = (m || {}) as Record<string, unknown>;
        lines.push(`- Method ${String(it.name || '')}(${String(it.formalSpec || '')}) -> ${String(it.returnType || '%Status')}`);
      }
      return lines.join('\n');
    }
    if (resolvedType === 'dictionary_classes_read') {
      const rows = this.extractArray(data, ['items', 'rows', 'data']);
      if (rows.length === 0) return 'No classes were returned.';
      const lines: string[] = [`Classes (${rows.length}):`];
      for (const r of rows.slice(0, 200)) {
        const it = (r || {}) as Record<string, unknown>;
        lines.push(`- ${String(it.name || '')} | ${String(it.super || '')}`);
      }
      if (rows.length > 200) lines.push(`... ${rows.length - 200} more class(es) omitted.`);
      return lines.join('\n');
    }
    if (resolvedType === 'invoke_policy_read') {
      const d = (data || {}) as Record<string, unknown>;
      return [
        'Invocation policy:',
        `- Mode: ${String(d.mode || 'unknown')}`,
        `- Max arguments: ${String(d.maxArguments || '')}`,
      ].join('\n');
    }
    if (data && typeof data === 'object') {
      return `Result:\n\`\`\`json\n${JSON.stringify(data, null, 2)}\n\`\`\``;
    }
    return '';
  }

  private resolveReadType(type: string, target?: string): string {
    const t = (target || '').toLowerCase();
    if (t === 'production/status') return 'production_status';
    if (t === 'production/topology') return 'production_topology';
    if (t === 'production/queues') return 'queue_counts';
    if (t === 'production/events') return 'event_log';
    if (t === 'lookups') return 'lookup_tables';
    if (t.startsWith('lookup/')) return 'lookup_read';
    if (t === 'hl7schemas') return 'hl7schemas_read';
    if (t === 'sql/select') return 'sql_read';
    if (t.startsWith('classmeta/')) return 'class_meta_read';
    if (t === 'dictionary/classes') return 'dictionary_classes_read';
    if (t === 'invoke-policy') return 'invoke_policy_read';
    if (t === 'discover/invoke-policy') return 'invoke_policy_read';
    if (type && type !== 'unknown') return type;
    return type || 'unknown';
  }

  private cleanMechanicalPrompting(text: string): string {
    if (!text) return text;
    return text
      .replace(/\b(Want me to proceed\?|Proceed\?)\b/gi, '')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  /**
   * Classify the user's intent based on message content.
   */
  private classifyIntent(message: string): Intent {
    const lower = message.toLowerCase();

    // Rollback
    if (lower.includes('roll back') || lower.includes('rollback') || lower.includes('undo') || lower.includes('revert')) {
      return 'rollback';
    }
    // Monitor / Status
    if (lower.includes('status') || lower.includes('running') || lower.includes('error') || lower.includes('queue')
        || lower.includes('how is') || lower.includes('how are') || lower.includes('health')) {
      return 'monitor';
    }
    // Explain
    if (lower.includes('explain') || lower.includes('what does') || lower.includes('how does')
        || lower.includes('show me') || lower.includes('describe')) {
      return 'explain';
    }
    // Test
    if (lower.includes('test') || lower.includes('run test') || lower.includes('unit test') || lower.includes('validate')) {
      return 'test';
    }
    // Modify
    if (lower.includes('change') || lower.includes('modify') || lower.includes('update') || lower.includes('add to')
        || lower.includes('remove from') || lower.includes('edit') || lower.includes('also send')) {
      return 'modify_integration';
    }
    // New integration (keywords: need, create, build, set up, receive, send, forward, integrate, connect)
    if (lower.includes('need') || lower.includes('create') || lower.includes('build') || lower.includes('set up')
        || lower.includes('receive') || lower.includes('forward') || lower.includes('integrate')
        || lower.includes('connect') || lower.includes('new') || lower.includes('implement')
        || lower.includes('hl7') || lower.includes('adt') || lower.includes('oru') || lower.includes('rde')) {
      return 'new_integration';
    }

    return 'general';
  }

  /**
   * Build the system prompt enriched with intent-specific context.
   */
  private buildSystemPrompt(intent: Intent, input: ChatInput): string {
    let prompt = ORCHESTRATOR_BASE_PROMPT;

    // Add intent-specific instructions
    switch (intent) {
      case 'new_integration':
        prompt += NEW_INTEGRATION_PROMPT;
        break;
      case 'modify_integration':
        prompt += MODIFY_INTEGRATION_PROMPT;
        break;
      case 'monitor':
        prompt += MONITOR_PROMPT;
        break;
      case 'explain':
        prompt += EXPLAIN_PROMPT;
        break;
      case 'test':
        prompt += TEST_PROMPT;
        break;
      case 'rollback':
        prompt += ROLLBACK_PROMPT;
        break;
    }

    // Add production context if available
    if (input.productionStatus) {
      prompt += `\n\n## Current Production Status\n${JSON.stringify(input.productionStatus, null, 2)}`;
    }

    prompt += `\n\n## Current Namespace: ${input.namespace}`;
    return prompt;
  }

  /** Check if the AI response contains ObjectScript class definitions */
  private containsCode(content: string): boolean {
    return content.includes('Class ') && content.includes('Extends ') && content.includes('{');
  }

  /** Extract ObjectScript class definitions from the AI response */
  private extractClasses(content: string): Array<{ className: string; classType: string; source: string }> {
    const classes: Array<{ className: string; classType: string; source: string }> = [];
    // Match Class <name> Extends <super> { ... }
    const classRegex = /^(Class\s+[\w.]+\s+Extends\s+[\w.%]+(?:\s*\[.*?\])?\s*\{[\s\S]*?^\})/gm;
    let match;
    while ((match = classRegex.exec(content)) !== null) {
      const source = match[1].trim();
      const nameMatch = source.match(/^Class\s+([\w.]+)/);
      const extendsMatch = source.match(/Extends\s+([\w.%]+)/);
      if (nameMatch) {
        const className = nameMatch[1];
        const superClass = extendsMatch ? extendsMatch[1] : '';
        let classType = 'Other';
        if (superClass.includes('BusinessService') || superClass.includes('TCPService')) classType = 'BusinessService';
        else if (superClass.includes('BusinessProcessBPL') || superClass.includes('BusinessProcess')) classType = 'BusinessProcess';
        else if (superClass.includes('BusinessOperation')) classType = 'BusinessOperation';
        else if (superClass.includes('DataTransformDTL')) classType = 'Transform';
        else if (superClass.includes('Rule.Definition')) classType = 'RoutingRule';
        else if (superClass.includes('Request') || superClass.includes('Response') || superClass.includes('Persistent')) classType = 'Message';
        else if (superClass.includes('TestCase')) classType = 'Test';

        classes.push({ className, classType, source });
      }
    }
    return classes;
  }
}

// ============================================================
// System Prompts
// ============================================================

const ACTION_CATALOG: ActionCatalogEntry[] = [
  { type: 'production_status', op: 'query', target: 'production/status', endpoint: '/production/status', method: 'GET', requiresApproval: false, description: 'Read live production status' },
  { type: 'production_topology', op: 'query', target: 'production/topology', endpoint: '/production/topology', method: 'GET', requiresApproval: false, description: 'Read current production topology and items' },
  { type: 'queue_counts', op: 'query', target: 'production/queues', endpoint: '/production/queues', method: 'GET', requiresApproval: false, description: 'Read live queue counts' },
  { type: 'event_log', op: 'query', target: 'production/events', endpoint: '/production/events', method: 'GET', requiresApproval: false, description: 'Read recent production events' },
  { type: 'lookup_tables', op: 'query', target: 'lookups', endpoint: '/lookups', method: 'GET', requiresApproval: false, description: 'Read lookup table catalog' },
  { type: 'lookup_read', op: 'query', target: 'lookup/ErrorCodes', endpoint: '/lookups/ErrorCodes', method: 'GET', requiresApproval: false, description: 'Read a lookup table content (set target to lookup/<TableName>)' },
  { type: 'hl7schemas_read', op: 'query', target: 'hl7schemas', endpoint: '/hl7schemas', method: 'GET', requiresApproval: false, description: 'Read HL7 schema catalog' },
  { type: 'dictionary_classes_read', op: 'query', target: 'dictionary/classes', endpoint: '/operate', method: 'POST', requiresApproval: false, description: 'Read dictionary class catalog (args.pattern, args.maxRows)' },
  { type: 'class_meta_read', op: 'query', target: 'classmeta/AIAgent.API.Dispatcher', endpoint: '/operate', method: 'POST', requiresApproval: false, description: 'Read class metadata (set target to classmeta/<ClassName>)' },
  { type: 'invoke_policy_read', op: 'discover', target: 'invoke-policy', endpoint: '/operate', method: 'POST', requiresApproval: false, description: 'Read invoke policy guards' },
  { type: 'sql_read', op: 'query', target: 'sql/select', endpoint: '/sql', method: 'POST', requiresApproval: false, description: 'Run read-only SQL SELECT via generic operate args.query' },
  { type: 'approve_deploy_generation', op: 'execute', target: 'generation/approve', endpoint: '/generate/approve', method: 'POST', requiresApproval: true, description: 'Approve and deploy a generated change set' },
  { type: 'reject_generation', op: 'execute', target: 'generation/reject', endpoint: '/generate/reject', method: 'POST', requiresApproval: true, description: 'Reject a generated change set' },
  { type: 'rollback_version', op: 'execute', target: 'lifecycle/rollback', endpoint: '/lifecycle/rollback/:id', method: 'POST', requiresApproval: true, description: 'Rollback to a version snapshot' },
  { type: 'start_production', op: 'execute', target: 'production/start', endpoint: '/production/start', method: 'POST', requiresApproval: true, description: 'Start production' },
  { type: 'stop_production', op: 'execute', target: 'production/stop', endpoint: '/production/stop', method: 'POST', requiresApproval: true, description: 'Stop production' },
  { type: 'add_production_host', op: 'mutate', target: 'production/host/add', endpoint: '/operate', method: 'POST', requiresApproval: true, description: 'Add business host to production' },
  { type: 'remove_production_host', op: 'mutate', target: 'production/host/remove', endpoint: '/operate', method: 'POST', requiresApproval: true, description: 'Remove business host from production' },
  { type: 'update_production_host_settings', op: 'mutate', target: 'production/host/settings', endpoint: '/operate', method: 'POST', requiresApproval: true, description: 'Update business host settings in production' },
  { type: 'invoke_classmethod', op: 'execute', target: 'class/invoke', endpoint: '/operate', method: 'POST', requiresApproval: true, description: 'Invoke policy-approved class method with args.className, args.method, args.arguments[]' },
];

const ORCHESTRATOR_BASE_PROMPT = `You are IRIS Copilot, an AI assistant for InterSystems IRIS / HealthConnect integration lifecycle work.

You are embedded in an IRIS instance. Users interact via chat to build, modify, monitor, test, and govern integrations using natural language.

Work generically for the current namespace and production context discovered at runtime.
Do not assume any specific customer/site, production name, host naming convention, or integration topology unless explicitly provided by live API data in this session.

For generated classes, use a neutral default prefix:
AIAgent.Generated.<Domain>.<ComponentType>.<Name>

Respond in the user's language and be precise about HL7 paths, IRIS APIs, and execution/approval boundaries.`;

const NEW_INTEGRATION_PROMPT = `

## Mode: New Integration Design

The user wants to create a new clinical integration. Follow this workflow:

1. **Understand the requirement** — What system sends what message to what target?
2. **Ask clarifying questions** — HL7 version/fields, ports, business rules, error handling
3. **Design the topology** — Which components are needed (BS/BP/BO/Router/DTL/LUT)?
4. **Show how it connects** — Map to existing production hosts
5. **Generate code** — Produce complete, compilable ObjectScript classes

When you are ready to generate code, output COMPLETE ObjectScript class definitions.
Each class should be a full, compilable definition starting with "Class" and ending with "}".
Use the AIAgent.Generated.<Domain>.* naming convention.`;

const MODIFY_INTEGRATION_PROMPT = `

## Mode: Modify Existing Integration

The user wants to change an existing integration. Follow this workflow:
1. Identify which existing components need modification
2. Explain what will change and what stays the same
3. Generate the modified class with only the necessary changes
4. Note any production configuration changes needed`;

const MONITOR_PROMPT = `

## Mode: Monitor / Status Check

The user wants to check system health. Provide information about:
- Production status (running/stopped/troubled)
- Message queue depths
- Error counts and recent errors
- Specific host health
Suggest remedial actions for any issues found.`;

const EXPLAIN_PROMPT = `

## Mode: Explain

The user wants to understand existing code or configuration.
Provide clear, non-technical explanations when possible.
Reference specific class names, host names, and HL7 field paths.`;

const TEST_PROMPT = `

## Mode: Testing

The user wants to test an integration. Help with:
- Generating %UnitTest classes
- Creating synthetic HL7 test messages
- Interpreting test results
- Suggesting test scenarios`;

const ROLLBACK_PROMPT = `

## Mode: Rollback

The user wants to undo a previous deployment. Guide them through:
- Which version to roll back to
- What classes will be restored/removed
- Impact on the running production`;
