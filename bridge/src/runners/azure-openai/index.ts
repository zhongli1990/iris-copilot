/**
 * Azure OpenAI Runner Adapter.
 * Wraps Azure OpenAI Service for organizations using Microsoft Azure-hosted models.
 * Uses the OpenAI SDK with Azure-specific configuration.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import OpenAI from 'openai';
import type { AzureClientOptions } from 'openai';
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

export interface AzureOpenAIConfig {
  endpoint: string;      // e.g., "https://myorg.openai.azure.com"
  apiKey: string;
  deploymentName: string; // e.g., "gpt-4o" (Azure deployment name)
  apiVersion?: string;    // e.g., "2024-08-01-preview"
}

export class AzureOpenAIRunner implements AIRunnerAdapter {
  readonly id = 'azure-openai';
  readonly name = 'Azure OpenAI Service';
  readonly capabilities: RunnerCapability[] = [
    'chat', 'code-generation', 'code-review', 'architecture', 'testing',
  ];

  private client: OpenAI;
  private deploymentName: string;

  constructor(config: AzureOpenAIConfig) {
    this.deploymentName = config.deploymentName;

    // OpenAI SDK supports Azure natively via these options
    this.client = new OpenAI({
      apiKey: config.apiKey,
      baseURL: `${config.endpoint.replace(/\/$/, '')}/openai/deployments/${config.deploymentName}`,
      defaultQuery: { 'api-version': config.apiVersion || '2024-08-01-preview' },
      defaultHeaders: { 'api-key': config.apiKey },
    } as AzureClientOptions);
  }

  async healthCheck(): Promise<RunnerHealth> {
    const start = Date.now();
    try {
      await this.client.chat.completions.create({
        model: this.deploymentName,
        max_tokens: 10,
        messages: [{ role: 'user', content: 'ping' }],
      });
      return {
        healthy: true,
        latencyMs: Date.now() - start,
        model: `azure/${this.deploymentName}`,
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
    const messages = this.buildMessages(request);
    const response = await this.client.chat.completions.create({
      model: this.deploymentName,
      max_tokens: 8192,
      messages,
    });

    const text = response.choices[0]?.message?.content || '';
    return {
      content: text,
      tokenCount: response.usage?.total_tokens || 0,
      model: `azure/${this.deploymentName}`,
      runnerId: this.id,
    };
  }

  async *chatStream(request: RunnerChatRequest): AsyncGenerator<RunnerStreamChunk> {
    const messages = this.buildMessages(request);
    const stream = await this.client.chat.completions.create({
      model: this.deploymentName,
      max_tokens: 8192,
      messages,
      stream: true,
    });

    for await (const chunk of stream) {
      const delta = chunk.choices[0]?.delta?.content;
      if (delta) {
        yield { token: delta, done: false };
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
      systemPrompt: AZURE_COS_SYSTEM_PROMPT,
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
      systemPrompt: AZURE_COS_SYSTEM_PROMPT,
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

    messages.push({
      role: 'system',
      content: request.systemPrompt || AZURE_COS_SYSTEM_PROMPT,
    });

    if (request.history) {
      for (const msg of request.history) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({ role: msg.role, content: msg.content });
        }
      }
    }

    messages.push({ role: 'user', content: request.message || '' });
    return messages;
  }
}

const AZURE_COS_SYSTEM_PROMPT = `You are an expert InterSystems IRIS HealthConnect developer.
You generate production-quality ObjectScript (COS) code for NHS hospital integration engines.
Follow IRIS HealthConnect patterns: Business Services, Processes, Operations, DTL transforms, routing rules.
Use proper error handling (try/catch, %Status), parameterized SQL, and SETTINGS parameters.
HL7 path syntax: Segment:Field.Component (e.g., PID:3(1).1 for MRN, MSH:9.1 for message type).`;
