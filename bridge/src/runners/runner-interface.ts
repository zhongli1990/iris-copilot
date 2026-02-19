/**
 * Core pluggable runner interface for the IRIS AI Agent Bridge.
 *
 * Every AI provider (Anthropic Claude, OpenAI, Azure OpenAI, Google Vertex,
 * local Ollama, etc.) implements this interface so the orchestrator can
 * interact with any backend through a single abstraction.
 */

// ---------------------------------------------------------------------------
// Capability enum
// ---------------------------------------------------------------------------

/**
 * Capabilities a runner may advertise.  The registry uses these to select
 * the best runner for a given task.
 */
export type RunnerCapability =
  | "chat"
  | "chat-stream"
  | "code-generation"
  | "code-review"
  | "function-calling"
  | "vision"
  | "embeddings"
  | "architecture"
  | "testing";

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

export interface RunnerHealth {
  /** Runner id that this health report belongs to. */
  runnerId?: string;
  /** Whether the runner is currently operational. */
  healthy: boolean;
  /** Latency of the last health probe in milliseconds (0 if unavailable). */
  latencyMs: number;
  /** Human-readable status message. */
  message?: string;
  /** ISO-8601 timestamp of the health check. */
  checkedAt?: string;
  /** Optional model/deployment id used by the probe. */
  model?: string;
  /** Optional error details for failed probes. */
  error?: string;
}

// ---------------------------------------------------------------------------
// Chat types
// ---------------------------------------------------------------------------

/** A single message in a chat conversation. */
export interface ChatMessage {
  role: "user" | "assistant" | "system";
  content: string;
}

/** Incoming chat request sent to a runner. */
export interface RunnerChatRequest {
  /** Conversation identifier (opaque string from IRIS). */
  conversationId?: string;
  /** Full ordered history of messages in this conversation. */
  messages?: ChatMessage[];
  /** Legacy single-message field used by existing runners. */
  message?: string;
  /** Legacy history field used by existing runners. */
  history?: ChatMessage[];
  /** System prompt to prepend (built by the orchestrator). */
  systemPrompt?: string;
  /** Current IRIS namespace context. */
  namespace?: string;
  /** Optional production status snapshot from IRIS. */
  productionStatus?: Record<string, unknown>;
  /** Maximum tokens to generate. */
  maxTokens?: number;
  /** Sampling temperature (0-2). */
  temperature?: number;
}

/** Response from a non-streaming chat call. */
export interface RunnerChatResponse {
  /** The runner that produced this response. */
  runnerId: string;
  /** The generated assistant message. */
  content: string;
  /** Token usage statistics (provider-dependent). */
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
  /** The model identifier actually used by the provider. */
  model?: string;
  /** Legacy token count field used by existing runners. */
  tokenCount?: number;
  /** If the model stopped for a reason other than natural end. */
  stopReason?: string;
}

/** A single chunk in a streaming chat response. */
export interface RunnerStreamChunk {
  /** Incremental text token. */
  token: string;
  /** True when this is the final chunk. */
  done: boolean;
  /** Optional runner identifier for attribution in streaming flows. */
  runner?: string;
  /** Cumulative usage (only populated on the final chunk). */
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}

// ---------------------------------------------------------------------------
// Code generation types
// ---------------------------------------------------------------------------

/** Specification for generating IRIS ObjectScript classes. */
export interface CodeGenerationSpec {
  /** Natural language description of what to build. */
  description: string;
  /** The target IRIS namespace (e.g. "HSBUS"). */
  namespace: string;
  /**
   * Type of integration to generate.
   * Drives which HealthConnect superclass patterns to use.
   */
  integrationType:
    | "hl7-inbound"
    | "hl7-outbound"
    | "rest-operation"
    | "soap-operation"
    | "file-service"
    | "tcp-service"
    | "custom-bp"
    | "routing-rule"
    | "dtl"
    | "generic";
  /** Existing class names that the generated code should interoperate with. */
  existingClasses?: string[];
  /** Extra context from the user conversation. */
  conversationContext?: string;
  /** Legacy fields used by current runner adapters. */
  componentType?: string;
  className?: string;
  additionalContext?: string;
  existingProduction?: string;
}

/** A single generated ObjectScript class. */
export interface GeneratedClass {
  /** Fully qualified IRIS class name (e.g. "BRI.Interfaces.Cerner.InboundADT"). */
  className: string;
  /**
   * The COS class type: service, process, operation, message, dtl, router, util.
   */
  classType: string;
  /** Complete UDL class source. */
  source: string;
  /** Brief explanation of the class's purpose. */
  description?: string;
}

/** Full result of a code generation request. */
export interface GeneratedCode {
  /** Runner that produced the code. */
  runnerId: string;
  /** Summary of what was generated. */
  description: string;
  /** The generated classes. */
  classes: GeneratedClass[];
  /** Suggested production host configurations for each class. */
  productionConfig?: Array<{
    name: string;
    className: string;
    category: string;
    enabled: boolean;
    settings: Record<string, string>;
    comment: string;
  }>;
}

// ---------------------------------------------------------------------------
// Code review types
// ---------------------------------------------------------------------------

/** Result of reviewing a piece of ObjectScript source code. */
export interface CodeReview {
  /** Legacy overall assessment (pass/warning/fail). */
  assessment?: string;
  /** Runner that produced the review. */
  runnerId: string;
  /** Overall quality rating: 1 (poor) to 5 (excellent). */
  rating?: number;
  /** High-level summary of the review. */
  summary?: string;
  /** Individual review findings. */
  findings: CodeReviewFinding[] | string;
  /** Suggested improved source (empty string if no changes needed). */
  suggestedSource?: string;
}

export interface CodeReviewFinding {
  severity: "info" | "warning" | "error";
  category: "security" | "performance" | "style" | "correctness" | "best-practice";
  message: string;
  /** Line number reference (0 if not applicable). */
  line: number;
}

// ---------------------------------------------------------------------------
// Runner adapter interface
// ---------------------------------------------------------------------------

/**
 * The core adapter interface that every AI runner must implement.
 *
 * Runners are registered in the RunnerRegistry and selected by the
 * Orchestrator based on capability matching and user/admin preference.
 */
export interface AIRunnerAdapter {
  /** Unique identifier for this runner (e.g. "claude-agent-sdk"). */
  readonly id: string;
  /** Human-readable display name (e.g. "Anthropic Claude"). */
  readonly name: string;
  /** List of capabilities this runner supports. */
  readonly capabilities: RunnerCapability[];

  /**
   * Check whether the runner is healthy and reachable.
   * Should complete within a few seconds.
   */
  healthCheck(): Promise<RunnerHealth>;

  /**
   * Send a chat request and return the complete response.
   */
  chat(request: RunnerChatRequest): Promise<RunnerChatResponse>;

  /**
   * Send a chat request and stream the response token-by-token.
   * Yields RunnerStreamChunk objects.  The last chunk has `done: true`.
   */
  chatStream(request: RunnerChatRequest): AsyncGenerator<RunnerStreamChunk>;

  /**
   * Generate IRIS ObjectScript classes from a specification.
   */
  generateCode(spec: CodeGenerationSpec): Promise<GeneratedCode>;

  /**
   * Review a piece of ObjectScript source code and return findings.
   */
  reviewCode(source: string, context: string): Promise<CodeReview>;
}
