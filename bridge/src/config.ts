/**
 * Configuration loader for the IRIS AI Agent Bridge.
 *
 * Reads environment variables (via dotenv) and exposes a typed,
 * validated configuration object used throughout the bridge.
 */

import dotenv from "dotenv";
dotenv.config();

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function env(key: string, fallback?: string): string {
  const value = process.env[key];
  if (value !== undefined && value !== "") return value;
  if (fallback !== undefined) return fallback;
  return "";
}

function envRequired(key: string): string {
  const value = process.env[key];
  if (value !== undefined && value !== "") return value;
  // Do not throw at import time — runners that are not configured simply
  // won't pass their health check.  The server itself can still start.
  return "";
}

function envInt(key: string, fallback: number): number {
  const raw = process.env[key];
  if (raw === undefined || raw === "") return fallback;
  const parsed = parseInt(raw, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

// ---------------------------------------------------------------------------
// Typed configuration
// ---------------------------------------------------------------------------

export interface AnthropicConfig {
  apiKey: string;
  model: string;
}

export interface OpenAIConfig {
  apiKey: string;
  model: string;
}

export interface AzureOpenAIConfig {
  endpoint: string;
  apiKey: string;
  deployment: string;
  apiVersion: string;
}

export interface IRISConfig {
  baseUrl: string;
  username: string;
  password: string;
  namespace: string;
}

export interface CodexNativeConfig {
  enabled: boolean;
  model: string;
  workspaceRoot: string;
  additionalDirectories: string[];
  sandbox: "read-only" | "workspace-write" | "danger-full-access";
  approvalPolicy: "never" | "on-request" | "untrusted";
}

export interface AppConfig {
  port: number;
  logLevel: string;
  defaultRunner: string;
  genericOperate: {
    enabled: boolean;
    approvalRequiredForMutation: boolean;
    dryRunRequired: boolean;
  };
  anthropic: AnthropicConfig;
  openai: OpenAIConfig;
  azureOpenai: AzureOpenAIConfig;
  iris: IRISConfig;
  codexNative: CodexNativeConfig;
}

// ---------------------------------------------------------------------------
// Build and export the singleton config
// ---------------------------------------------------------------------------

export const config: AppConfig = {
  port: envInt("PORT", 3100),
  logLevel: env("LOG_LEVEL", "info"),
  defaultRunner: env("DEFAULT_RUNNER", "openai-codex-sdk"),
  genericOperate: {
    enabled: env("GENERIC_OPERATE_ENABLED", "0") === "1",
    approvalRequiredForMutation: env("GENERIC_OPERATE_APPROVAL_REQUIRED_FOR_MUTATION", "1") === "1",
    dryRunRequired: env("GENERIC_OPERATE_DRYRUN_REQUIRED", "1") === "1",
  },

  anthropic: {
    apiKey: envRequired("ANTHROPIC_API_KEY"),
    model: env("ANTHROPIC_MODEL", "claude-opus-4-1-20250805"),
  },

  openai: {
    apiKey: envRequired("OPENAI_API_KEY"),
    model: env("OPENAI_MODEL", "gpt-5.2-codex"),
  },

  azureOpenai: {
    endpoint: env("AZURE_OPENAI_ENDPOINT", ""),
    apiKey: env("AZURE_OPENAI_KEY", ""),
    deployment: env("AZURE_OPENAI_DEPLOYMENT", "gpt-4o"),
    apiVersion: env("AZURE_OPENAI_API_VERSION", "2024-10-21"),
  },

  iris: {
    baseUrl: env("IRIS_BASE_URL", "http://localhost:52773"),
    username: env("IRIS_USERNAME", "_SYSTEM"),
    password: env("IRIS_PASSWORD", "SYS"),
    namespace: env("IRIS_NAMESPACE", "HSBUS"),
  },
  codexNative: {
    enabled: env("CODEX_NATIVE_ENABLED", "1") === "1",
    model: env("CODEX_NATIVE_MODEL", env("OPENAI_MODEL", "gpt-5.2-codex")),
    workspaceRoot: env("CODEX_NATIVE_WORKSPACE", ".."),
    additionalDirectories: env("CODEX_NATIVE_ADDITIONAL_DIRS", "")
      .split(",")
      .map(s => s.trim())
      .filter(Boolean),
    sandbox: (env("CODEX_NATIVE_SANDBOX", "read-only") as "read-only" | "workspace-write" | "danger-full-access"),
    approvalPolicy: (env("CODEX_NATIVE_APPROVAL", "never") as "never" | "on-request" | "untrusted"),
  },
};

/**
 * Returns true when Azure OpenAI is fully configured (endpoint + key).
 * When true the OpenAI runner should use the Azure backend instead of
 * the public OpenAI API.
 */
export function isAzureConfigured(): boolean {
  return config.azureOpenai.endpoint !== "" && config.azureOpenai.apiKey !== "";
}
