/**
 * Runner Registry: discovers, stores, and selects AI runner adapters.
 * Supports capability-based routing with fallback.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

import type { AIRunnerAdapter, RunnerCapability, RunnerHealth } from './runner-interface.js';

export interface RunnerSelection {
  capability: RunnerCapability;
  preferred?: string; // runner ID
}

export class RunnerRegistry {
  private runners: Map<string, AIRunnerAdapter> = new Map();
  private healthCache: Map<string, { health: RunnerHealth; timestamp: number }> = new Map();
  private readonly HEALTH_TTL = 1_800_000; // 30 minute cache

  /** Register a runner adapter */
  register(runner: AIRunnerAdapter): void {
    this.runners.set(runner.id, runner);
    console.log(`[RunnerRegistry] Registered: ${runner.name} (${runner.id}) — capabilities: ${runner.capabilities.join(', ')}`);
  }

  /** Unregister a runner */
  unregister(id: string): void {
    this.runners.delete(id);
    this.healthCache.delete(id);
  }

  /** Get a specific runner by ID */
  get(id: string): AIRunnerAdapter | undefined {
    return this.runners.get(id);
  }

  /** Get all registered runners */
  getAll(): AIRunnerAdapter[] {
    return Array.from(this.runners.values());
  }

  /** Select the best runner for a given capability */
  select(selection: RunnerSelection): AIRunnerAdapter | undefined {
    const { capability, preferred } = selection;

    // 1. Try preferred runner first
    if (preferred) {
      const pref = this.runners.get(preferred);
      if (pref && pref.capabilities.includes(capability)) {
        return pref;
      }
    }

    // 2. Fall back to any runner with the capability
    for (const runner of this.runners.values()) {
      if (runner.capabilities.includes(capability)) {
        return runner;
      }
    }

    return undefined;
  }

  /** Health check all runners (with caching) */
  async healthCheckAll(): Promise<Map<string, RunnerHealth>> {
    const results = new Map<string, RunnerHealth>();
    const checks = Array.from(this.runners.entries()).map(async ([id, runner]) => {
      // Check cache
      const cached = this.healthCache.get(id);
      if (cached && Date.now() - cached.timestamp < this.HEALTH_TTL) {
        results.set(id, cached.health);
        return;
      }
      // Fresh check
      try {
        const health = await runner.healthCheck();
        this.healthCache.set(id, { health, timestamp: Date.now() });
        results.set(id, health);
      } catch (err) {
        const errorHealth: RunnerHealth = {
          healthy: false,
          latencyMs: -1,
          error: err instanceof Error ? err.message : String(err),
        };
        this.healthCache.set(id, { health: errorHealth, timestamp: Date.now() });
        results.set(id, errorHealth);
      }
    });
    await Promise.all(checks);
    return results;
  }

  /** Get registry summary for API responses */
  async getSummary(): Promise<object[]> {
    const healthMap = await this.healthCheckAll();
    return this.getAll().map(runner => ({
      id: runner.id,
      name: runner.name,
      capabilities: runner.capabilities,
      health: healthMap.get(runner.id) || { healthy: false, error: 'Not checked' },
    }));
  }
}
