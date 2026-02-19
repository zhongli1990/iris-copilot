/**
 * OpenAI Codex SDK Runner Adapter.
 * Uses the native @openai/codex-sdk thread API (not manual CLI spawning).
 */

import path from 'path';
import fs from 'fs';
import { Codex, Thread, type ThreadEvent, type ThreadOptions } from '@openai/codex-sdk';
import type {
  AIRunnerAdapter,
  RunnerCapability,
  RunnerHealth,
  RunnerChatRequest,
  RunnerChatResponse,
  RunnerStreamChunk,
  CodeGenerationSpec,
  GeneratedCode,
  CodeReview,
} from '../runner-interface.js';

export interface CodexNativeConfig {
  model: string;
  workspaceRoot: string;
  sandboxMode: 'read-only' | 'workspace-write' | 'danger-full-access';
  approvalPolicy: 'never' | 'on-request' | 'untrusted';
  additionalDirectories?: string[];
}

export class OpenAICodexSDKRunner implements AIRunnerAdapter {
  readonly id = 'openai-codex-sdk';
  readonly name = 'OpenAI Codex SDK';
  readonly capabilities: RunnerCapability[] = [
    'chat', 'chat-stream', 'code-generation', 'code-review', 'architecture', 'testing',
  ];

  private readonly model: string;
  private readonly workspaceRoot: string;
  private readonly sandboxMode: CodexNativeConfig['sandboxMode'];
  private readonly approvalPolicy: CodexNativeConfig['approvalPolicy'];
  private readonly additionalDirectories: string[];
  private readonly codex: Codex;
  private readonly threadsByConversation = new Map<string, Thread>();

  constructor(config: CodexNativeConfig) {
    this.model = config.model;
    const resolved = path.resolve(process.cwd(), config.workspaceRoot || '.');
    this.workspaceRoot = fs.existsSync(resolved) ? resolved : process.cwd();
    this.sandboxMode = config.sandboxMode;
    this.approvalPolicy = config.approvalPolicy;
    this.additionalDirectories = (config.additionalDirectories || [])
      .map(dir => path.resolve(this.workspaceRoot, dir))
      .filter(dir => fs.existsSync(dir));
    this.codex = new Codex();
  }

  async healthCheck(): Promise<RunnerHealth> {
    const start = Date.now();
    try {
      const thread = this.codex.startThread(this.threadOptions());
      const turn = await thread.run('Reply exactly with OK');
      const text = this.normalizeForIris((turn.finalResponse || '').trim());
      const healthy = text.length > 0;
      return {
        runnerId: this.id,
        healthy,
        latencyMs: Date.now() - start,
        message: healthy ? `Codex SDK reachable (${text.substring(0, 40)})` : 'Codex SDK returned an empty reply',
        model: this.model,
        checkedAt: new Date().toISOString(),
      };
    } catch (err) {
      return {
        runnerId: this.id,
        healthy: false,
        latencyMs: Date.now() - start,
        message: 'Codex SDK unavailable',
        error: err instanceof Error ? err.message : String(err),
        model: this.model,
        checkedAt: new Date().toISOString(),
      };
    }
  }

  async chat(request: RunnerChatRequest): Promise<RunnerChatResponse> {
    const thread = this.getThreadForRequest(request);
    const prompt = this.buildPrompt(request);
    const turn = await thread.run(prompt);
    const usage = turn.usage ? {
      promptTokens: Number(turn.usage.input_tokens || 0),
      completionTokens: Number(turn.usage.output_tokens || 0),
      totalTokens: Number((turn.usage.input_tokens || 0) + (turn.usage.output_tokens || 0)),
    } : undefined;

    return {
      runnerId: this.id,
      content: this.normalizeForIris(turn.finalResponse || ''),
      model: this.model,
      usage,
      tokenCount: usage?.totalTokens,
    };
  }

  async *chatStream(request: RunnerChatRequest): AsyncGenerator<RunnerStreamChunk> {
    const thread = this.getThreadForRequest(request);
    const prompt = this.buildPrompt(request);
    const { events } = await thread.runStreamed(prompt);

    let assembled = '';
    for await (const ev of events) {
      const maybeDelta = this.extractDeltaFromEvent(ev, assembled);
      if (maybeDelta) {
        assembled += maybeDelta;
        yield { token: maybeDelta, done: false };
      }
      if (ev.type === 'turn.completed' && ev.usage) {
        yield {
          token: '',
          done: true,
          usage: {
            promptTokens: Number(ev.usage.input_tokens || 0),
            completionTokens: Number(ev.usage.output_tokens || 0),
            totalTokens: Number((ev.usage.input_tokens || 0) + (ev.usage.output_tokens || 0)),
          },
        };
        return;
      }
    }
    yield { token: '', done: true };
  }

