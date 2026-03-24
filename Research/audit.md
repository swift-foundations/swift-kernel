# Audit: swift-kernel

## Code Surface — 2026-03-24

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: code-surface — [API-NAME-001]–[API-NAME-004], [API-ERR-001]–[API-ERR-005], [API-IMPL-003], [API-IMPL-005]–[API-IMPL-009]
- **Files**: 67 source files across 6 targets

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | MEDIUM | [API-IMPL-008] | Kernel.Continuation.Context.swift | Methods and computed properties in class body | RESOLVED 2026-03-24 |
| 2 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Synchronization.swift | All methods in class body | RESOLVED 2026-03-24 |
| 3 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Gate.swift | Methods in class body | RESOLVED 2026-03-24 |
| 4 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Barrier.swift | Methods in class body | RESOLVED 2026-03-24 |
| 5 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Worker.Token.swift | Methods in class body | RESOLVED 2026-03-24 |
| 6 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Handle.Reference.swift | Method in class body | RESOLVED 2026-03-24 |
| 7 | MEDIUM | [API-NAME-002] | Kernel.Thread.Synchronization.swift | Public compound names: `broadcastAll()`, `waitTracked()`, `signalIfWaiters()`, `broadcastIfWaiters()` | DEFERRED — Property-primitives not yet a dependency; documented as WORKAROUND with removal criteria |
| 8 | MEDIUM | [API-NAME-002] | Kernel.Thread.Handle+joinChecked.swift:29 | Public compound name `joinChecked()` | DEFERRED — consuming ~Copyable prevents Property.View accessor; documented as WORKAROUND |
| 9 | LOW | [API-IMPL-006] | Kernel.File.Open.swift | File declares `Kernel.File.Open.Configuration` but is named after namespace. Should be `Kernel.File.Open.Configuration.swift`. | OPEN |
| 10 | LOW | [API-IMPL-008] | Kernel.Thread.Synchronization.Channel.swift | All methods in struct body | RESOLVED 2026-03-24 |

### Summary

10 findings: 0 critical, 0 high, 8 medium, 2 low. **7 resolved**, 2 deferred, 1 open.

All [API-IMPL-008] violations resolved — methods moved to extensions across 7 types. Two compound-name [API-NAME-002] findings remain deferred with documented workarounds.

---

## Implementation — 2026-03-24

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: implementation — [IMPL-INTENT], [IMPL-EXPR-001], [IMPL-000]–[IMPL-062], [PATTERN-009]–[PATTERN-053], [API-LAYER-001], [SEM-DEP-*]
- **Files**: 67 source files across 6 targets

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [IMPL-060] | Optional+take.swift | `Optional._take()` general-purpose utility belongs in ownership-primitives | RESOLVED 2026-03-24 — moved to swift-ownership-primitives as `Optional.take()`, removed from Kernel Core |
| 2 | MEDIUM | [IMPL-INTENT] | Kernel.File.Write+Shared.swift:17–88 | String-based path manipulation reimplements path parsing on `Swift.String` instead of using `Kernel.Path` APIs from L1 | OPEN |
| 3 | MEDIUM | [IMPL-041] | Kernel.File.Write.Error.swift:17–25 | Internal error type uses string messages — error context is lossy | OPEN |
| 4 | MEDIUM | [IMPL-002] | Kernel.Thread.Executors.swift:51 | `Int(options.count)` raw conversion from typed `Kernel.Thread.Count` | FALSE_POSITIVE — legitimate stdlib boundary per [IMPL-010]; uses purpose-built `Int(_ count:)` overload |
| 5 | MEDIUM | [IMPL-002] | Kernel.Thread.Executors.swift:70–71 | Mixed `UInt64`/`Int` arithmetic in round-robin index | RESOLVED 2026-03-24 — modulo computed in UInt64 domain, eliminating overflow trap |
| 6 | MEDIUM | [IMPL-INTENT] | Kernel.Failure.swift | Hardcoded `DWORD`/`FormatMessageW`/`strerror` — raw platform code in L3 | RESOLVED 2026-03-24 — delegated to platform packages (.posixMessage via swift-posix, .win32Message via swift-windows) per [PLAT-ARCH-008] |
| 7 | MEDIUM | [IMPL-EXPR-001] | Kernel.Thread.Gate.swift:57–66 | Manual lock/unlock with early return in `open()` | RESOLVED 2026-03-24 — refactored to `withLock`, broadcast moved outside lock |
| 8 | MEDIUM | [IMPL-060] | Kernel.File.Write.{Atomic,Streaming}.Error | `isNotFound`, `isPermissionDenied`, etc. semantic accessors duplicated verbatim across both error types | OPEN |
| 9 | LOW | [IMPL-002] | Kernel.Thread.Synchronization.swift:95 | `Int64(clamping: nanoseconds)` silently truncates `UInt64` timeout values exceeding `Int64.max` | OPEN |
| 10 | LOW | [IMPL-060] | Kernel.File.Write.Durability.swift | Three identical Durability enums with bridge methods | RESOLVED 2026-03-24 — unified into single `Kernel.File.Write.Durability`, deleted 2 duplicate files |

