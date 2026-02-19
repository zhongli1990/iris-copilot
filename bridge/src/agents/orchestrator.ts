/**
 * Master Orchestrator Agent.
 * Classifies user intent, selects the right AI runner, and coordinates
 * the multi-step workflow (requirements → design → generate → review).
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import type { RunnerRegistry } from '../runners/runner-registry.js';
import type { RunnerChatRequest, RunnerStreamChunk, GeneratedCode } from '../runners/runner-interface.js';
import { config } from '../config.js';

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
  generation?: {
    description: string;
    classes: Array<{ className: string; classType: string; source: string }>;
  };
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

  constructor(registry: RunnerRegistry) {
    this.registry = registry;
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
    // Emit runner attribution first so UI can show exactly which runner is active.
    yield { token: '', done: false, runner: runner.id };
    const request: RunnerChatRequest = {
      message: input.message,
      systemPrompt: this.buildSystemPrompt(intent, input),
      history: input.history || [],
    };

    yield* runner.chatStream(request);
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

const ORCHESTRATOR_BASE_PROMPT = `You are IRIS Copilot, the AI-powered development platform for NHS hospital Trust Integration Engines.

You are embedded within an InterSystems IRIS HealthConnect instance. Users interact with you through a chat interface to build, modify, monitor, and manage clinical system integrations — WITHOUT writing any ObjectScript code themselves.

You are currently assisting with the NHS Bradford Teaching Hospitals Trust Integration Engine:
- 1,224 COS classes, 150+ production hosts, 74 clinical system interfaces
- Main production: BRI.Productions.TEST
- Key upstream systems: Cerner (TCP 30000-30007), IPM/PAS (HTTP), CRIS (TCP 7982), WinPath (TCP 35100), TelePath (TCP 9985)
- Key downstream: A&E, RTADT, BadgerNet, SystmOne, ICE New, ICNET, Waba, AScribe
- Architecture: Hub-and-spoke with EnsLib.HL7.MsgRouter.RoutingEngine distributor/router pattern
- HL7 schemas in use: 2.3, 2.3.1, 2.4, CERNER2.3, custom schemas

AI-generated classes use the prefix: AIAgent.Generated.<Domain>.<ComponentType>.<Name>

Respond in the user's language (English, Spanish, Chinese, etc.). Be precise about HL7 field paths and IRIS APIs.`;

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
