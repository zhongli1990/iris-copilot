/**
 * Real-world lifecycle query regression runner.
 *
 * Reads tests/realworld-e2e-cases.json and validates chat outcomes via /api/chat.
 *
 * Usage:
 *   npm run e2e:realworld
 *
 * Optional env:
 *   BRIDGE_URL=http://localhost:3100
 *   NAMESPACE=DEMO2_AI2
 *   RUNNER=openai-codex-sdk
 */

import fs from 'node:fs';
import path from 'node:path';

type Json = Record<string, unknown>;

interface CaseExpected {
  actionTargetAny?: string[];
  requiresApproval?: boolean;
  responseIncludesAny?: string[];
  responseNotIncludes?: string[];
}

interface RealWorldCase {
  id: string;
  title: string;
  query: string;
  expected: CaseExpected;
}

interface CasesFile {
  version: string;
  namespace?: string;
  runner?: string;
  cases: RealWorldCase[];
}

const BRIDGE_URL = process.env.BRIDGE_URL || 'http://localhost:3100';

function isObject(value: unknown): value is Json {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter(v => typeof v === 'string') as string[] : [];
}

function readCases(): CasesFile {
  const p = path.resolve(process.cwd(), '..', 'tests', 'realworld-e2e-cases.json');
  const raw = fs.readFileSync(p, 'utf8');
  return JSON.parse(raw) as CasesFile;
}

async function callChat(query: string, namespace: string, runner: string): Promise<Json> {
  const res = await fetch(`${BRIDGE_URL}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      conversationId: `rw-${Date.now()}-${Math.floor(Math.random() * 10000)}`,
      message: query,
      namespace,
      preferredRunner: runner,
    }),
  });
  const text = await res.text();
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`Invalid JSON from /api/chat: ${text.slice(0, 220)}`);
  }
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 260)}`);
  if (!isObject(json)) throw new Error('Unexpected non-object chat response.');
  return json;
}

function includesAny(haystack: string, needles: string[]): boolean {
  if (needles.length === 0) return true;
  const h = haystack.toLowerCase();
  return needles.some(n => h.includes(n.toLowerCase()));
}

function includesNone(haystack: string, needles: string[]): boolean {
  if (needles.length === 0) return true;
  const h = haystack.toLowerCase();
  return needles.every(n => !h.includes(n.toLowerCase()));
}

function evaluateCase(testCase: RealWorldCase, rsp: Json): { pass: boolean; checks: string[] } {
  const checks: string[] = [];
  let pass = true;

  const responseText = String(rsp.response || '');
  const actions = asArray(rsp.actions);
  const firstAction = (actions[0] || {}) as Json;
  const firstTarget = String(firstAction.target || '');
  const firstRequiresApproval = Boolean(firstAction.requiresApproval ?? false);

  if (testCase.expected.actionTargetAny && testCase.expected.actionTargetAny.length > 0) {
    const ok = testCase.expected.actionTargetAny.includes(firstTarget);
    checks.push(`target in ${JSON.stringify(testCase.expected.actionTargetAny)} => actual '${firstTarget}' : ${ok ? 'PASS' : 'FAIL'}`);
    if (!ok) pass = false;
  }

  if (typeof testCase.expected.requiresApproval === 'boolean') {
    const ok = firstRequiresApproval === testCase.expected.requiresApproval;
    checks.push(`requiresApproval=${testCase.expected.requiresApproval} => actual ${firstRequiresApproval} : ${ok ? 'PASS' : 'FAIL'}`);
    if (!ok) pass = false;
  }

  const mustAny = testCase.expected.responseIncludesAny || [];
  const anyOk = includesAny(responseText, mustAny);
  checks.push(`response includes any ${JSON.stringify(mustAny)} : ${anyOk ? 'PASS' : 'FAIL'}`);
  if (!anyOk) pass = false;

  const mustNot = testCase.expected.responseNotIncludes || [];
  const noneOk = includesNone(responseText, mustNot);
  checks.push(`response excludes ${JSON.stringify(mustNot)} : ${noneOk ? 'PASS' : 'FAIL'}`);
  if (!noneOk) pass = false;

  return { pass, checks };
}

async function main() {
  const cfg = readCases();
  const namespace = process.env.NAMESPACE || cfg.namespace || 'DEMO2_AI2';
  const runner = process.env.RUNNER || cfg.runner || 'openai-codex-sdk';

  const outcomes: Array<Json> = [];
  let passed = 0;

  for (const c of cfg.cases) {
    try {
      const rsp = await callChat(c.query, namespace, runner);
      const evalResult = evaluateCase(c, rsp);
      if (evalResult.pass) passed++;
      outcomes.push({
        id: c.id,
        title: c.title,
        query: c.query,
        pass: evalResult.pass,
        checks: evalResult.checks,
        responsePreview: String(rsp.response || '').slice(0, 500),
        action: (asArray(rsp.actions)[0] || {}),
      });
    } catch (err) {
      outcomes.push({
        id: c.id,
        title: c.title,
        query: c.query,
        pass: false,
        checks: [err instanceof Error ? err.message : String(err)],
      });
    }
  }

  const failed = cfg.cases.length - passed;
  const report: Json = {
    generatedAt: new Date().toISOString(),
    version: cfg.version,
    namespace,
    runner,
    total: cfg.cases.length,
    passed,
    failed,
    outcomes,
  };

  const reportPath = path.resolve(process.cwd(), '..', 'tests', 'realworld-e2e-last-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2), 'utf8');

  for (const o of outcomes) {
    const ok = Boolean(o.pass);
    console.log(`[${ok ? 'PASS' : 'FAIL'}] ${String(o.id)} ${String(o.title)}`);
    for (const chk of asStringArray(o.checks)) {
      console.log(`       ${chk}`);
    }
  }
  console.log('----------------------------------------');
  console.log(`Total: ${cfg.cases.length}, Passed: ${passed}, Failed: ${failed}`);
  console.log(`Report: ${reportPath}`);
  process.exitCode = failed > 0 ? 1 : 0;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

