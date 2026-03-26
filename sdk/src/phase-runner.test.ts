import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PhaseRunner, PhaseRunnerError } from './phase-runner.js';
import type { PhaseRunnerDeps, VerificationOutcome } from './phase-runner.js';
import type {
  PhaseOpInfo,
  PlanResult,
  SessionUsage,
  SessionOptions,
  HumanGateCallbacks,
  GSDEvent,
} from './types.js';
import { PhaseStepType, PhaseType, GSDEventType } from './types.js';
import type { GSDConfig } from './config.js';
import { CONFIG_DEFAULTS } from './config.js';

// ─── Mock modules ────────────────────────────────────────────────────────────

// Mock session-runner to avoid real SDK calls
vi.mock('./session-runner.js', () => ({
  runPhaseStepSession: vi.fn(),
  runPlanSession: vi.fn(),
}));

import { runPhaseStepSession } from './session-runner.js';

const mockRunPhaseStepSession = vi.mocked(runPhaseStepSession);

// ─── Factory helpers ─────────────────────────────────────────────────────────

function makePhaseOp(overrides: Partial<PhaseOpInfo> = {}): PhaseOpInfo {
  return {
    phase_found: true,
    phase_dir: '/tmp/project/.planning/phases/01-auth',
    phase_number: '1',
    phase_name: 'Authentication',
    phase_slug: 'auth',
    padded_phase: '01',
    has_research: false,
    has_context: false,
    has_plans: true,
    has_verification: false,
    plan_count: 1,
    roadmap_exists: true,
    planning_exists: true,
    commit_docs: true,
    context_path: '/tmp/project/.planning/phases/01-auth/CONTEXT.md',
    research_path: '/tmp/project/.planning/phases/01-auth/RESEARCH.md',
    ...overrides,
  };
}

function makeUsage(): SessionUsage {
  return {
    inputTokens: 100,
    outputTokens: 50,
    cacheReadInputTokens: 0,
    cacheCreationInputTokens: 0,
  };
}

function makePlanResult(overrides: Partial<PlanResult> = {}): PlanResult {
  return {
    success: true,
    sessionId: 'sess-123',
    totalCostUsd: 0.01,
    durationMs: 1000,
    usage: makeUsage(),
    numTurns: 5,
    ...overrides,
  };
}

function makeConfig(overrides: Partial<GSDConfig> = {}): GSDConfig {
  return {
    ...structuredClone(CONFIG_DEFAULTS),
    ...overrides,
    workflow: {
      ...CONFIG_DEFAULTS.workflow,
      ...(overrides.workflow ?? {}),
    },
  } as GSDConfig;
}

function makeDeps(overrides: Partial<PhaseRunnerDeps> = {}): PhaseRunnerDeps {
  const events: GSDEvent[] = [];

  return {
    projectDir: '/tmp/project',
    tools: {
      initPhaseOp: vi.fn().mockResolvedValue(makePhaseOp()),
      phaseComplete: vi.fn().mockResolvedValue(undefined),
      exec: vi.fn(),
      stateLoad: vi.fn(),
      roadmapAnalyze: vi.fn(),
      commit: vi.fn(),
      verifySummary: vi.fn(),
      initExecutePhase: vi.fn(),
      configGet: vi.fn(),
      stateBeginPhase: vi.fn(),
    } as any,
    promptFactory: {
      buildPrompt: vi.fn().mockResolvedValue('test prompt'),
    } as any,
    contextEngine: {
      resolveContextFiles: vi.fn().mockResolvedValue({}),
    } as any,
    eventStream: {
      emitEvent: vi.fn((event: GSDEvent) => events.push(event)),
      on: vi.fn(),
      emit: vi.fn(),
    } as any,
    config: makeConfig(),
    ...overrides,
  };
}

