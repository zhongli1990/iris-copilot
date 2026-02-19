/**
 * Claude Agent SDK Runner Adapter.
 * Wraps the Anthropic Messages API for chat, code generation, and code review.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import Anthropic from '@anthropic-ai/sdk';
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

export class ClaudeRunner implements AIRunnerAdapter {
  readonly id = 'claude-agent-sdk';
  readonly name = 'Claude Agent SDK (Anthropic)';
  readonly capabilities: RunnerCapability[] = [
    'chat', 'code-generation', 'code-review', 'architecture', 'testing',
  ];

  private client: Anthropic;
  private model: string;

  constructor(apiKey: string, model: string = 'claude-opus-4-1-20250805') {
    this.client = new Anthropic({ apiKey });
    this.model = model;
  }

  async healthCheck(): Promise<RunnerHealth> {
    const start = Date.now();
    try {
      // Lightweight API call to verify key is valid
      const msg = await this.client.messages.create({
        model: this.model,
        max_tokens: 10,
        messages: [{ role: 'user', content: 'ping' }],
      });
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
    const messages = this.buildMessages(request);
    const response = await this.client.messages.create({
      model: this.model,
      max_tokens: 8192,
      system: request.systemPrompt || IRIS_SYSTEM_PROMPT,
      messages,
    });

    const text = response.content
      .filter(block => block.type === 'text')
      .map(block => (block as { type: 'text'; text: string }).text)
      .join('');

    return {
      content: text,
      tokenCount: (response.usage?.input_tokens || 0) + (response.usage?.output_tokens || 0),
      model: this.model,
      runnerId: this.id,
    };
  }

  async *chatStream(request: RunnerChatRequest): AsyncGenerator<RunnerStreamChunk> {
    const messages = this.buildMessages(request);
    const stream = this.client.messages.stream({
      model: this.model,
      max_tokens: 8192,
      system: request.systemPrompt || IRIS_SYSTEM_PROMPT,
      messages,
    });

    for await (const event of stream) {
      if (event.type === 'content_block_delta') {
        const delta = event.delta as { type: string; text?: string };
        if (delta.type === 'text_delta' && delta.text) {
          yield { token: delta.text, done: false };
        }
      }
    }
    yield { token: '', done: true };
  }

  async generateCode(spec: CodeGenerationSpec): Promise<GeneratedCode> {
    const prompt = `Generate InterSystems ObjectScript (COS) code for the following specification.

## Specification
${spec.description}

## Component Type
${spec.componentType} (e.g., BusinessService, BusinessProcess, BusinessOperation, DataTransformation, RoutingRule, Message)

## Class Name
${spec.className}

## Context
Namespace: ${spec.namespace || 'USER'}
Existing production: ${spec.existingProduction || 'Unknown'}
${spec.additionalContext || ''}

## Requirements
- Generate a complete, compilable COS class
- Follow InterSystems IRIS HealthConnect patterns
- Include proper error handling with try/catch
- Use parameterized SQL where applicable
- Include class documentation comments
- Use SETTINGS parameter for configurable values

Return ONLY the ObjectScript class source code, starting with "Class" and ending with "}".
Do not include markdown code fences.`;

    const response = await this.chat({
      conversationId: 'codegen',
      message: prompt,
      systemPrompt: IRIS_CODE_GEN_PROMPT,
      history: [],
    });

    // Extract class source from response
    let source = response.content.trim();
    // Strip markdown fences if present
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
    const prompt = `Review the following InterSystems ObjectScript class for correctness, best practices, and potential issues.

## Context
${context}

## Source Code
${source}

Provide:
1. Overall assessment (pass/fail/warning)
2. List of issues found (if any) with line numbers and severity
3. Suggested fixes for each issue`;

    const response = await this.chat({
      conversationId: 'review',
      message: prompt,
      systemPrompt: IRIS_CODE_GEN_PROMPT,
      history: [],
    });

    return {
      assessment: response.content.includes('FAIL') ? 'fail' : response.content.includes('WARNING') ? 'warning' : 'pass',
      findings: response.content,
      runnerId: this.id,
    };
  }

  private buildMessages(request: RunnerChatRequest): Array<{ role: 'user' | 'assistant'; content: string }> {
    const messages: Array<{ role: 'user' | 'assistant'; content: string }> = [];

    // Add conversation history
    if (request.history) {
      for (const msg of request.history) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({ role: msg.role, content: msg.content });
        }
      }
    }

    // Add current message
    messages.push({ role: 'user', content: request.message || '' });
    return messages;
  }
}

// ============================================================
// System Prompts
// ============================================================

const IRIS_SYSTEM_PROMPT = `You are IRIS Copilot, an expert AI assistant for InterSystems IRIS HealthConnect integration development. You help clinical users, hospital IT staff, and developers build HealthConnect integrations by understanding their requirements in plain English and guiding them through the design and implementation process.

You are deeply knowledgeable about:
- InterSystems ObjectScript (COS) programming
- IRIS HealthConnect productions (Business Services, Processes, Operations)
- HL7 v2 messaging (ADT, ORM, ORU, RDE, SIU, MDM)
- FHIR R4 resources
- Data Transformations (DTL)
- Routing Rules and Business Rules
- Ensemble message routing patterns

You are currently assisting with the NHS Bradford Teaching Hospitals Trust Integration Engine (TIE), which has:
- 1,224 COS classes across 74 clinical system interfaces
- 150+ production hosts in BRI.Productions.TEST
- Key systems: Cerner, IPM, CRIS, WinPath, TelePath, BadgerNet, YHCR

When a user describes an integration requirement:
1. Classify the intent (new integration, modification, monitoring, debugging)
2. Ask clarifying questions about HL7 fields, systems, and business rules
3. Design the production topology (which BS/BP/BO/Router/DTL components are needed)
4. Generate ObjectScript code following Bradford TIE conventions
5. Explain what will be deployed and how it connects to existing components

Always respond in the user's language. Be precise about HL7 field paths and IRIS APIs.`;

const IRIS_CODE_GEN_PROMPT = `You are an expert InterSystems ObjectScript code generator. You generate production-quality COS classes for IRIS HealthConnect.

Key rules:
1. Every class must be complete and compilable — include all necessary keywords, brackets, and Storage definitions for persistent classes
2. Use try/catch with %Status for error handling
3. Use parameterized SQL (? placeholders) — NEVER concatenate values into SQL
4. Use SETTINGS parameter for configurable values (ports, paths, endpoints)
5. Use Lookup Tables for reference data that changes without code changes
6. Follow the Bradford TIE naming convention: AIAgent.Generated.<Domain>.<ComponentType>.<Name>
7. For BPL processes, use proper XML namespace and correct HL7 path syntax
8. For Business Operations, always include an XData MessageMap
9. For DTL transforms, include IGNOREMISSINGSOURCE = 1
10. Include class-level documentation comments explaining purpose

HL7 path syntax in IRIS: Segment:Field.Component.SubComponent or Segment:Field(Repeat).Component
Examples: PID:3(1).1 = MRN, PID:5.1 = Last name, MSH:9.1 = Message type, RXE:2.1 = Drug code`;
