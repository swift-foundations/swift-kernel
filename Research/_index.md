# swift-kernel Research Index

| Document | Topic | Date | Status |
|----------|-------|------|--------|
| [audit.md](audit.md) | Systematic code audit: code-surface, implementation, modularization, platform + batch-B modularization (MOD-001–MOD-014) | 2026-03-24 | ACTIVE |
| [conditional-compilation-public-enum-cases.md](conditional-compilation-public-enum-cases.md) | `#if !os(Windows)` on Kernel.Failure.signal: prior art, dependency chain, consumer impact | 2026-03-24 | DECISION |
| [kernel-thread-gate.md](kernel-thread-gate.md) | Kernel.Thread.Gate design, semantics, and implementation | 2026-03-20 | DECISION |
| [kernel-event-driver-zero-allocation-redesign.md](kernel-event-driver-zero-allocation-redesign.md) | Zero-allocation poll, ~Copyable descriptor lifecycle, kevent helper extraction | 2026-04-09 | DECISION |
| [unified-completion-api-design.md](unified-completion-api-design.md) | Witness-based Completion API: ~Copyable state sharing, backend pattern, Event↔Completion symmetry | 2026-04-09 | IN_PROGRESS |
