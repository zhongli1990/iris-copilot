/**
 * IRIS HTTP Client.
 * Calls back into the IRIS REST API (AIAgent.API.Dispatcher) from the Node.js bridge.
 * Used by AI agents to inspect productions, read classes, and check status.
 *
 * Part of the IRIS AI Agent Platform (IRIS Copilot).
 */

export interface IRISHealthResponse {
  status: string;
  iris?: boolean;
  bridge?: boolean;
}

export class IRISClient {
  private baseUrl: string;
  private timeout: number;

  constructor(baseUrl: string = 'http://localhost:52773/ai', timeout: number = 30000) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.timeout = timeout;
  }

  /** Health check — verify IRIS is reachable */
  async healthCheck(): Promise<IRISHealthResponse> {
    // Avoid calling /health here because IRIS /ai/health may call back into
    // bridge health, creating a recursive dependency chain.
    await this.fetch('/production/status');
    return { status: 'ok', iris: true, bridge: false };
  }

  /** Get production status */
  async getProductionStatus(): Promise<object> {
    return this.fetch('/production/status');
  }

  /** Get production topology (all hosts) */
  async getProductionTopology(): Promise<object> {
    return this.fetch('/production/topology');
  }

  /** List classes matching a pattern */
  async listClasses(pattern: string = 'AIAgent.Generated.%'): Promise<object> {
    return this.fetch(`/classes?pattern=${encodeURIComponent(pattern)}`);
  }

  /** Read a specific class source */
  async readClass(className: string): Promise<object> {
    return this.fetch(`/classes/${encodeURIComponent(className)}`);
  }

  /** List lookup tables */
  async listLookupTables(): Promise<object> {
    return this.fetch('/lookups');
  }

  /** Read a lookup table */
  async readLookupTable(tableName: string): Promise<object> {
    return this.fetch(`/lookups/${encodeURIComponent(tableName)}`);
  }

  /** List HL7 schemas */
  async listHL7Schemas(): Promise<object> {
    return this.fetch('/hl7schemas');
  }

  /** Get production event log */
  async getEventLog(count: number = 50): Promise<object> {
    return this.fetch(`/production/events?count=${count}`);
  }

  /** Execute a read-only SQL query */
  async executeSQL(query: string): Promise<object> {
    return this.fetchPost('/sql', { query });
  }

  /** Get audit log */
  async getAuditLog(page: number = 1, pageSize: number = 50): Promise<object> {
    return this.fetch(`/audit?page=${page}&pageSize=${pageSize}`);
  }

  // ---- HTTP helpers ----

  private async fetch(path: string): Promise<object> {
    const url = `${this.baseUrl}${path}`;
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);
      const response = await globalThis.fetch(url, {
        method: 'GET',
        headers: { 'Accept': 'application/json' },
        signal: controller.signal,
      });
      clearTimeout(timeoutId);
      if (!response.ok) {
        throw new Error(`IRIS API error: ${response.status} ${response.statusText}`);
      }
      return await response.json() as object;
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') {
        throw new Error(`IRIS API timeout: ${url}`);
      }
      throw err;
    }
  }

  private async fetchPost(path: string, body: object): Promise<object> {
    const url = `${this.baseUrl}${path}`;
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);
      const response = await globalThis.fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      clearTimeout(timeoutId);
      if (!response.ok) {
        throw new Error(`IRIS API error: ${response.status} ${response.statusText}`);
      }
      return await response.json() as object;
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') {
        throw new Error(`IRIS API timeout: ${url}`);
      }
      throw err;
    }
  }
}
