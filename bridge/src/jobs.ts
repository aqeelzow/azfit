import { randomUUID } from "node:crypto";

// A small in-memory job queue. Jobs run one at a time, so the bridge never
// starts several Claude Code processes at once against your plan's limits.
// Finished jobs are kept for a day so the phone can collect them, then dropped.

export type JobStatus = "queued" | "running" | "done" | "failed";

export interface Job {
  id: string;
  kind: string;
  status: JobStatus;
  created: string;
  finished?: string;
  result?: unknown;
  error?: string;
}

export type Runner = (input: unknown) => Promise<unknown>;

const KEEP_MS = 24 * 60 * 60 * 1000;

export class JobQueue {
  private jobs = new Map<string, Job>();
  private inputs = new Map<string, unknown>();
  private waiting: string[] = [];
  private running = false;
  private listeners = new Map<string, Array<() => void>>();

  private runners: Record<string, Runner>;

  constructor(runners: Record<string, Runner>) {
    this.runners = runners;
  }

  has(kind: string): boolean {
    return kind in this.runners;
  }

  add(kind: string, input: unknown): Job {
    this.prune();
    const job: Job = { id: randomUUID(), kind, status: "queued", created: new Date().toISOString() };
    this.jobs.set(job.id, job);
    this.inputs.set(job.id, input);
    this.waiting.push(job.id);
    void this.pump();
    return job;
  }

  get(id: string): Job | undefined {
    return this.jobs.get(id);
  }

  /** Resolves when the job finishes or after `ms`, whichever comes first. */
  wait(id: string, ms: number): Promise<Job | undefined> {
    const job = this.jobs.get(id);
    if (!job || job.status === "done" || job.status === "failed" || ms <= 0) return Promise.resolve(job);
    return new Promise((resolve) => {
      const done = () => {
        clearTimeout(timer);
        resolve(this.jobs.get(id));
      };
      const timer = setTimeout(() => {
        const list = this.listeners.get(id) ?? [];
        this.listeners.set(id, list.filter((f) => f !== done));
        resolve(this.jobs.get(id));
      }, ms);
      this.listeners.set(id, [...(this.listeners.get(id) ?? []), done]);
    });
  }

  private async pump(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      while (this.waiting.length > 0) {
        const id = this.waiting.shift()!;
        const job = this.jobs.get(id)!;
        const input = this.inputs.get(id);
        this.inputs.delete(id); // don't keep personal data around longer than needed
        job.status = "running";
        try {
          job.result = await this.runners[job.kind]!(input);
          job.status = "done";
        } catch (e) {
          job.status = "failed";
          job.error = (e as Error).message;
        }
        job.finished = new Date().toISOString();
        for (const f of this.listeners.get(id) ?? []) f();
        this.listeners.delete(id);
      }
    } finally {
      this.running = false;
    }
  }

  private prune(): void {
    const cutoff = Date.now() - KEEP_MS;
    for (const [id, job] of this.jobs) {
      if (job.finished && Date.parse(job.finished) < cutoff) this.jobs.delete(id);
    }
  }
}
