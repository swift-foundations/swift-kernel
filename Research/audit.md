# Audit: swift-kernel

## Code Surface — 2026-03-24

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: code-surface — [API-NAME-001]–[API-NAME-004], [API-ERR-001]–[API-ERR-005], [API-IMPL-003], [API-IMPL-005]–[API-IMPL-009]
- **Files**: 62 source files (Sources/Kernel/)

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | MEDIUM | [API-IMPL-008] | Kernel.Continuation.Context.swift:51–145 | Methods (`complete`, `cancel`, `fail`) and computed properties (`isResumed`, `state`) in class body. Nested `State` enum also in body. All should be in extensions. | OPEN |
| 2 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Synchronization.swift:38–249 | All methods (`lock`, `unlock`, `withLock`, `wait`, `signal`, `broadcast`, `waitTracked`, `signalIfWaiters`, `broadcastIfWaiters`, `broadcastAll`, `waiters`) in class body. Should be in extensions. | OPEN |
| 3 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Gate.swift:43–101 | Methods (`open`, `wait`, `wait(timeout:)`) and computed property (`isOpen`) in class body. Should be in extensions. | OPEN |
| 4 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Barrier.swift:30–77 | Methods (`arrive`) and computed property (`arrived`) in class body. Should be in extensions. | OPEN |
| 5 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Worker.Token.swift:28–46 | Computed property (`shouldStop`) and method (`requestStop`) in class body. Should be in extensions. | OPEN |
| 6 | MEDIUM | [API-IMPL-008] | Kernel.Thread.Handle.Reference.swift:40–67 | Method (`join`) in class body. `deinit` is permitted, but `join()` should be in an extension. | OPEN |
| 7 | MEDIUM | [API-NAME-002] | Kernel.Thread.Synchronization.swift:137,175,203,224,242 | Public compound names: `broadcastAll()`, `waitTracked()`, `waitTracked(condition:timeout:)`, `signalIfWaiters()`, `broadcastIfWaiters()` | DEFERRED — Property-primitives not yet a dependency; documented as WORKAROUND with removal criteria |
| 8 | MEDIUM | [API-NAME-002] | Kernel.Thread.Handle+joinChecked.swift:29 | Public compound name `joinChecked()` | DEFERRED — consuming ~Copyable prevents Property.View accessor; documented as WORKAROUND |
| 9 | LOW | [API-IMPL-006] | Kernel.File.Open.swift | File declares `Kernel.File.Open.Configuration` (line 24) but is named `Kernel.File.Open.swift`. Should be `Kernel.File.Open.Configuration.swift`, with the `Kernel.File.open()` extension (line 92) in a separate file. | OPEN |
| 10 | LOW | [API-IMPL-008] | Kernel.Thread.Synchronization.Channel.swift:26–90 | All methods in struct body. Should be in extensions. | OPEN |

### Summary

10 findings: 0 critical, 0 high, 8 medium, 2 low.

**Systemic pattern**: [API-IMPL-008] violations are concentrated in the Thread synchronization primitives (Gate, Barrier, Synchronization, Channel, Worker.Token, Handle.Reference) and the Continuation.Context class. All 7 instances follow the same pattern: `final class` or `struct` with all methods in the type body. Remediation is mechanical — move methods to extensions.

Two compound-name findings [API-NAME-002] are deferred with documented workarounds and specific removal criteria.

---

