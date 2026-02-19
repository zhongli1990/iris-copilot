/**
 * OpenAI Runner Adapter.
 * Wraps the OpenAI Chat Completions API for code generation and chat.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import OpenAI from 'openai';
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

export class OpenAIRunner implements AIRunnerAdapter {
  readonly id = 'openai-codex';
  readonly name = 'OpenAI (GPT/Codex)';
  readonly capabilities: RunnerCapability[] = [
    'chat', 'code-generation', 'code-review', 'architecture', 'testing',
  ];

  private client: OpenAI;
  private model: string;

  constructor(apiKey: string, model: string = 'gpt-5.2-codex') {
    this.client = new OpenAI({ apiKey });
    this.model = model;
  }

  private isCodexModel(): boolean {
    return this.model.toLowerCase().includes('codex');
  }

  private toPrompt(request: RunnerChatRequest): string {
    const lines: string[] = [];
    const system = request.systemPrompt || OPENAI_COS_SYSTEM_PROMPT;
    if (system) {
      lines.push(`System:\n${system}`);
    }
    if (request.history && request.history.length > 0) {
      for (const m of request.history) {
        lines.push(`${m.role.toUpperCase()}:\n${m.content}`);
      }
    }
    lines.push(`USER:\n${request.message || ''}`);
    lines.push('ASSISTANT:\n');
    return lines.join('\n\n');
  }

  private extractResponsesText(resp: any): string {
    if (!resp) return '';
    if (typeof resp.output_text === 'string' && resp.output_text.trim() !== '') {
      return resp.output_text;
    }
    // Fallback: walk output[].content[] text blocks
    const out = Array.isArray(resp.output) ? resp.output : [];
    const chunks: string[] = [];
    for (const item of out) {
      const content = Array.isArray(item?.content) ? item.content : [];
      for (const part of content) {
        if (typeof part?.text === 'string') {
          chunks.push(part.text);
        } else if (typeof part?.content === 'string') {
          chunks.push(part.content);
        }
      }
    }
    return chunks.join('');
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

  async healthCheck(): Promise<RunnerHealth> {
    const start = Date.now();
    try {
      if (this.isCodexModel()) {
        await this.client.responses.create({
          model: this.model,
          input: 'ping',
          max_output_tokens: 16,
        });
      } else {
        await this.client.chat.completions.create({
          model: this.model,
          max_tokens: 10,
          messages: [{ role: 'user', content: 'ping' }],
        });
      }
      return {
        healthy: true,
        latencyMs: Date.now() - start,
        model: this.model,
      };
    } catch (err) {
      return {
        healthy: false,
        latencyMs: Date.now() - start,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }

  async chat(request: RunnerChatRequest): Promise<RunnerChatResponse> {
    if (this.isCodexModel()) {
      const response = await this.client.responses.create({
        model: this.model,
        input: this.toPrompt(request),
        max_output_tokens: request.maxTokens || 8192,
      });
      const anyResp = response as any;
      const usage = anyResp?.usage;
      return {
        content: this.normalizeForIris(this.extractResponsesText(anyResp)),
        tokenCount: usage?.total_tokens || 0,
        model: this.model,
        runnerId: this.id,
      };
    }

    const messages = this.buildMessages(request);
    {
      const response = await this.client.chat.completions.create({
        model: this.model,
        max_tokens: 8192,
        messages,
      });

      const text = this.normalizeForIris(response.choices[0]?.message?.content || '');
      return {
        content: text,
        tokenCount: response.usage?.total_tokens || 0,
        model: this.model,
        runnerId: this.id,
      };
    }
  }

  async *chatStream(request: RunnerChatRequest): AsyncGenerator<RunnerStreamChunk> {
    if (this.isCodexModel()) {
      const response = await this.chat(request);
      if (response.content) {
        yield { token: response.content, done: false };
      }
      yield { token: '', done: true };
      return;
    }

    const messages = this.buildMessages(request);
    const stream = await this.client.chat.completions.create({
      model: this.model,
      max_tokens: 8192,
      messages,
      stream: true,
    });

    for await (const chunk of stream) {
      const delta = chunk.choices[0]?.delta?.content;
      if (delta) {
        yield { token: this.normalizeForIris(delta), done: false };
      }
    }
    yield { token: '', done: true };
  }

  async generateCode(spec: CodeGenerationSpec): Promise<GeneratedCode> {
    const prompt = `Generate InterSystems ObjectScript (COS) code for the following specification.

## Specification
${spec.description}

## Component Type: ${spec.componentType}
## Class Name: ${spec.className}
## Namespace: ${spec.namespace || 'USER'}
${spec.additionalContext || ''}

Generate a complete, compilable ObjectScript class. Follow IRIS HealthConnect patterns.
Return ONLY the class source code starting with "Class" and ending with "}".`;

    const response = await this.chat({
      conversationId: 'codegen',
      message: prompt,
      systemPrompt: OPENAI_COS_SYSTEM_PROMPT,
      history: [],
    });

    let source = response.content.trim();
    if (source.startsWith('```')) {
      source = source.replace(/^```\w*\n?/, '').replace(/\n?```$/, '');
    }

    return {
      classes: [{
        className: spec.className || 'AIAgent.Generated.Sample.Class',
        classType: spec.componentType || 'Generic',
        source,
      }],
      description: spec.description,
      runnerId: this.id,
    };
  }

  async reviewCode(source: string, context: string): Promise<CodeReview> {
    const response = await this.chat({
      conversationId: 'review',
      message: `Review this ObjectScript class:\n\n${source}\n\nContext: ${context}`,
      systemPrompt: OPENAI_COS_SYSTEM_PROMPT,
      history: [],
    });

    return {
      assessment: response.content.toLowerCase().includes('error') ? 'fail' : 'pass',
      findings: response.content,
      runnerId: this.id,
    };
  }

  private buildMessages(request: RunnerChatRequest): Array<OpenAI.Chat.ChatCompletionMessageParam> {
    const messages: Array<OpenAI.Chat.ChatCompletionMessageParam> = [];

    // System prompt
    messages.push({
      role: 'system',
      content: request.systemPrompt || OPENAI_COS_SYSTEM_PROMPT,
    });

    // History
    if (request.history) {
      for (const msg of request.history) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({ role: msg.role, content: msg.content });
        }
      }
    }

    // Current message
    messages.push({ role: 'user', content: request.message || '' });
    return messages;
  }
}

const OPENAI_COS_SYSTEM_PROMPT = `You are an expert InterSystems IRIS HealthConnect developer.
You generate production-quality ObjectScript (COS) code for NHS hospital integration engines.
Follow IRIS HealthConnect patterns: Business Services, Processes, Operations, DTL transforms, routing rules.
Use proper error handling (try/catch, %Status), parameterized SQL, and SETTINGS parameters.
HL7 path syntax: Segment:Field.Component (e.g., PID:3(1).1 for MRN, MSH:9.1 for message type).`;