  async generateCode(spec: CodeGenerationSpec): Promise<GeneratedCode> {
    const prompt =
`Generate production-ready InterSystems ObjectScript for this requirement.

Requirement:
${spec.description}

Integration type: ${spec.integrationType || 'generic'}
Namespace: ${spec.namespace || 'USER'}
Existing classes: ${(spec.existingClasses || []).join(', ') || 'None'}
Additional context: ${spec.conversationContext || ''}

Return complete, compilable class definitions.`;

    const response = await this.chat({
      conversationId: 'codegen',
      message: prompt,
      systemPrompt: CODING_SYSTEM_PROMPT,
      history: [],
      namespace: spec.namespace,
    });

    const source = response.content.trim();
    const className = this.extractFirstClassName(source) || 'AIAgent.Generated.Codex.GeneratedClass';
    return {
      runnerId: this.id,
      description: spec.description,
      classes: [{
        className,
        classType: 'Generic',
        source,
        description: 'Generated by OpenAI Codex SDK runner',
      }],
    };
  }

  async reviewCode(source: string, context: string): Promise<CodeReview> {
    const prompt =
`Review the following ObjectScript class for correctness, safety, and IRIS best practices.

Context:
${context}

Source:
${source}

Return findings with severity and concrete fixes.`;

    const response = await this.chat({
      conversationId: 'review',
      message: prompt,
      systemPrompt: CODING_SYSTEM_PROMPT,
      history: [],
    });

    return {
      runnerId: this.id,
      rating: 4,
      summary: 'Codex SDK review completed',
      findings: response.content,
      suggestedSource: '',
      assessment: response.content.toLowerCase().includes('error') ? 'fail' : 'pass',
    };
  }

  private getThreadForRequest(request: RunnerChatRequest): Thread {
    const conversationId = request.conversationId || 'default';
    const existing = this.threadsByConversation.get(conversationId);
    if (existing) return existing;

    const thread = this.codex.startThread(this.threadOptions());
    this.threadsByConversation.set(conversationId, thread);
    return thread;
  }

  private threadOptions(): ThreadOptions {
    return {
      model: this.model,
      sandboxMode: this.sandboxMode,
      approvalPolicy: this.approvalPolicy,
      networkAccessEnabled: true,
      workingDirectory: this.workspaceRoot,
      additionalDirectories: this.additionalDirectories,
      skipGitRepoCheck: true,
    };
  }

  private buildPrompt(request: RunnerChatRequest): string {
    const lines: string[] = [];
    lines.push(`System:\n${request.systemPrompt || CODING_SYSTEM_PROMPT}`);
    if (request.namespace) {
      lines.push(`IRIS Namespace:\n${request.namespace}`);
    }
    lines.push(`Workspace Root:\n${this.workspaceRoot}`);
    if (this.additionalDirectories.length > 0) {
      lines.push(`Additional Read Context:\n${this.additionalDirectories.join('\n')}`);
    }
    lines.push('Instruction:\nUse local repository files and project context to ground your answer. Read relevant files before proposing code.');
    if (request.messages && request.messages.length > 0) {
      lines.push('Conversation History:');
      for (const msg of request.messages) {
        lines.push(`${msg.role.toUpperCase()}: ${msg.content}`);
      }
    } else if (request.history && request.history.length > 0) {
      lines.push('Conversation History:');
      for (const msg of request.history) {
        lines.push(`${msg.role.toUpperCase()}: ${msg.content}`);
      }
    }
    lines.push(`USER:\n${request.message || ''}`);
    return lines.join('\n\n');
  }

  private extractDeltaFromEvent(ev: ThreadEvent, assembled: string): string | null {
    const candidate = this.extractAgentTextFromEvent(ev);
    if (candidate === null) return null;
    const normalized = this.normalizeForIris(candidate);
    if (!normalized) return null;
    return normalized.startsWith(assembled) ? normalized.slice(assembled.length) : normalized;
  }

  private extractAgentTextFromEvent(ev: ThreadEvent): string | null {
    if ((ev.type === 'item.updated' || ev.type === 'item.completed') && ev.item?.type === 'agent_message') {
      return String(ev.item.text || '');
    }
    return null;
  }

  private extractFirstClassName(source: string): string | null {
    const m = source.match(/^\s*Class\s+([A-Za-z0-9_.]+)/m);
    return m ? m[1] : null;
  }

  private normalizeForIris(text: string): string {
    if (!text) return '';
    return text
      .replace(/[‘’]/g, "'")
      .replace(/[“”]/g, '"')
      .replace(/[–—]/g, '-')
      .replace(/…/g, '...')
      .replace(/\u00A0/g, ' ');
  }
}

const CODING_SYSTEM_PROMPT = `You are an expert InterSystems IRIS HealthConnect engineer.
Use local repository context, existing classes, and conventions to produce enterprise-grade changes.
Prefer minimal safe deltas, robust error handling, and deployment-ready ObjectScript.`;