## Implementation — 2026-03-24

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: implementation — [IMPL-INTENT], [IMPL-EXPR-001], [IMPL-000]–[IMPL-062], [PATTERN-009]–[PATTERN-053], [API-LAYER-001], [SEM-DEP-*]
- **Files**: 62 source files (Sources/Kernel/)

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [IMPL-060] | Optional+take.swift | `Optional._take()` is a general-purpose `~Copyable` utility, not kernel-specific. Belongs in ownership-primitives or a similar foundational package. Every package needing this pattern must currently reimplement it. | OPEN |
| 2 | MEDIUM | [IMPL-INTENT] | Kernel.File.Write+Shared.swift:17–88 | String-based path manipulation (`posixParentDirectory`, `windowsParentDirectory`, `fileName`, `normalizeWindowsPath`) reimplements path parsing on `Swift.String` instead of using `Kernel.Path` APIs from L1. Round-trips through String for operations the path types likely already support. | OPEN |
| 3 | MEDIUM | [IMPL-041] | Kernel.File.Write.Error.swift:17–25 | Internal error type uses string messages (`.sync(String)`, `.close(String)`, `.rename(from:to:String)`, `.random(String)`). Error context is lossy — platform error codes and domain errors are flattened into interpolated strings, then re-parsed into structured public error types. | OPEN |
| 4 | MEDIUM | [IMPL-002] | Kernel.Thread.Executors.swift:51 | `(0..<Int(options.count)).map { _ in Executor() }` — `Int(options.count)` raw conversion from typed `Kernel.Thread.Count`. Should use typed range or iteration. | OPEN |
| 5 | MEDIUM | [IMPL-002] | Kernel.Thread.Executors.swift:70–71 | `Int(index) % executors.count` — mixed `UInt64`/`Int` arithmetic in round-robin index calculation. Raw extraction from atomic counter bypasses typed arithmetic. | OPEN |
| 6 | MEDIUM | [IMPL-INTENT] | Kernel.Failure.swift:178 | `let langId: DWORD = 0x0400` — hardcoded magic number for `MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)`. Should be a named constant or computed from the LANG_NEUTRAL/SUBLANG_DEFAULT constants. | OPEN |
| 7 | MEDIUM | [IMPL-EXPR-001] | Kernel.Thread.Gate.swift:57–66 | Manual `lock()`/`unlock()` with early return in `open()` — the state mutation could use `withLock { }` to eliminate the manual unlock-before-return path. | OPEN |
| 8 | MEDIUM | [IMPL-060] | Kernel.File.Write.{Atomic,Streaming}.Error | `isNotFound`, `isPermissionDenied`, `isReadOnly`, `isNoSpace`, `isDestinationExists` semantic accessors are duplicated verbatim across `Atomic.Error` and `Streaming.Error`. Could be unified via a shared protocol or common type. | OPEN |
| 9 | LOW | [IMPL-002] | Kernel.Thread.Synchronization.swift:95 | `Int64(clamping: nanoseconds)` silently truncates `UInt64` timeout values exceeding `Int64.max`. No diagnostic or documentation of clamping behavior. | OPEN |
| 10 | LOW | [IMPL-060] | Kernel.File.Write.Durability.swift | Three identical `Durability` enums (`Write.Durability`, `Atomic.Durability`, `Streaming.Durability`) with identical cases (`full`, `dataOnly`, `none`) and bridge methods (`.unified`). Could be a single shared type. | OPEN |

### Summary

10 findings: 0 critical, 1 high, 7 medium, 2 low.

