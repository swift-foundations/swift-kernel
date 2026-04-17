# swift-kernel Research Index

| Document | Topic | Date | Status |
|----------|-------|------|--------|
| [audit.md](audit.md) | Systematic code audit: code-surface, implementation, modularization, platform + batch-B modularization (MOD-001–MOD-014) | 2026-03-24 | ACTIVE |
| [conditional-compilation-public-enum-cases.md](conditional-compilation-public-enum-cases.md) | `#if !os(Windows)` on Kernel.Failure.signal: prior art, dependency chain, consumer impact | 2026-03-24 | DECISION |
| [kernel-thread-gate.md](kernel-thread-gate.md) | Kernel.Thread.Gate design, semantics, and implementation | 2026-03-20 | DECISION (SUPERSEDED — type moved to swift-threads 2026-04-14) |
| [kernel-event-driver-zero-allocation-redesign.md](kernel-event-driver-zero-allocation-redesign.md) | Zero-allocation poll, ~Copyable descriptor lifecycle, kevent helper extraction | 2026-04-09 | DECISION |
| [unified-completion-api-design.md](unified-completion-api-design.md) | Witness-based Completion API: ~Copyable state sharing, backend pattern, Event↔Completion symmetry | 2026-04-09 | IN_PROGRESS |
| [kernel-completion-driver-redesign.md](kernel-completion-driver-redesign.md) | Six proactor-specific design questions: drain semantics, descriptor ownership, flush witness, token lifecycle, boundaries, IOCP stub | 2026-04-09 | CONVERGED |
| [completion-architecture-audit.md](completion-architecture-audit.md) | L1 vocabulary purity audit: vestigial L1 finding, type-by-type [PLAT-ARCH-012] assessment, IOCP integration path | 2026-04-13 | DECISION |
| [main-thread-dispatch-abstraction.md](main-thread-dispatch-abstraction.md) | *(Relocated)* Executor.Main platform architecture research. Canonical doc now at [`swift-foundations/swift-executors/Research/executor-main-platform-architecture.md`](../../swift-executors/Research/executor-main-platform-architecture.md); this file is a redirect stub. Per [RES-002a] triage: decisions belong to swift-executors (the package that owns `Executor.Main`). | 2026-04-16 | SUPERSEDED |
