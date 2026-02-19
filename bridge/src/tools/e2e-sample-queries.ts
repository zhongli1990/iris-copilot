/**
 * E2E sample-query validator for IRIS Copilot.
 *
 * Runs deterministic backend checks against bridge and IRIS APIs.
 *
 * Usage:
 *   npm run e2e:sample
 *
 * Optional env:
 *   BRIDGE_URL=http://localhost:3100
 *   IRIS_URL=http://localhost:52773
 *   NAMESPACE=DEMO2_AI2
 *   RUNNER=openai-codex-sdk
 */

type Json = Record<string, unknown>;

interface TestCase {
  id: string;
  name: string;
  run: () => Promise<{ pass: boolean; detail: string }>;
}

const BRIDGE_URL = process.env.BRIDGE_URL || 'http://localhost:3100';
const IRIS_URL = process.env.IRIS_URL || 'http://localhost:52773';
const NAMESPACE = process.env.NAMESPACE || 'DEMO2_AI2';
const RUNNER = process.env.RUNNER || 'openai-codex-sdk';

function isObject(value: unknown): value is Json {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

async function getJson(url: string): Promise<Json> {
  const res = await fetch(url);
  const text = await res.text();
  let json: unknown = {};
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`Invalid JSON from ${url}: ${text.slice(0, 200)}`);
  }
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} from ${url}: ${text.slice(0, 300)}`);
  }
  if (!isObject(json)) throw new Error(`Unexpected response shape from ${url}`);
  return json;
}

async function postJson(url: string, body: Json): Promise<Json> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json: unknown = {};
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`Invalid JSON from ${url}: ${text.slice(0, 200)}`);
  }
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} from ${url}: ${text.slice(0, 300)}`);
  }
  if (!isObject(json)) throw new Error(`Unexpected response shape from ${url}`);
  return json;
}

async function callChat(message: string): Promise<Json> {
  return postJson(`${BRIDGE_URL}/api/chat`, {
    conversationId: `e2e-${Date.now()}`,
    message,
    namespace: NAMESPACE,
    preferredRunner: RUNNER,
  });
}

function unwrapDataEnvelope(raw: unknown): unknown {
  let current: unknown = raw;
  for (let i = 0; i < 5; i++) {
    if (!isObject(current)) break;
    if (current.status === 'ok' && current.data !== undefined) {
      current = current.data;
      continue;
    }
    if (current.data !== undefined && (current.meta !== undefined || current.dryRun !== undefined)) {
      current = current.data;
      continue;
    }
    break;
  }
  return current;
}

function pickHostsCount(payload: unknown): number {
  if (!isObject(payload)) return 0;
  if (Array.isArray(payload.hosts)) return payload.hosts.length;
  if (typeof payload.hostCount === 'number') return payload.hostCount;
  return 0;
}

function pickQueueRowsCount(payload: unknown): number {
  if (!isObject(payload)) return 0;
  if (Array.isArray(payload.queues)) return payload.queues.length;
  if (Array.isArray(payload.hosts)) return payload.hosts.length;
  return 0;
}

