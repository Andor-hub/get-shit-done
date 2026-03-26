/**
 * Integration test — proves PhaseRunner state machine works against real gsd-tools.cjs.
 *
 * Creates a temp `.planning/` directory structure, instantiates real GSDTools,
 * and exercises the state machine. Sessions will fail (no Claude CLI in CI) but
 * the state machine's control flow, event emission, and error capture are proven.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { homedir } from 'node:os';

import { GSDTools } from './gsd-tools.js';
import { PhaseRunner } from './phase-runner.js';
import type { PhaseRunnerDeps } from './phase-runner.js';
import { ContextEngine } from './context-engine.js';
import { PromptFactory } from './phase-prompt.js';
import { GSDEventStream } from './event-stream.js';
import { loadConfig } from './config.js';
import type { GSDEvent } from './types.js';
import { GSDEventType, PhaseStepType } from './types.js';

// ─── Helpers ─────────────────────────────────────────────────────────────────

const GSD_TOOLS_PATH = join(homedir(), '.claude', 'get-shit-done', 'bin', 'gsd-tools.cjs');

async function createTempPlanningDir(): Promise<string> {
  const tmpDir = await mkdtemp(join(tmpdir(), 'gsd-sdk-phase-int-'));

  // Create .planning structure
  const planningDir = join(tmpDir, '.planning');
  const phasesDir = join(planningDir, 'phases');
  const phaseDir = join(phasesDir, '01-integration-test');

  await mkdir(phaseDir, { recursive: true });

  // config.json
  await writeFile(
    join(planningDir, 'config.json'),
    JSON.stringify({
      model_profile: 'balanced',
      commit_docs: false,
      workflow: {
        research: true,
        verifier: true,
        auto_advance: true,
        skip_discuss: false,
      },
    }),
  );

  // ROADMAP.md — required for roadmap_exists
  await writeFile(join(planningDir, 'ROADMAP.md'), '# Roadmap\n\n## Phase 01: Integration Test\n');

  // CONTEXT.md in phase dir — triggers has_context=true → discuss is skipped
  await writeFile(
    join(phaseDir, 'CONTEXT.md'),
    '# Context\n\nThis is an integration test phase with pre-existing context.\n',
  );

  return tmpDir;
}

// ─── Test suite ──────────────────────────────────────────────────────────────

describe('Integration: PhaseRunner against real gsd-tools.cjs', () => {
  let tmpDir: string;
  let tools: GSDTools;

  beforeAll(async () => {
    tmpDir = await createTempPlanningDir();
    tools = new GSDTools({
      projectDir: tmpDir,
      gsdToolsPath: GSD_TOOLS_PATH,
      timeoutMs: 10_000,
    });
  });

  afterAll(async () => {
    if (tmpDir) {
      await rm(tmpDir, { recursive: true, force: true });
    }
  });

  // ── Test 1: initPhaseOp returns valid PhaseOpInfo ──

  it('initPhaseOp returns valid PhaseOpInfo for temp phase', async () => {
    const info = await tools.initPhaseOp('01');

    expect(info.phase_found).toBe(true);
    expect(info.phase_number).toBe('01');
    expect(info.phase_name).toBe('integration-test');
    expect(info.phase_dir).toBe('.planning/phases/01-integration-test');
    expect(info.has_context).toBe(true);
    expect(info.has_plans).toBe(false);
    expect(info.plan_count).toBe(0);
    expect(info.roadmap_exists).toBe(true);
    expect(info.planning_exists).toBe(true);
  });

  it('initPhaseOp returns phase_found=false for nonexistent phase', async () => {
    const info = await tools.initPhaseOp('99');

    expect(info.phase_found).toBe(false);
    expect(info.has_context).toBe(false);
    expect(info.plan_count).toBe(0);
  });

  // ── Test 2: PhaseRunner state machine control flow ──

  it('PhaseRunner emits lifecycle events and captures session errors gracefully', { timeout: 300_000 }, async () => {
    const eventStream = new GSDEventStream();
    const config = await loadConfig(tmpDir);
    const contextEngine = new ContextEngine(tmpDir);
    const promptFactory = new PromptFactory();

    const events: GSDEvent[] = [];
    eventStream.on('event', (e: GSDEvent) => events.push(e));

    const deps: PhaseRunnerDeps = {
      projectDir: tmpDir,
      tools,
      promptFactory,
      contextEngine,
      eventStream,
      config,
    };

    const runner = new PhaseRunner(deps);
    // Tight budget/turns so each session finishes fast
    const result = await runner.run('01', {
      maxTurnsPerStep: 2,
      maxBudgetPerStep: 0.10,
    });

    // ── (a) Phase start event emitted ──
    const phaseStartEvents = events.filter(e => e.type === GSDEventType.PhaseStart);
    expect(phaseStartEvents).toHaveLength(1);
    const phaseStart = phaseStartEvents[0]!;
    if (phaseStart.type === GSDEventType.PhaseStart) {
      expect(phaseStart.phaseNumber).toBe('01');
      expect(phaseStart.phaseName).toBe('integration-test');
    }

    // ── (b) Discuss should be skipped (has_context=true) ──
    // No discuss step in results since it was skipped
    const discussSteps = result.steps.filter(s => s.step === PhaseStepType.Discuss);
    expect(discussSteps).toHaveLength(0);

    // ── (c) Step start events emitted for attempted steps ──
    const stepStartEvents = events.filter(e => e.type === GSDEventType.PhaseStepStart);
    expect(stepStartEvents.length).toBeGreaterThanOrEqual(1);

    // ── (d) Step results are properly structured ──
    // With CLI available, sessions may succeed or fail depending on budget/turns.
    // Either way, each step result must have correct structure.
    expect(result.steps.length).toBeGreaterThanOrEqual(1);
    for (const step of result.steps) {
      expect(Object.values(PhaseStepType)).toContain(step.step);
      expect(typeof step.success).toBe('boolean');
      expect(typeof step.durationMs).toBe('number');
      // Failed steps may or may not have an error message
      // (e.g. advance step can fail without explicit error string)
    }

    // ── (e) Phase complete event emitted ──
    const phaseCompleteEvents = events.filter(e => e.type === GSDEventType.PhaseComplete);
    expect(phaseCompleteEvents).toHaveLength(1);

    // ── (f) Result structure is valid ──
    expect(result.phaseNumber).toBe('01');
    expect(result.phaseName).toBe('integration-test');
    expect(typeof result.totalCostUsd).toBe('number');
    expect(typeof result.totalDurationMs).toBe('number');
    expect(result.totalDurationMs).toBeGreaterThan(0);
  });

  // ── Test 3: PhaseRunner with nonexistent phase throws ──

  it('PhaseRunner throws PhaseRunnerError for nonexistent phase', async () => {
    const eventStream = new GSDEventStream();
    const config = await loadConfig(tmpDir);
    const contextEngine = new ContextEngine(tmpDir);
    const promptFactory = new PromptFactory();

    const deps: PhaseRunnerDeps = {
      projectDir: tmpDir,
      tools,
      promptFactory,
      contextEngine,
      eventStream,
      config,
    };

    const runner = new PhaseRunner(deps);
    await expect(runner.run('99')).rejects.toThrow('Phase 99 not found on disk');
  });

  // ── Test 4: GSD.runPhase() public API delegates correctly ──

  it('GSD.runPhase() creates collaborators and delegates to PhaseRunner', { timeout: 300_000 }, async () => {
    // Import GSD here to test the public API wiring
    const { GSD } = await import('./index.js');

    const gsd = new GSD({ projectDir: tmpDir });
    const events: GSDEvent[] = [];
    gsd.onEvent((e) => events.push(e));

    const result = await gsd.runPhase('01', {
      maxTurnsPerStep: 2,
      maxBudgetPerStep: 0.10,
    });

    // Proves the full wiring works: GSD → PhaseRunner → GSDTools → gsd-tools.cjs
    expect(result.phaseNumber).toBe('01');
    expect(result.phaseName).toBe('integration-test');
    expect(result.steps.length).toBeGreaterThanOrEqual(1);
    expect(events.some(e => e.type === GSDEventType.PhaseStart)).toBe(true);
    expect(events.some(e => e.type === GSDEventType.PhaseComplete)).toBe(true);
  });
});