**Systemic patterns**:
- **String-based error bridging** (#3): The internal `Kernel.File.Write.Error` acts as a lossy bridge between domain errors and the public error types. Platform error codes are interpolated into strings, then re-parsed into structured error codes (hardcoded to `.POSIX.EIO`). This loses the original error domain information.
- **Type duplication** (#8, #10): The Atomic and Streaming write APIs share identical error accessor logic and identical durability enums. A common protocol or shared base type would eliminate ~200 lines of duplication.
- **Raw type extraction** (#4, #5): Thread executor pool code bypasses typed arithmetic infrastructure.

---

## Modularization — 2026-03-24

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: modularization — [MOD-DOMAIN], [MOD-001]–[MOD-014]
- **Files**: 62 source files, 1 target (`Kernel`)

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [MOD-DOMAIN] | Package.swift | Single `Kernel` target bundles 4 semantic domains: File I/O (30 files), Thread (20 files), System (3 files), Continuation (2 files), plus shared infrastructure (7 files) | OPEN |
| 2 | HIGH | [MOD-001] | Package.swift | No Core target — 11 external product dependencies on monolithic target, no dependency funnel | OPEN |
| 3 | HIGH | [MOD-003] | Package.swift | No variant decomposition — File I/O, Threading, System, Continuation share one compilation unit | OPEN |
| 4 | HIGH | [MOD-005] | Sources/Kernel/ | `Kernel` target has 62 implementation files — not a zero-implementation umbrella | OPEN |
| 5 | MEDIUM | [MOD-002] | Exports.swift + per-file imports | Re-exports exist in Exports.swift but per-file imports bypass centralized path: `Ownership_Primitives` (2 files), `Kernel_String_Primitives` + `String_Primitives` (1 file), `Synchronization` (3 files), `Cardinal_Primitives` (1 file) | OPEN |
| 6 | MEDIUM | [MOD-006] | Package.swift:42–53 | Single target forces all consumers to resolve all 11 deps — File I/O consumers must resolve Queue Primitives (Thread-only); System consumers must resolve Reference Primitives (Thread-only) | OPEN |
| 7 | MEDIUM | [MOD-006] | Package.swift | `Ownership_Primitives` imported by `Kernel.Thread.spawn.swift` and `Kernel.Thread.Executor.swift` but not declared as package-level dependency — transitive resolution only | OPEN |
| 8 | MEDIUM | [MOD-006] | Package.swift | `Kernel_String_Primitives` and `String_Primitives` imported by `Swift.String+Kernel.swift` with no corresponding target dependency — transitive resolution only | OPEN |
| 9 | MEDIUM | [MOD-008] | Package.swift | All 4 domains meet split criteria: different dependency sets (Thread needs Ownership, File needs String primitives, System needs neither), independent consumer value, semantic independence. Remediation designed but not executed. | OPEN |
| 10 | LOW | [MOD-013] | Package.swift | No `// MARK: -` semantic group markers — currently 4 targets (below 5-target threshold) but no structure for post-modularization | OPEN |

### Summary

10 findings: 0 critical, 4 high, 5 medium, 1 low.

swift-kernel bundles 4 orthogonal semantic domains into a single 62-file target, violating [MOD-DOMAIN], [MOD-001], [MOD-003], and [MOD-005]. Two undeclared transitive dependencies (`Ownership_Primitives`, `Kernel_String_Primitives`) would surface as build failures during modularization.

### Remediation: 5 Sub-Targets + Umbrella

**Outcome**: Published product `Kernel` stays identical (umbrella re-export). Zero downstream breakage. Zero access-level changes.

**Target structure** (max depth 2):

```
Kernel Core               6 files   — re-exports, Failure, small extensions
  ├── Kernel System       3 files   — processor count, memory total
  │     ↑
  ├── Kernel Thread      20 files   — executor, worker, synchronization, spawn
  ├── Kernel File        31 files   — write (atomic, streaming), clone, copy, open
  ├── Kernel Continuation 2 files   — async bridging (Context)
  │
  └── Kernel (umbrella)   1 file    — @_exported re-exports only
```

**Cross-domain dependencies** (only 2 exist):

1. **Thread → System**: `Kernel.System.Processor.count` in `Executors.Options` — drives Kernel Thread → Kernel System.
2. **File → Process.ID**: `Kernel.Process.ID.current` in `Atomic+API` — resolves via Core (L1 type). NOT a cross-L3-target dependency.

**New package dependency**: `swift-ownership-primitives` must be declared explicitly. Currently resolves transitively. Core's `exports.swift` adds `@_exported public import Ownership_Primitives`.

**File assignment** (Kernel Core):

| File | Reason |
|------|--------|
| `exports.swift` | [MOD-002] centralized re-exports |
| `Kernel.Failure.swift` | Cross-domain error aggregator |
| `Kernel.Lock.Acquire+timeout.swift` | Extension on primitives type |
| `Kernel.Process.ID+CustomStringConvertible.swift` | Retroactive conformance |
| `Optional+take.swift` | Stdlib extension used by Thread (note: audit IMPL #1 flags this for ownership-primitives) |
| `Tagged+Kernel.Atomic.Flag.swift` | Stdlib extension on Tagged |

**File assignment** (variants): Kernel System (3 files: `Kernel.System.*`), Kernel Thread (20 files: `Kernel.Thread.*`), Kernel File (31 files: `Kernel.File.*` + `Swift.String+Kernel.swift`), Kernel Continuation (2 files: `Kernel.Continuation.*`).

**Kernel File [MOD-002] exception**: Directly depends on `.product(name: "Kernel String Primitives", package: "swift-kernel-primitives")` because Core doesn't need string primitives — only File does.

**Key Package.swift targets**:

```swift
// MARK: - Core
.target(name: "Kernel Core", dependencies: [
    .product(name: "Kernel Primitives", package: "swift-kernel-primitives"),
    .product(name: "System Primitives", package: "swift-system-primitives"),
    .product(name: "Reference Primitives", package: "swift-reference-primitives"),
    .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
    .product(name: "Dimension Primitives", package: "swift-dimension-primitives"),
    .product(name: "Queue Primitives", package: "swift-queue-primitives"),
    .product(name: "POSIX Kernel", package: "swift-posix", condition: ...),
    .product(name: "Darwin Kernel", package: "swift-darwin", condition: ...),
    .product(name: "Darwin System", package: "swift-darwin", condition: ...),
    .product(name: "Linux Kernel", package: "swift-linux", condition: ...),
    .product(name: "Linux System", package: "swift-linux", condition: ...),
    .product(name: "Windows Kernel", package: "swift-windows", condition: ...),
]),
// MARK: - System
.target(name: "Kernel System", dependencies: ["Kernel Core"]),
// MARK: - Thread
.target(name: "Kernel Thread", dependencies: ["Kernel Core", "Kernel System"]),
// MARK: - File
.target(name: "Kernel File", dependencies: [
    "Kernel Core",
    .product(name: "Kernel String Primitives", package: "swift-kernel-primitives"),
]),
// MARK: - Continuation
.target(name: "Kernel Continuation", dependencies: ["Kernel Core"]),
// MARK: - Umbrella
.target(name: "Kernel", dependencies: [
    "Kernel Core", "Kernel System", "Kernel Thread",
    "Kernel File", "Kernel Continuation",
]),
```

**Import cleanup** (during file move):

- Remove `public import Ownership_Primitives` from `Kernel.Thread.spawn.swift` (now via Core)
- Remove `internal import Ownership_Primitives` from `Kernel.Thread.Executor.swift` (now via Core)
- Remove `public import Cardinal_Primitives` from `Kernel.Thread.Count.swift` (via Core → Kernel Primitives)
- Remove direct platform imports from `Kernel.Thread.Affinity.swift` (via Core)
- Keep `#if canImport(Darwin) internal import Darwin` in `Kernel.Failure.swift` — these are C modules for `strerror`, not the platform packages

**What does NOT change**: Products (`Kernel`, `Kernel Test Support`), access levels, `@inlinable` annotations, test structure, downstream consumers (8 packages import `Kernel` product — unchanged).

**Verification**:

1. `swift build` from swift-kernel — all targets compile
2. `swift test` from swift-kernel — all existing tests pass
3. `swift build` from swift-io and swift-file-system — downstream consumers unaffected
4. Umbrella `Sources/Kernel/` contains only `exports.swift`

**Risks**:

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `String_Primitives` not transitively available to Kernel File | Low | Add `swift-string-primitives` as explicit package dep |
| `Ownership_Primitives` addition changes resolved graph | Low | Already used; just making implicit dep explicit |
| Downstream build breakage | Very low | Product name and API surface unchanged |

---

## Legacy — Consolidated 2026-03-24

### From: swift-kernel-deep-audit.md (2026-03-19)

Comprehensive audit covering implementation, code-surface, and platform layering. Code-surface and implementation findings are superseded by the fresh sections above. Platform finding retained:

| # | Severity | Skill | Location | Finding | Status |
|---|----------|-------|----------|---------|--------|
| 1 | MEDIUM | platform | Kernel.Failure.swift:91,146–150 | Direct `import Darwin`/`Glibc`/`Musl`/`WinSDK` for `strerror()`/`FormatMessageW` — L3 should route through platform packages [PLAT-ARCH-008] | OPEN |

Previously tracked finding "6 boolean flags for preservation behavior — OptionSet would be more expressive" is now RESOLVED: `Kernel.File.Write.Atomic.Preservation` was converted to `OptionSet` (confirmed in current code).

**Resolved findings from original audit** (11 items — for traceability, see git history at 2026-03-19).