### Summary

10 findings: 0 critical, 1 high, 7 medium, 2 low. **5 resolved**, 1 false positive, 4 open.

Resolved: `Optional.take()` moved to ecosystem, Durability unified, Executors overflow fixed, Gate refactored to `withLock`, platform code delegated to platform packages. Remaining: string-based error bridge (#2, #3), error accessor duplication (#8), timeout clamping (#9).

---

## Modularization — 2026-03-24

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: modularization — [MOD-DOMAIN], [MOD-001]–[MOD-014]
- **Files**: 67 source files, 6 targets (Core, System, Thread, File, Continuation, Umbrella)

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [MOD-DOMAIN] | Package.swift | Single target bundled 4 semantic domains | RESOLVED 2026-03-24 — decomposed into 5 sub-targets + umbrella |
| 2 | HIGH | [MOD-001] | Package.swift | No Core target | RESOLVED 2026-03-24 — Kernel Core centralizes all external dependencies |
| 3 | HIGH | [MOD-003] | Package.swift | No variant decomposition | RESOLVED 2026-03-24 — File, Thread, System, Continuation are independent targets |
| 4 | HIGH | [MOD-005] | Sources/Kernel/ | Kernel target had implementation files | RESOLVED 2026-03-24 — umbrella now contains only exports.swift + Documentation.docc |
| 5 | MEDIUM | [MOD-002] | Exports.swift | Per-file imports bypassed centralized path | RESOLVED 2026-03-24 — imports cleaned up, all resolve via Core re-exports |
| 6 | MEDIUM | [MOD-006] | Package.swift | Single target forced all consumers to resolve all deps | RESOLVED 2026-03-24 — each sub-target declares only its own dependencies |
| 7 | MEDIUM | [MOD-006] | Package.swift | `Ownership_Primitives` transitive-only | RESOLVED 2026-03-24 — declared as explicit package dependency, re-exported via Core |
| 8 | MEDIUM | [MOD-006] | Package.swift | `Kernel_String_Primitives` transitive-only | RESOLVED 2026-03-24 — Kernel File declares direct dependency on Kernel String Primitives |
| 9 | MEDIUM | [MOD-008] | Package.swift | Split criteria met but not executed | RESOLVED 2026-03-24 |
| 10 | LOW | [MOD-013] | Package.swift | No MARK semantic group markers | RESOLVED 2026-03-24 — Package.swift uses `// MARK: -` for Core, System, Thread, File, Continuation, Umbrella, Test Support |

### Summary

10 findings: 0 critical, 4 high, 5 medium, 1 low. **All 10 resolved.**

### Executed Structure

```
Kernel Core               5 files   — re-exports, Failure, extensions
  ├── Kernel System       4 files   — processor count, memory total
  │     ↑
  ├── Kernel Thread      21 files   — executor, worker, synchronization, spawn
  ├── Kernel File        33 files   — write (atomic/streaming), clone, copy, open
  ├── Kernel Continuation 3 files   — async bridging (Context)
  │
  └── Kernel (umbrella)   2 files   — exports.swift + Documentation.docc
```

Published products unchanged. 91 tests passing. `swift-ownership-primitives` added as explicit dependency. Kernel File has direct dependency on `Kernel String Primitives` ([MOD-002] exception — Core doesn't need it).

---

## Legacy — Consolidated 2026-03-24

### From: swift-kernel-deep-audit.md (2026-03-19)

All findings superseded by fresh sections above or resolved during this session.

| # | Severity | Skill | Location | Finding | Status |
|---|----------|-------|----------|---------|--------|
| 1 | MEDIUM | platform | Kernel.Failure.swift | Direct `import Darwin`/`Glibc`/`Musl`/`WinSDK` for `strerror()`/`FormatMessageW` — L3 should route through platform packages [PLAT-ARCH-008] | RESOLVED 2026-03-24 — delegated to `.posixMessage` (swift-posix) and `.win32Message` (swift-windows) |

Previously tracked finding "6 boolean flags for preservation behavior — OptionSet would be more expressive" was also RESOLVED: `Kernel.File.Write.Atomic.Preservation` converted to `OptionSet`.

**All legacy findings resolved. Legacy section can be removed on next audit.**