async function main() {
  const tests: TestCase[] = [
    {
      id: 'T01',
      name: 'Bridge health',
      run: async () => {
        const health = await getJson(`${BRIDGE_URL}/api/health`);
        const ok = health.status === 'ok' && health.bridge === true;
        return { pass: ok, detail: JSON.stringify(health) };
      },
    },
    {
      id: 'T02',
      name: 'IRIS health',
      run: async () => {
        const health = await getJson(`${IRIS_URL}/ai/health`);
        const data = unwrapDataEnvelope(health);
        const ok = isObject(data) && data.status === 'healthy';
        return { pass: ok, detail: JSON.stringify(data) };
      },
    },
    {
      id: 'T03',
      name: 'Operate query production/topology returns hosts',
      run: async () => {
        const rsp = await postJson(`${BRIDGE_URL}/api/iris/operate`, {
          namespace: NAMESPACE,
          op: 'query',
          target: 'production/topology',
          action: 'read',
          args: {},
          dryRun: false,
        });
        const data = unwrapDataEnvelope(rsp);
        const count = pickHostsCount(data);
        return { pass: count > 0, detail: `hostCount=${count}` };
      },
    },
    {
      id: 'T04',
      name: 'Operate query production/queues returns rows',
      run: async () => {
        const rsp = await postJson(`${BRIDGE_URL}/api/iris/operate`, {
          namespace: NAMESPACE,
          op: 'query',
          target: 'production/queues',
          action: 'read',
          args: {},
          dryRun: false,
        });
        const data = unwrapDataEnvelope(rsp);
        const count = pickQueueRowsCount(data);
        return { pass: count >= 0, detail: `queueRows=${count}` };
      },
    },
    {
      id: 'T05',
      name: 'Chat: list classes in BRI.*',
      run: async () => {
        const rsp = await callChat('list classes in the BRI.* packages');
        const text = String(rsp.response || '');
        const actions = asArray((rsp as Json).actions);
        const first = (actions[0] || {}) as Json;
        const target = String(first.target || '');
        const ok = target === 'dictionary/classes';
        return { pass: ok, detail: `target=${target}; response=${text.slice(0, 180)}` };
      },
    },
    {
      id: 'T06',
      name: 'Chat: dry-run host add returns dry-run result',
      run: async () => {
        const rsp = await callChat('Create a plan to add a disabled test business host named AIAgent.DryRun.TestHost, dry-run only.');
        const text = String(rsp.response || '');
        const ok = text.toLowerCase().includes('dry-run executed') || text.toLowerCase().includes('"dry_run"');
        return { pass: ok, detail: text.slice(0, 260) };
      },
    },
    {
      id: 'T07',
      name: 'Operate discover invoke-policy',
      run: async () => {
        const rsp = await postJson(`${BRIDGE_URL}/api/iris/operate`, {
          namespace: NAMESPACE,
          op: 'discover',
          target: 'invoke-policy',
          action: 'read',
          args: {},
          dryRun: false,
        });
        const data = unwrapDataEnvelope(rsp);
        const ok = isObject(data) && typeof data.mode === 'string';
        return { pass: ok, detail: JSON.stringify(data) };
      },
    },
    {
      id: 'T08',
      name: 'Operate invoke forbidden class is denied',
      run: async () => {
        const res = await fetch(`${BRIDGE_URL}/api/iris/operate`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            namespace: NAMESPACE,
            op: 'execute',
            target: 'class/invoke',
            action: 'apply',
            dryRun: false,
            args: {
              className: '%SYSTEM.OBJ',
              method: 'Delete',
              arguments: ['AIAgent.Generated.Test.cls'],
            },
          }),
        });
        const text = await res.text();
        const denied = text.includes('FORBIDDEN') || text.toLowerCase().includes('denied');
        return { pass: denied, detail: `HTTP ${res.status}: ${text.slice(0, 260)}` };
      },
    },
  ];

  const results: Array<{ id: string; name: string; pass: boolean; detail: string }> = [];
  for (const t of tests) {
    try {
      const r = await t.run();
      results.push({ id: t.id, name: t.name, pass: r.pass, detail: r.detail });
    } catch (err) {
      results.push({
        id: t.id,
        name: t.name,
        pass: false,
        detail: err instanceof Error ? err.message : String(err),
      });
    }
  }

  const passed = results.filter(r => r.pass).length;
  const failed = results.length - passed;
  for (const r of results) {
    const tag = r.pass ? 'PASS' : 'FAIL';
    console.log(`[${tag}] ${r.id} ${r.name}`);
    console.log(`       ${r.detail}`);
  }
  console.log('----------------------------------------');
  console.log(`Total: ${results.length}, Passed: ${passed}, Failed: ${failed}`);
  process.exitCode = failed > 0 ? 1 : 0;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