/** Collect events from a deps object. */
function getEmittedEvents(deps: PhaseRunnerDeps): GSDEvent[] {
  const events: GSDEvent[] = [];
  const emitFn = deps.eventStream.emitEvent as ReturnType<typeof vi.fn>;
  for (const call of emitFn.mock.calls) {
    events.push(call[0] as GSDEvent);
  }
  return events;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('PhaseRunner', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockRunPhaseStepSession.mockResolvedValue(makePlanResult());
  });

  // ─── Happy path ────────────────────────────────────────────────────────

  describe('happy path — full lifecycle', () => {
    it('runs all steps in order: discuss → research → plan → execute → verify → advance', async () => {
      const phaseOp = makePhaseOp({ has_context: false, has_plans: true, plan_count: 1 });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      expect(result.success).toBe(true);
      expect(result.phaseNumber).toBe('1');
      expect(result.phaseName).toBe('Authentication');

      // Verify steps ran in order
      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).toEqual([
        PhaseStepType.Discuss,
        PhaseStepType.Research,
        PhaseStepType.Plan,
        PhaseStepType.Execute,
        PhaseStepType.Verify,
        PhaseStepType.Advance,
      ]);

      // All steps succeeded
      expect(result.steps.every(s => s.success)).toBe(true);
    });

    it('returns correct phase name from PhaseOpInfo', async () => {
      const phaseOp = makePhaseOp({ phase_name: 'Data Layer' });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('2');

      expect(result.phaseName).toBe('Data Layer');
    });
  });

  // ─── Config-driven skipping ────────────────────────────────────────────

  describe('config-driven step skipping', () => {
    it('skips discuss when has_context=true', async () => {
      const phaseOp = makePhaseOp({ has_context: true });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).not.toContain(PhaseStepType.Discuss);
      expect(result.success).toBe(true);
    });

    it('skips discuss when config.workflow.skip_discuss=true', async () => {
      const config = makeConfig({ workflow: { skip_discuss: true } as any });
      const deps = makeDeps({ config });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).not.toContain(PhaseStepType.Discuss);
    });

    it('skips research when config.workflow.research=false', async () => {
      const config = makeConfig({ workflow: { research: false } as any });
      const deps = makeDeps({ config });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).not.toContain(PhaseStepType.Research);
    });

    it('skips verify when config.workflow.verifier=false', async () => {
      const config = makeConfig({ workflow: { verifier: false } as any });
      const deps = makeDeps({ config });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).not.toContain(PhaseStepType.Verify);
    });

    it('runs with all config flags false — only plan, execute, advance', async () => {
      const config = makeConfig({
        workflow: {
          skip_discuss: true,
          research: false,
          verifier: false,
        } as any,
      });
      const phaseOp = makePhaseOp({ has_context: false, has_plans: true, plan_count: 1 });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).toEqual([
        PhaseStepType.Plan,
        PhaseStepType.Execute,
        PhaseStepType.Advance,
      ]);
    });
  });

  // ─── Execute iterates plans ────────────────────────────────────────────

  describe('execute step', () => {
    it('iterates multiple plans sequentially', async () => {
      const phaseOp = makePhaseOp({ has_context: true, plan_count: 3 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const executeStep = result.steps.find(s => s.step === PhaseStepType.Execute);
      expect(executeStep).toBeDefined();
      expect(executeStep!.planResults).toHaveLength(3);

      // runPhaseStepSession called once per plan in execute step
      // (plus once for plan step itself)
      const executeCallCount = mockRunPhaseStepSession.mock.calls.filter(
        call => call[1] === PhaseStepType.Execute,
      ).length;
      expect(executeCallCount).toBe(3);
    });

    it('handles zero plans gracefully', async () => {
      const phaseOp = makePhaseOp({ has_context: true, plan_count: 0, has_plans: true });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const executeStep = result.steps.find(s => s.step === PhaseStepType.Execute);
      expect(executeStep).toBeDefined();
      expect(executeStep!.success).toBe(true);
      expect(executeStep!.planResults).toHaveLength(0);
    });

    it('captures mid-execute session failure in PlanResults', async () => {
      const phaseOp = makePhaseOp({ has_context: true, plan_count: 2 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      let callCount = 0;
      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Execute) {
          callCount++;
          if (callCount === 2) {
            return makePlanResult({
              success: false,
              error: { subtype: 'error_during_execution', messages: ['Session crashed'] },
            });
          }
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const executeStep = result.steps.find(s => s.step === PhaseStepType.Execute);
      expect(executeStep!.planResults).toHaveLength(2);
      expect(executeStep!.planResults![0].success).toBe(true);
      expect(executeStep!.planResults![1].success).toBe(false);
      expect(executeStep!.success).toBe(false); // overall execute step fails
    });
  });

  // ─── Blocker callbacks ─────────────────────────────────────────────────

  describe('blocker callbacks', () => {
    it('invokes onBlockerDecision when no plans after plan step', async () => {
      // First call: initial state (no context so discuss runs)
      // After discuss: re-query returns has_context=true
      // After plan: re-query returns has_plans=false
      const onBlockerDecision = vi.fn().mockResolvedValue('stop');
      const phaseOp = makePhaseOp({ has_context: true, has_plans: false, plan_count: 0 });
      const config = makeConfig();
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: { onBlockerDecision },
      });

      expect(onBlockerDecision).toHaveBeenCalled();
      const callArg = onBlockerDecision.mock.calls[0][0];
      expect(callArg.step).toBe(PhaseStepType.Plan);
      expect(callArg.error).toContain('No plans');

      // Runner halted — no execute/verify/advance steps
      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).not.toContain(PhaseStepType.Execute);
      expect(stepTypes).not.toContain(PhaseStepType.Verify);
      expect(stepTypes).not.toContain(PhaseStepType.Advance);
    });

    it('invokes onBlockerDecision when no context after discuss', async () => {
      const onBlockerDecision = vi.fn().mockResolvedValue('stop');
      const phaseOp = makePhaseOp({ has_context: false });
      const deps = makeDeps();
      // After discuss step, re-query still has no context
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: { onBlockerDecision },
      });

      expect(onBlockerDecision).toHaveBeenCalled();
      const callArg = onBlockerDecision.mock.calls[0][0];
      expect(callArg.step).toBe(PhaseStepType.Discuss);
    });

    it('auto-approves (skip) when no callback registered at discuss blocker', async () => {
      const phaseOp = makePhaseOp({ has_context: false, has_plans: true, plan_count: 1 });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1'); // no callbacks

      // Should proceed past discuss even though no context
      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).toContain(PhaseStepType.Research);
      expect(stepTypes).toContain(PhaseStepType.Plan);
    });
  });

  // ─── Human gate: reject halts runner ───────────────────────────────────

  describe('human gate reject', () => {
    it('halts runner when blocker callback returns stop', async () => {
      const phaseOp = makePhaseOp({ has_context: false });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: {
          onBlockerDecision: vi.fn().mockResolvedValue('stop'),
        },
      });

      expect(result.success).toBe(false);
      // Only discuss step ran before halt
      expect(result.steps).toHaveLength(1);
      expect(result.steps[0].step).toBe(PhaseStepType.Discuss);
    });
  });

  // ─── Verification routing ──────────────────────────────────────────────

  describe('verification routing', () => {
    it('routes to advance when verification passes', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);
      mockRunPhaseStepSession.mockResolvedValue(makePlanResult({ success: true }));

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).toContain(PhaseStepType.Verify);
      expect(stepTypes).toContain(PhaseStepType.Advance);
      expect(result.success).toBe(true);
    });

    it('invokes onVerificationReview when verification returns human_needed', async () => {
      const onVerificationReview = vi.fn().mockResolvedValue('accept');
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      // Verify step returns human_review_needed subtype
      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Verify) {
          return makePlanResult({
            success: false,
            error: { subtype: 'human_review_needed', messages: ['Needs review'] },
          });
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: { onVerificationReview },
      });

      expect(onVerificationReview).toHaveBeenCalled();
      expect(result.success).toBe(true); // callback accepted
    });

    it('halts when verification review callback rejects', async () => {
      const onVerificationReview = vi.fn().mockResolvedValue('reject');
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Verify) {
          return makePlanResult({
            success: false,
            error: { subtype: 'human_review_needed', messages: ['Needs review'] },
          });
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: { onVerificationReview },
      });

      // Verify step completes with error, runner continues to advance
      const verifyStep = result.steps.find(s => s.step === PhaseStepType.Verify);
      expect(verifyStep!.success).toBe(false);
      expect(verifyStep!.error).toBe('halted_by_callback');
    });
  });

  // ─── Gap closure ───────────────────────────────────────────────────────

  describe('gap closure', () => {
    it('retries verification once on gaps_found', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      let verifyCallCount = 0;
      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Verify) {
          verifyCallCount++;
          if (verifyCallCount === 1) {
            // First verify: gaps found
            return makePlanResult({
              success: false,
              error: { subtype: 'verification_failed', messages: ['Gaps found'] },
            });
          }
          // Second verify (gap closure retry): passes
          return makePlanResult({ success: true });
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      expect(verifyCallCount).toBe(2); // Exactly 1 retry
      expect(result.success).toBe(true);
    });

    it('caps gap closure at exactly 1 retry (not 0, not 2)', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      let verifyCallCount = 0;
      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Verify) {
          verifyCallCount++;
          // Always return gaps_found
          return makePlanResult({
            success: false,
            error: { subtype: 'verification_failed', messages: ['Gaps persist'] },
          });
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      // 1 initial + 1 retry = 2 calls (not 3)
      expect(verifyCallCount).toBe(2);
      // Verify step still succeeds (gap closure exhausted → proceed)
      const verifyStep = result.steps.find(s => s.step === PhaseStepType.Verify);
      expect(verifyStep!.success).toBe(true);
    });
  });

  // ─── Phase lifecycle events ────────────────────────────────────────────

  describe('phase lifecycle events', () => {
    it('emits events in correct order', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await runner.run('1');

      const events = getEmittedEvents(deps);
      const eventTypes = events.map(e => e.type);

      // First event: phase_start
      expect(eventTypes[0]).toBe(GSDEventType.PhaseStart);

      // Last event: phase_complete
      expect(eventTypes[eventTypes.length - 1]).toBe(GSDEventType.PhaseComplete);

      // Each step has start + complete pair
      const stepStarts = events.filter(e => e.type === GSDEventType.PhaseStepStart);
      const stepCompletes = events.filter(e => e.type === GSDEventType.PhaseStepComplete);
      expect(stepStarts.length).toBeGreaterThan(0);
      expect(stepStarts.length).toBe(stepCompletes.length);
    });

    it('phase_start event contains correct phaseNumber and phaseName', async () => {
      const phaseOp = makePhaseOp({ has_context: true, phase_name: 'Auth Phase' });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await runner.run('5');

      const events = getEmittedEvents(deps);
      const phaseStart = events.find(e => e.type === GSDEventType.PhaseStart) as any;
      expect(phaseStart.phaseNumber).toBe('5');
      expect(phaseStart.phaseName).toBe('Auth Phase');
    });

    it('phase_complete event reports success and step count', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await runner.run('1');

      const events = getEmittedEvents(deps);
      const phaseComplete = events.find(e => e.type === GSDEventType.PhaseComplete) as any;
      expect(phaseComplete.success).toBe(true);
      expect(phaseComplete.stepsCompleted).toBe(3); // plan, execute, advance
    });

    it('step_start events include correct step type', async () => {
      const phaseOp = makePhaseOp({ has_context: false, has_plans: true, plan_count: 1 });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await runner.run('1');

      const events = getEmittedEvents(deps);
      const stepStarts = events
        .filter(e => e.type === GSDEventType.PhaseStepStart)
        .map(e => (e as any).step);

      // With all config defaults: discuss, research, plan, execute, verify, advance
      expect(stepStarts).toContain(PhaseStepType.Discuss);
      expect(stepStarts).toContain(PhaseStepType.Research);
      expect(stepStarts).toContain(PhaseStepType.Plan);
      expect(stepStarts).toContain(PhaseStepType.Execute);
      expect(stepStarts).toContain(PhaseStepType.Verify);
      expect(stepStarts).toContain(PhaseStepType.Advance);
    });
  });

  // ─── Error propagation ─────────────────────────────────────────────────

  describe('error propagation', () => {
    it('throws PhaseRunnerError when phase not found', async () => {
      const phaseOp = makePhaseOp({ phase_found: false });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await expect(runner.run('99')).rejects.toThrow(PhaseRunnerError);
      await expect(runner.run('99')).rejects.toThrow(/not found/);
    });

    it('throws PhaseRunnerError when initPhaseOp fails', async () => {
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockRejectedValue(
        new Error('gsd-tools crashed'),
      );

      const runner = new PhaseRunner(deps);
      await expect(runner.run('1')).rejects.toThrow(PhaseRunnerError);
      await expect(runner.run('1')).rejects.toThrow(/Failed to initialize/);
    });

    it('captures session errors in PhaseStepResult without throwing', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Plan) {
          return makePlanResult({
            success: false,
            error: { subtype: 'error_during_execution', messages: ['Session exploded'] },
          });
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const planStep = result.steps.find(s => s.step === PhaseStepType.Plan);
      expect(planStep!.success).toBe(false);
      expect(planStep!.error).toContain('Session exploded');
      // Runner continues to execute/advance even after plan error
    });

    it('captures thrown errors from runPhaseStepSession in step result', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Plan) {
          throw new Error('Network error');
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const planStep = result.steps.find(s => s.step === PhaseStepType.Plan);
      expect(planStep!.success).toBe(false);
      expect(planStep!.error).toBe('Network error');
    });
  });

  // ─── Advance step ──────────────────────────────────────────────────────

  describe('advance step', () => {
    it('calls tools.phaseComplete on auto_advance', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true, auto_advance: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await runner.run('1');

      expect(deps.tools.phaseComplete).toHaveBeenCalledWith('1');
    });

    it('auto-approves advance when no callback and auto_advance=false', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true, auto_advance: false } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      expect(deps.tools.phaseComplete).toHaveBeenCalled();
      const advanceStep = result.steps.find(s => s.step === PhaseStepType.Advance);
      expect(advanceStep!.success).toBe(true);
    });

    it('halts advance when callback returns stop', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true, auto_advance: false } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);
      const onBlockerDecision = vi.fn().mockResolvedValue('stop');

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: { onBlockerDecision },
      });

      const advanceStep = result.steps.find(s => s.step === PhaseStepType.Advance);
      expect(advanceStep!.success).toBe(false);
      expect(advanceStep!.error).toBe('advance_rejected');
      expect(deps.tools.phaseComplete).not.toHaveBeenCalled();
    });

    it('captures phaseComplete errors without throwing', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true, auto_advance: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);
      (deps.tools.phaseComplete as ReturnType<typeof vi.fn>).mockRejectedValue(
        new Error('gsd-tools commit failed'),
      );

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      const advanceStep = result.steps.find(s => s.step === PhaseStepType.Advance);
      expect(advanceStep!.success).toBe(false);
      expect(advanceStep!.error).toContain('commit failed');
    });
  });

  // ─── Callback error handling ───────────────────────────────────────────

  describe('callback error handling', () => {
    it('auto-approves when blocker callback throws', async () => {
      const phaseOp = makePhaseOp({ has_context: false, has_plans: true, plan_count: 1 });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: {
          onBlockerDecision: vi.fn().mockRejectedValue(new Error('callback broke')),
        },
      });

      // Should auto-approve (skip) and continue
      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).toContain(PhaseStepType.Research);
    });

    it('auto-accepts when verification callback throws', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Verify) {
          return makePlanResult({
            success: false,
            error: { subtype: 'human_review_needed', messages: ['Review'] },
          });
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: {
          onVerificationReview: vi.fn().mockRejectedValue(new Error('callback broke')),
        },
      });

      // Should auto-accept and proceed to advance
      const stepTypes = result.steps.map(s => s.step);
      expect(stepTypes).toContain(PhaseStepType.Advance);
    });

    it('auto-approves advance when advance callback throws', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true, auto_advance: false } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1', {
        callbacks: {
          onBlockerDecision: vi.fn().mockRejectedValue(new Error('nope')),
        },
      });

      // Advance should auto-approve on callback error
      expect(deps.tools.phaseComplete).toHaveBeenCalled();
    });
  });

  // ─── Cost tracking ─────────────────────────────────────────────────────

  describe('result aggregation', () => {
    it('aggregates cost across all steps', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 2 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      mockRunPhaseStepSession.mockResolvedValue(makePlanResult({ totalCostUsd: 0.05 }));

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      // plan step: 1 session × $0.05
      // execute step: 2 sessions × $0.05
      // total = $0.15
      expect(result.totalCostUsd).toBeCloseTo(0.15, 2);
    });

    it('reports overall success=false when any step fails', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      mockRunPhaseStepSession.mockImplementation(async (_prompt, step) => {
        if (step === PhaseStepType.Plan) {
          return makePlanResult({ success: false, error: { subtype: 'error', messages: ['fail'] } });
        }
        return makePlanResult();
      });

      const runner = new PhaseRunner(deps);
      const result = await runner.run('1');

      expect(result.success).toBe(false);
    });
  });

  // ─── PromptFactory / ContextEngine integration ─────────────────────────

  describe('prompt and context integration', () => {
    it('calls contextEngine.resolveContextFiles with correct PhaseType per step', async () => {
      const phaseOp = makePhaseOp({ has_context: false, has_plans: true, plan_count: 1 });
      const deps = makeDeps();
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await runner.run('1');

      const resolveCallArgs = (deps.contextEngine.resolveContextFiles as ReturnType<typeof vi.fn>)
        .mock.calls.map((call: any) => call[0]);

      expect(resolveCallArgs).toContain(PhaseType.Discuss);
      expect(resolveCallArgs).toContain(PhaseType.Research);
      expect(resolveCallArgs).toContain(PhaseType.Plan);
      expect(resolveCallArgs).toContain(PhaseType.Execute);
      expect(resolveCallArgs).toContain(PhaseType.Verify);
    });

    it('passes prompt from PromptFactory to runPhaseStepSession', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 0 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);
      (deps.promptFactory.buildPrompt as ReturnType<typeof vi.fn>).mockResolvedValue('custom plan prompt');

      const runner = new PhaseRunner(deps);
      await runner.run('1');

      // Plan step: check that the prompt was passed through
      const planCall = mockRunPhaseStepSession.mock.calls.find(
        call => call[1] === PhaseStepType.Plan,
      );
      expect(planCall).toBeDefined();
      expect(planCall![0]).toBe('custom plan prompt');
    });
  });

  // ─── Session options pass-through ──────────────────────────────────────

  describe('session options', () => {
    it('passes maxBudgetPerStep and maxTurnsPerStep to sessions', async () => {
      const phaseOp = makePhaseOp({ has_context: true, has_plans: true, plan_count: 1 });
      const config = makeConfig({ workflow: { research: false, verifier: false, skip_discuss: true } as any });
      const deps = makeDeps({ config });
      (deps.tools.initPhaseOp as ReturnType<typeof vi.fn>).mockResolvedValue(phaseOp);

      const runner = new PhaseRunner(deps);
      await runner.run('1', {
        maxBudgetPerStep: 2.0,
        maxTurnsPerStep: 20,
        model: 'claude-opus-4-6',
      });

      // Check session options passed to runPhaseStepSession
      const call = mockRunPhaseStepSession.mock.calls[0];
      const sessionOpts = call[3] as SessionOptions;
      expect(sessionOpts.maxBudgetUsd).toBe(2.0);
      expect(sessionOpts.maxTurns).toBe(20);
      expect(sessionOpts.model).toBe('claude-opus-4-6');
    });
  });
});
