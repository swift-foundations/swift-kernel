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
| 7 | MEDIUM | [API-NAME-002] | Kernel.Thread.Synchronization.swift | Public compound names: `broadcastAll()`, `waitTracked()`, `signalIfWaiters()`, `broadcastIfWaiters()` | DEFERRED — Property-primitives not yet a dependency; documented as WORKAROUND with removal criteria | Verified: 2026-04-01 |
| 8 | MEDIUM | [API-NAME-002] | Kernel.Thread.Handle+joinChecked.swift:29 | Public compound name `joinChecked()` | DEFERRED — consuming ~Copyable prevents Property.View accessor; documented as WORKAROUND | Verified: 2026-04-01 |
| 9 | LOW | [API-IMPL-006] | Kernel.File.Open.swift | File declares `Kernel.File.Open.Configuration` but is named after namespace | RESOLVED 2026-03-24 — split into Kernel.File.Open.Configuration.swift + Kernel.File.Open.swift |
| 10 | LOW | [API-IMPL-008] | Kernel.Thread.Synchronization.Channel.swift | All methods in struct body | RESOLVED 2026-03-24 |

### Summary

10 findings: 0 critical, 0 high, 8 medium, 2 low. **8 resolved**, 2 deferred, 0 open.

All [API-IMPL-008] violations resolved — methods moved to extensions across 7 types. File naming split completed. Two compound-name [API-NAME-002] findings remain deferred with documented workarounds.

---

## Implementation — 2026-04-09

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: implementation — [IMPL-INTENT], [IMPL-000]–[IMPL-075], [PATTERN-009]–[PATTERN-053], [API-LAYER-001], [SEM-DEP-*]
- **Files**: 68 source files across 6 targets (includes new Kernel.Completion+IOUring.swift)

### Systemic Pattern — io_uring Ring Protocol

The epoll driver achieves zero raw C types because L1 provides typed wrappers (`Kernel.Event.Poll.create/ctl/wait`). The io_uring driver lacks equivalent L1 ring abstractions, so Ring hand-rolls the shared-memory protocol with raw pointers and UInt32 arithmetic. **Findings 11–20 are all consequences of this L1 infrastructure gap.** The fix is a typed `Kernel.IO.Uring.Ring` at L1 in swift-linux-primitives — the individual findings resolve as corollaries.

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [IMPL-060] | Optional+take.swift | `Optional._take()` general-purpose utility belongs in ownership-primitives | RESOLVED 2026-03-24 |
| 2 | MEDIUM | [IMPL-INTENT] | Kernel.File.Write+Shared.swift:17–88 | String-based path manipulation reimplements path parsing on `Swift.String` instead of using `Kernel.Path` APIs from L1 | OPEN |
| 3 | MEDIUM | [IMPL-041] | Kernel.File.Write.Error.swift:17–25 | Internal error type uses string messages — error context is lossy | OPEN |
| 4 | MEDIUM | [IMPL-002] | Kernel.Thread.Executors.swift:51 | `Int(options.count)` raw conversion from typed `Kernel.Thread.Count` | FALSE_POSITIVE — legitimate stdlib boundary per [IMPL-010] |
| 5 | MEDIUM | [IMPL-002] | Kernel.Thread.Executors.swift:70–71 | Mixed `UInt64`/`Int` arithmetic in round-robin index | RESOLVED 2026-03-24 |
| 6 | MEDIUM | [IMPL-INTENT] | Kernel.Failure.swift | Hardcoded `DWORD`/`FormatMessageW`/`strerror` — raw platform code in L3 | RESOLVED 2026-03-24 |
| 7 | MEDIUM | [IMPL-EXPR-001] | Kernel.Thread.Gate.swift:57–66 | Manual lock/unlock with early return in `open()` | RESOLVED 2026-03-24 |
| 8 | MEDIUM | [IMPL-060] | Kernel.File.Write.{Atomic,Streaming}.Error | `isNotFound`, `isPermissionDenied`, etc. semantic accessors duplicated verbatim across both error types | OPEN |
| 9 | LOW | [IMPL-002] | Kernel.Thread.Synchronization.swift:100 | `Int64(clamping: nanoseconds)` silently truncates `UInt64` timeout values exceeding `Int64.max` | OPEN |
| 10 | LOW | [IMPL-060] | Kernel.File.Write.Durability.swift | Three identical Durability enums with bridge methods | RESOLVED 2026-03-24 |
| 11 | **HIGH** | [IMPL-060] | Kernel.Completion+IOUring.swift (Ring class) | Ring reimplements standard io_uring SQ/CQ shared-memory ring protocol (head/tail indexing, masking, SQE slot allocation, CQE iteration) — identical protocol every io_uring user implements. Should be typed L1 ring accessors in swift-linux-primitives | OPEN |
| 12 | **HIGH** | [IMPL-006] | Kernel.Completion+IOUring.swift:70–80 | Seven raw `UnsafeMutablePointer<UInt32>` / `UnsafePointer` stored properties for SQ/CQ ring head, tail, array, sqes, cqes. Should be typed L1 ring accessor | OPEN |
| 13 | **HIGH** | [IMPL-002] | Kernel.Completion+IOUring.swift:233–245 | enqueue() uses raw UInt32 wrapping arithmetic: `sqEntries &- (tail &- sqHead.pointee)`, `Int(tail & sqMask)`, `sqArray[idx] = UInt32(idx)`. Should be typed L1 ring operation | OPEN |
| 14 | **HIGH** | [IMPL-002] | Kernel.Completion+IOUring.swift:276–294 | drain() uses raw UInt32 masking: `cqes[Int(head & cqMask)]`, `head &+= 1`. Should be typed L1 CQ ring drain | OPEN |
| 15 | MEDIUM | [IMPL-002] | Kernel.Completion+IOUring.swift:289,299,332,338,370,376 | `.rawValue` extraction for Length/Offset conversions: `Kernel.IO.Uring.Length(submission.length.rawValue)`. Should use `.map()` or `.retag()` per [INFRA-103] | OPEN |
| 16 | MEDIUM | [IMPL-002] | Kernel.Completion+IOUring.swift:277–279 | `__unchecked` construction of `Operation.Data` from `token.rawValue`. Should use functor path | OPEN |
| 17 | MEDIUM | [IMPL-002] | Kernel.Completion+IOUring.swift:283 | `Kernel.Completion.Token(cqe.data.rawValue)` — rawValue extraction for CQE→Event token. Should use `.map()` or `.retag()` | OPEN |
| 18 | MEDIUM | [IMPL-002] | Kernel.Completion+IOUring.swift:400 | `sqe.pointee.flags = sqeFlags.rawValue` — L1 SQE should accept `Flags` type directly | OPEN |
| 19 | MEDIUM | [IMPL-002] | Kernel.Completion+IOUring.swift:404–406 | `Buffer.Group(rawValue: submission.bufferGroup.rawValue)` — should have typed conversion | OPEN |
| 20 | MEDIUM | [IMPL-010] | Kernel.Completion+IOUring.swift:147–149,206–216 | Ring size computation and pointer setup with 12× raw `Int()` conversions at call site. Should be encapsulated in L1 ring factory | OPEN |

### Summary

20 findings: 0 critical, 5 high, 11 medium, 4 low. **5 resolved**, 1 false positive, 14 open.

Prior findings: string-based error bridge (#2, #3), error accessor duplication (#8), timeout clamping (#9) remain open.

**io_uring findings (#11–20)**: 4 high, 6 medium — all caused by missing L1 typed ring abstractions. Resolution path: create `Kernel.IO.Uring.Ring` in swift-linux-primitives that encapsulates the shared-memory SQ/CQ protocol, then refactor Ring class to delegate (matching the epoll driver pattern).

---

## Modularization — 2026-03-24

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations)
- **Skill**: modularization — [MOD-DOMAIN], [MOD-001]–[MOD-014]
- **Files**: 67 source files, 6 targets (Core, System, Thread, File, Continuation, Umbrella)

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [MOD-DOMAIN] | Package.swift | Single target bundled 4 semantic domains | RESOLVED 2026-03-24 — decomposed into 5 sub-targets + umbrella | Verified: 2026-04-01 |
| 2 | HIGH | [MOD-001] | Package.swift | No Core target | RESOLVED 2026-03-24 — Kernel Core centralizes all external dependencies | Verified: 2026-04-01 |
| 3 | HIGH | [MOD-003] | Package.swift | No variant decomposition | RESOLVED 2026-03-24 — File, Thread, System, Continuation are independent targets | Verified: 2026-04-01 |
| 4 | HIGH | [MOD-005] | Sources/Kernel/ | Kernel target had implementation files | RESOLVED 2026-03-24 — umbrella now contains only exports.swift + Documentation.docc | Verified: 2026-04-01 |
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

## Platform — 2026-04-09

### Scope

- **Target**: swift-kernel (Layer 3 — Foundations, unified cross-platform module)
- **Skill**: platform — [PLAT-ARCH-001]–[PLAT-ARCH-011], [PATTERN-001]–[PATTERN-008]
- **Files**: 68 source files across 6 targets (includes new Kernel.Completion+IOUring.swift)

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [PATTERN-004a] | Kernel.System.Processor.Count.swift:21 | `#if canImport(Darwin)` uses `canImport` for platform identity | RESOLVED 2026-03-24 |
| 2 | HIGH | [PATTERN-004a] | Kernel.System.Memory.Total.swift:25,27 | `canImport` used for platform identity | RESOLVED 2026-03-24 |
| 3 | HIGH | [PATTERN-004a] | Kernel.System.Processor.Physical.Count.swift:29,31 | `canImport` used for platform identity | RESOLVED 2026-03-24 |
| 4 | HIGH | [PATTERN-004a] | Kernel.File.Open.swift:114 | `canImport(Darwin)` mixed with `#if os(Linux)` | RESOLVED 2026-03-24 |
| 5 | MEDIUM | [PLAT-ARCH-008] | Kernel.Failure.swift:90–92 | `public import WinSDK` leaks raw Windows SDK | RESOLVED 2026-03-24 |
| 6 | MEDIUM | [PLAT-ARCH-008] | Kernel.Failure.swift:46–49 | `#if !os(Windows)` on `.signal` enum case | DEFERRED — Irreducible POSIX concept; zero consumer impact. See [conditional-compilation-public-enum-cases.md](conditional-compilation-public-enum-cases.md) |
| 7 | **HIGH** | [PLAT-ARCH-008] | Kernel.Completion+IOUring.swift:147–221 | Ring.create() computes mmap sizes from io_uring kernel params, extracts raw mutable pointers, and performs 10× `.advanced(by:).assumingMemoryBound(to:)` pointer arithmetic to set up ring head/tail/array pointers. This is io_uring Linux platform mechanism living in L3. Belongs in L1 (swift-linux-primitives) as a typed ring factory | OPEN |
| 8 | **HIGH** | [PLAT-ARCH-005a] | Kernel.Completion+IOUring.swift:70–80 | Seven raw C pointer stored properties (`UnsafeMutablePointer<UInt32>` × 5, `UnsafeMutablePointer<SQE>`, `UnsafePointer<CQE>`). While private, these are io_uring platform types that should be abstracted behind L1 typed ring accessors. The epoll driver has zero raw C pointer stored properties | OPEN |
| 9 | MEDIUM | [PLAT-ARCH-005a] | Kernel.Completion+IOUring.swift:72,73,80,84 | Raw `UInt32` stored properties for `sqMask`, `sqEntries`, `cqMask`, `pendingCount` — io_uring ring quantities expressed as platform C integer type | OPEN |

### Summary

9 findings: 0 critical, 6 high, 3 medium. **5 resolved**, 1 deferred, 3 open.

Prior resolutions intact. **io_uring findings (#7–9)**: the Ring class contains Linux io_uring platform mechanism (pointer arithmetic, raw C types, shared-memory protocol) in L3. Resolution path: typed `Kernel.IO.Uring.Ring` at L1 absorbs the mechanism, Ring class delegates (matching epoll driver pattern).

**Clean areas**: `import Glibc`/`import Musl` eliminated (2026-04-09), mmap/munmap replaced with ecosystem `Kernel.Memory.Map` API, `#if os(Linux)` correct for L3 platform boundary. Re-export chain, Package.swift conditions, Swift 6 mode, feature flags, module naming all correct.

---

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-foundations.md (2026-04-03)

**Pre-publication audit — P0/P1/P2 checks**

#### P2: Methods in Type Bodies [API-IMPL-008]

| File:Line | Type | Members |
|-----------|------|---------|
| `Kernel.File.Write.Streaming.Context.swift:37` | `Context` | 8 |
| `Kernel.File.Write.Atomic.Options.swift:16` | `Options` | 5 |

Note: The 2026-03-24 code-surface audit (above) already addressed [API-IMPL-008] violations in class types. These two remaining findings from the cross-package audit are in struct types holding stored properties.

---

### From: swift-institute/Research/modularization-audit-foundations-batch-B.md (2026-03-20)

**Modularization audit (batch B) — MOD-001 through MOD-014**

2 products: Kernel, Kernel Test Support. Also has `_Lock Test Process` executable target.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns at this layer |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 10 deps on main target — large but all platform-conditional, justified by cross-platform unification role |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | REVIEW | 63 files in Kernel target — substantial but may be inherent to cross-platform unification |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | PASS | Kernel Test Support published as library product |
| MOD-012 | PASS | `Kernel`, `Kernel Test Support` — correct L3 naming |
| MOD-013 | N/A | 4 source targets, threshold is 5 (note: Package.swift has good internal comments even below threshold) |
| MOD-014 | N/A | Platform deps use `condition: .when(platforms:)` not traits — correct for always-needed platform abstraction |

**Findings**: 0 FAIL. 1 REVIEW (MOD-008): 63 files in Kernel is large but this is the cross-platform unification layer (Darwin + Linux + Windows + POSIX). Each platform variant is already in a separate package. Splitting Kernel further would require identifying sub-domains within the unified API (e.g., file descriptors, threads, signals). Worth investigating but not a clear violation.

**Note**: This batch-B audit assessed Kernel as a single-product package post-decomposition. The 2026-03-24 modularization section above documents the pre-decomposition state and the completed restructuring into Core + 4 sub-targets + umbrella.

---

## L3 Composition — 2026-04-20

### Scope

- **Target**: swift-kernel (L3 cross-platform unifier surface)
- **Skill**: platform — [PLAT-ARCH-008e] L3 Unifier Composition Discipline (sole rule)
- **Files**: 34 swift-kernel source files across 7 targets; read-only cross-check against 25 swift-posix, 7 swift-darwin, 20 swift-linux, 9 swift-windows source files, plus L2 standards (iso-9945, darwin-standard, linux-standard, windows-standard).

### Method

For every L3 platform-policy wrapper defined under `extension {POSIX,Darwin,Linux,Windows}.Kernel.*`, apply the three-check decision test from [PLAT-ARCH-008e]:

1. A method with the same name is inherited onto the `Kernel.T` unifier surface from L2 raw via namespace-alias extension.
2. An L3 platform-policy wrapper with that name exists at swift-posix / swift-darwin / swift-linux / swift-windows.
3. The L3 wrapper adds behavior (retry, partial-IO loop, completion-await, error normalization) rather than being a pure re-export.

All three yes → VIOLATION: consumers writing `import Kernel` silently receive raw L2 behavior with no compiler signal, bypassing the L3 policy tier's retry / completion / composition logic.

**Namespace-alias mechanism confirmed**:
- `ISO_9945.Kernel = Kernel_Primitives_Core.Kernel` ([`swift-iso-9945/Sources/ISO 9945 Core/ISO 9945.Kernel.swift:26`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Core/ISO%209945.Kernel.swift)). Every `extension ISO_9945.Kernel.T` adds to the same `Kernel.T` that `import Kernel` consumers see.
- `Windows.Kernel = Kernel_Primitives_Core.Kernel` ([`swift-microsoft/swift-windows-standard/Sources/Windows Kernel Standard Core/Windows.Kernel.swift:29`](../../../swift-microsoft/swift-windows-standard/Sources/Windows%20Kernel%20Standard%20Core/Windows.Kernel.swift)) — same effect on Windows.
- `POSIX.Kernel` is a SEPARATE `public enum` ([`swift-posix/Sources/POSIX Core/POSIX.Kernel.swift:25-31`](../../swift-posix/Sources/POSIX%20Core/POSIX.Kernel.swift)) — extensions on `POSIX.Kernel.T` do NOT flow to `Kernel.T`. This is by design per `swift-posix/Research/l3-policy-design.md` §"POSIX Enum vs Typealias"; it is what creates the shadow surface this rule flags.

**swift-kernel delegation check**: zero explicit `Kernel.{File.Flush,IO.Read,IO.Write,Socket.*}` method definitions in `swift-kernel/Sources/**`. Zero references to `POSIX.Kernel.{File.Flush,IO,Socket}` in swift-kernel source. swift-kernel consumes the `POSIX_Kernel` umbrella via `@_exported public import` ([`swift-kernel/Sources/Kernel Core/exports.swift:47`](../Sources/Kernel%20Core/exports.swift)), so the POSIX policy surface is VISIBLE to consumers — but only via explicit `POSIX.Kernel.*` call paths, which defeats the unifier's purpose per [PLAT-ARCH-008e].

### Enumeration summary

| Platform L3 | Methods adding behavior | Methods that shadow a Kernel.T.m |
|-------------|------------------------|----------------------------------|
| swift-posix | 25 (Flush × 4, IO.Read × 5, IO.Write × 6, Socket.Accept × 2, Socket.Send × 3, Socket.Receive × 3, Socket.Connect × 4) | 24 (1 novel composed op: `POSIX.Kernel.IO.Read.readAll` has no iso-9945 counterpart) |
| swift-darwin | 0 wrappers over L2 raw that shadow `Kernel.T.m` | 0 (novel L3 APIs only: `Darwin.Random.fill`, `System.Topology.NUMA.Discover.discover`) |
| swift-linux | 0 wrappers over L2 raw that shadow `Kernel.T.m` | 0 (novel L3 APIs only: `Linux.Random.fill`, `Linux.Thread.Affinity.apply`) |
| swift-windows | 0 wrappers over L2 raw that shadow `Kernel.T.m` | 0 (novel L3 APIs only: `Windows.Thread.Affinity.apply`, `Windows.Kernel.Glob.Match.match`, `System.Topology.NUMA.Discover.discover`, `Windows.Random.fill`) |

All detected violations are on the POSIX side. Darwin/Linux/Windows L3 packages currently host only novel L3 APIs (no method shadows the L2 raw surface inherited via namespace alias), so the rule does not apply there today.

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.File.Flush.swift:39`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.File.Flush.swift); L3 wrapper [`swift-posix/POSIX.Kernel.File.Flush.swift:43`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.File.Flush.swift) | `Kernel.File.Flush.flush(_:)` inherits raw `fsync()` from iso-9945 via namespace-alias extension. `POSIX.Kernel.File.Flush.flush(_:)` adds EINTR retry (`while true { try Kernel.File.Flush.flush(descriptor); return } catch where error.code.isInterrupted { continue }`). L2 doc-comment explicitly states "does NOT automatically retry on EINTR … For automatic EINTR retry, use the policy-aware wrapper in POSIX_Kernel" — consumers silently get raw behavior. Fix: explicit delegation in swift-kernel via peer L3 (swift-posix). | RESOLVED 2026-04-20 (f541a08) — explicit `Kernel.File.Flush.flush(_:)` cross-platform delegate landed at [`swift-kernel/Kernel.File.Flush+CrossPlatform.POSIX.swift`](../Sources/Kernel%20File/Kernel.File.Flush%2BCrossPlatform.POSIX.swift); routes through `POSIX.Kernel.File.Flush.flush` on POSIX, restoring EINTR retry per [PLAT-ARCH-008e]. Windows companion at [`swift-kernel/Kernel.File.Flush+CrossPlatform.Windows.swift`](../Sources/Kernel%20File/Kernel.File.Flush%2BCrossPlatform.Windows.swift). |
| 2 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.File.Flush.swift:72`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.File.Flush.swift) (`#if os(Linux)`); L3 wrapper [`swift-posix/POSIX.Kernel.File.Flush.swift:63`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.File.Flush.swift) | `Kernel.File.Flush.data(_:)` (Linux) inherits raw `fdatasync()` from iso-9945. `POSIX.Kernel.File.Flush.data(_:)` adds EINTR retry. Consumers silently get raw. | RESOLVED 2026-04-20 (e9bafc5) — `Kernel.File.Flush.data(_:)` is owned by per-platform extensions: `Darwin.Kernel.File.Flush.data` (swift-darwin `1d57f80`) and `Linux.Kernel.File.Flush.data` (swift-linux `43a43e0`). Both platform-`Kernel` typealias to `Kernel_Primitives.Kernel`, so those extensions land directly on `Kernel.File.Flush` — no swift-kernel cross-platform delegate needed (would be a redeclaration on the same underlying type). Per [PLAT-ARCH-002] + [PLAT-ARCH-008d]: each platform L3-policy package owns its `data` semantics directly. |
| 3 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.File.Flush.swift:104`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.File.Flush.swift) (`#if canImport(Darwin)`); L3 wrapper [`swift-posix/POSIX.Kernel.File.Flush.swift:87`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.File.Flush.swift) | `Kernel.File.Flush.full(_:)` (Darwin) inherits raw `fcntl(F_FULLFSYNC)` from iso-9945. `POSIX.Kernel.File.Flush.full(_:)` adds EINTR retry. | FALSE_POSITIVE — `HANDOFF-kernel-file-flush-unifiers.md` Phase A renames L2 `full` → `fullFsync`, eliminating the `Kernel.File.Flush.full` namespace-alias inheritance outright. After Phase A, there is no `Kernel.File.Flush.full(_:)` for a consumer to call. `full` is a Darwin-specific syscall with no cross-platform sibling; `POSIX.Kernel.File.Flush.full(_:)` is the intended terminal surface, and adding a cross-platform `Kernel.File.Flush.full(_:)` delegate is not warranted. No separate remediation needed. |
| 4 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.File.Flush.swift:131`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.File.Flush.swift) (`#if canImport(Darwin)`); L3 wrapper [`swift-posix/POSIX.Kernel.File.Flush.swift:109`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.File.Flush.swift) | `Kernel.File.Flush.barrier(_:)` (Darwin) inherits raw `fcntl(F_BARRIERFSYNC)` from iso-9945. `POSIX.Kernel.File.Flush.barrier(_:)` adds EINTR retry. | FALSE_POSITIVE — same shape as #3. `HANDOFF-kernel-file-flush-unifiers.md` Phase A renames L2 `barrier` → `barrierFsync`, eliminating the `Kernel.File.Flush.barrier` namespace-alias inheritance. `barrier` is Darwin-specific; `POSIX.Kernel.File.Flush.barrier(_:)` is the intended terminal surface. Phase C's cross-platform `Kernel.File.Flush.data(_:)` wrapping `barrierFsync` on Darwin handles the portable-consumer case; a standalone cross-platform `Kernel.File.Flush.barrier(_:)` is not warranted. No separate remediation needed. |
| 5 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.IO.Read.swift:33`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.IO.Read.swift) (raw buffer) & `:116` (span adapter); L3 wrapper [`swift-posix/POSIX.Kernel.IO.Read.swift:54`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.IO.Read.swift) & `:138` | `Kernel.IO.Read.read(_:, into:)` (both `UnsafeMutableRawBufferPointer` and `inout MutableSpan<UInt8>` overloads) inherits raw `read(2)` from iso-9945. `POSIX.Kernel.IO.Read.read(_:, into:)` adds EINTR retry at both overloads. Consumers silently get raw. Fix: explicit `Kernel.IO.Read.read(_:, into:)` in swift-kernel delegating to `POSIX.Kernel.IO.Read.read` on POSIX and to Windows-standard equivalent on Windows. | RESOLVED 2026-04-20 (24cf586) — POSIX cross-platform delegates landed at [`swift-kernel/Kernel.IO.Read+CrossPlatform.POSIX.swift`](../Sources/Kernel%20File/Kernel.IO.Read%2BCrossPlatform.POSIX.swift). Both overloads now route through `POSIX.Kernel.IO.Read.read`. Windows: no companion file — `Windows.Kernel == Kernel` means `Windows.Kernel.IO.Read.read` in windows-standard (L2) already surfaces as `Kernel.IO.Read.read`; Windows has no EINTR and swift-windows hosts no L3 policy wrapper, so the [PLAT-ARCH-008e] "L3 platform tier empty" exception applies. |
| 6 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.IO.Read.swift:72`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.IO.Read.swift) (raw buffer) & `:134` (span adapter); L3 wrapper [`swift-posix/POSIX.Kernel.IO.Read.swift:76`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.IO.Read.swift) & `:156` | `Kernel.IO.Read.pread(_:, into:, at:)` (both raw-buffer and span overloads) inherits raw `pread(2)` from iso-9945. `POSIX.Kernel.IO.Read.pread(_:, into:, at:)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (24cf586) — POSIX cross-platform delegates landed at [`swift-kernel/Kernel.IO.Read+CrossPlatform.POSIX.swift`](../Sources/Kernel%20File/Kernel.IO.Read%2BCrossPlatform.POSIX.swift). Both overloads now route through `POSIX.Kernel.IO.Read.pread`. Windows inherits `Windows.Kernel.IO.Read.pread` from windows-standard (L2) — [PLAT-ARCH-008e] "L3 platform tier empty" exception. |
| 7 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.IO.Write.swift:51`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.IO.Write.swift) (raw buffer) & `:179` (span adapter); L3 wrapper [`swift-posix/POSIX.Kernel.IO.Write.swift:60`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.IO.Write.swift) & `:146` | `Kernel.IO.Write.write(_:, from:)` (both raw-buffer and span overloads) inherits raw `write(2)` from iso-9945. `POSIX.Kernel.IO.Write.write(_:, from:)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (5b0ae3b) — POSIX cross-platform delegates landed at [`swift-kernel/Kernel.IO.Write+CrossPlatform.POSIX.swift`](../Sources/Kernel%20File/Kernel.IO.Write%2BCrossPlatform.POSIX.swift). Both overloads now route through `POSIX.Kernel.IO.Write.write`. Windows inherits `Windows.Kernel.IO.Write.write` from windows-standard (L2) — [PLAT-ARCH-008e] "L3 platform tier empty" exception. |
| 8 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.IO.Write.swift:103`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.IO.Write.swift) (raw buffer) & `:197` (span adapter); L3 wrapper [`swift-posix/POSIX.Kernel.IO.Write.swift:85`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.IO.Write.swift) & `:164` | `Kernel.IO.Write.pwrite(_:, from:, at:)` (both raw-buffer and span overloads) inherits raw `pwrite(2)` from iso-9945. `POSIX.Kernel.IO.Write.pwrite(_:, from:, at:)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (5b0ae3b) — POSIX cross-platform delegates landed at [`swift-kernel/Kernel.IO.Write+CrossPlatform.POSIX.swift`](../Sources/Kernel%20File/Kernel.IO.Write%2BCrossPlatform.POSIX.swift). Both overloads now route through `POSIX.Kernel.IO.Write.pwrite`. Windows inherits `Windows.Kernel.IO.Write.pwrite` from windows-standard (L2) — [PLAT-ARCH-008e] "L3 platform tier empty" exception. |
| 9 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.IO.Write.swift:142`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20File/ISO%209945.Kernel.IO.Write.swift) (raw buffer) & `:214` (span adapter); L3 wrapper [`swift-posix/POSIX.Kernel.IO.Write.swift:109`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.IO.Write.swift) & `:181` | `Kernel.IO.Write.writeAll(_:, from:)` inherits iso-9945's partial-write loop which calls raw `write` without retry — so interruption during the loop throws EINTR to the consumer. `POSIX.Kernel.IO.Write.writeAll(_:, from:)` layers EINTR retry on top of the partial-write loop. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (5b0ae3b) — POSIX cross-platform delegates landed at [`swift-kernel/Kernel.IO.Write+CrossPlatform.POSIX.swift`](../Sources/Kernel%20File/Kernel.IO.Write%2BCrossPlatform.POSIX.swift). Both overloads (raw-buffer and span) now route through `POSIX.Kernel.IO.Write.writeAll`, inheriting the `EINTR`-retry-wrapped partial-write loop. Windows has no `writeAll` in windows-standard today — cross-platform parity on Windows remains a separate architectural question. |
| 10 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Accept.swift:41`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Accept.swift) (`Socket.Descriptor` overload) & `:85` (`Descriptor` overload); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Accept.swift:54`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Accept.swift) & `:73` | `Kernel.Socket.Accept.accept(_:)` (both `Socket.Descriptor` and generic `Descriptor` overloads) inherits raw `accept(2)` from iso-9945. `POSIX.Kernel.Socket.Accept.accept(_:)` adds EINTR retry on both overloads. Server loops silently get raw. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (bfa092e) — POSIX cross-platform delegates initially landed at `swift-kernel/Sources/Kernel Core/Kernel.Socket.Accept+CrossPlatform.POSIX.swift`; **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Accept+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Accept%2BCrossPlatform.POSIX.swift)** (commits `2c63378` remove + `9a83433` add; reflection: `swift-institute/Research/Reflections/2026-04-20-socket-unifier-rfc-composition-and-swift-sockets-migration.md`). Both overloads now route through `POSIX.Kernel.Socket.Accept.accept`. Latent L2/L3 overload-resolution ambiguity (same shape as Read/Write Findings #5–#9) tracked in `swift-kernel/HANDOFF-socket-family-l2-l3-ambiguity.md`. Windows gap: `Kernel.Socket.Accept` namespace, `Accept.Result`, and `Address.Storage` are declared in iso-9945 (L2 POSIX spec); Winsock exposes accept with a bare-descriptor return and raw `sockaddr` pointer — not architecturally interchangeable with the POSIX typed surface today. Tracked alongside the Connect (Finding #17) Windows gap in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |
| 11 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Send.swift:35`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Send.swift); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Send.swift:43`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Send.swift) | `Kernel.Socket.Send.send(_:, from:, options:)` inherits raw `send(2)` from iso-9945. `POSIX.Kernel.Socket.Send.send(_:, from:, options:)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (6a6d527) — POSIX cross-platform delegate initially landed in swift-kernel; **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Send+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Send%2BCrossPlatform.POSIX.swift)** (`2c63378 + 9a83433`), routing through `POSIX.Kernel.Socket.Send.send`. Latent L2/L3 ambiguity tracked in `swift-kernel/HANDOFF-socket-family-l2-l3-ambiguity.md`. Windows gap: typed send surface (`Kernel.Socket.Message.Options` etc.) is declared in iso-9945 (L2 POSIX); `Windows.Kernel.Socket.send` uses different flag/buffer types via Winsock — tracked in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |
| 12 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Send.swift:65`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Send.swift); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Send.swift:68`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Send.swift) | `Kernel.Socket.Send.to(_:, from:, options:, address:, addressLength:)` inherits raw `sendto(2)` from iso-9945. `POSIX.Kernel.Socket.Send.to(…)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (6a6d527) — POSIX cross-platform delegate initially landed in swift-kernel; **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Send+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Send%2BCrossPlatform.POSIX.swift)** (`2c63378 + 9a83433`), routing through `POSIX.Kernel.Socket.Send.to`. No swift-sockets unifier counterpart for the `to(…)` overload today — no L2/L3 ambiguity to pre-empt here. Windows gap tracked in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |
| 13 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Send.swift:100`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Send.swift); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Send.swift:94`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Send.swift) | `Kernel.Socket.Send.message(_:, header:, options:)` inherits raw `sendmsg(2)` from iso-9945. `POSIX.Kernel.Socket.Send.message(…)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (6a6d527) — POSIX cross-platform delegate initially landed in swift-kernel; **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Send+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Send%2BCrossPlatform.POSIX.swift)** (`2c63378 + 9a83433`), routing through `POSIX.Kernel.Socket.Send.message`. Latent L2/L3 ambiguity tracked in `swift-kernel/HANDOFF-socket-family-l2-l3-ambiguity.md`. Windows gap: `Kernel.Socket.Message.Header` declared in iso-9945; Winsock has no direct `sendmsg` analogue in windows-standard today — tracked in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |
| 14 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Receive.swift:34`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Receive.swift); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Receive.swift:44`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Receive.swift) | `Kernel.Socket.Receive.receive(_:, into:, options:)` inherits raw `recv(2)` from iso-9945. `POSIX.Kernel.Socket.Receive.receive(…)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (5bd87f3) — POSIX cross-platform delegate initially landed in swift-kernel; **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Receive+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Receive%2BCrossPlatform.POSIX.swift)** (`2c63378 + 9a83433`), routing through `POSIX.Kernel.Socket.Receive.receive`. Latent L2/L3 ambiguity tracked in `swift-kernel/HANDOFF-socket-family-l2-l3-ambiguity.md`. Windows gap tracked in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |
| 15 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Receive.swift:62`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Receive.swift); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Receive.swift:68`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Receive.swift) | `Kernel.Socket.Receive.from(_:, into:, options:)` inherits raw `recvfrom(2)` from iso-9945. `POSIX.Kernel.Socket.Receive.from(…)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (5bd87f3) — POSIX cross-platform delegate initially landed in swift-kernel; **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Receive+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Receive%2BCrossPlatform.POSIX.swift)** (`2c63378 + 9a83433`), routing through `POSIX.Kernel.Socket.Receive.from`. No swift-sockets unifier counterpart for the `from(…)` overload today — no L2/L3 ambiguity to pre-empt here. Windows gap tracked in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |
| 16 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Receive.swift:102`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Receive.swift); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Receive.swift:92`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Receive.swift) | `Kernel.Socket.Receive.message(_:, header:, options:)` inherits raw `recvmsg(2)` from iso-9945. `POSIX.Kernel.Socket.Receive.message(…)` adds EINTR retry. Fix: explicit delegation in swift-kernel. | RESOLVED 2026-04-20 (5bd87f3) — POSIX cross-platform delegate initially landed in swift-kernel; **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Receive+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Receive%2BCrossPlatform.POSIX.swift)** (`2c63378 + 9a83433`), routing through `POSIX.Kernel.Socket.Receive.message`. Latent L2/L3 ambiguity tracked in `swift-kernel/HANDOFF-socket-family-l2-l3-ambiguity.md`. Windows gap tracked in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |
| 17 | HIGH | [PLAT-ARCH-008e] | [`swift-iso-9945/ISO 9945.Kernel.Socket.Connect.swift:39`](../../../swift-iso/swift-iso-9945/Sources/ISO%209945%20Kernel%20Socket/ISO%209945.Kernel.Socket.Connect.swift) (Storage), `:55` (IPv4), `:63` (IPv6), `:71` (Unix); L3 wrapper [`swift-posix/POSIX.Kernel.Socket.Connect.swift:54`](../../swift-posix/Sources/POSIX%20Kernel%20Socket/POSIX.Kernel.Socket.Connect.swift), `:68`, `:81`, `:94` | `Kernel.Socket.Connect.connect(_:, address:)` (four address overloads: `Storage+length`, `IPv4`, `IPv6`, `Unix`) inherits raw `connect(2)` from iso-9945. `POSIX.Kernel.Socket.Connect.connect(…)` applies a richer policy than retry: on EINTR it calls `Kernel.Socket.Connect.awaitCompletion(descriptor)` (poll POLLOUT + getsockopt SO_ERROR) because EINTR on connect means the handshake continues asynchronously, NOT "call again". Consumers silently get a raw connect that throws on EINTR without the completion-await. Fix: explicit delegation in swift-kernel; this is the highest-leverage fix of the 17 — the behavior difference is semantic, not just retry. | RESOLVED 2026-04-20 (6741b6a) — POSIX cross-platform delegate initially landed in swift-kernel (plus RFC-valued `RFC_791.IPv4.Address` / `RFC_4291.IPv6.Address` overloads at `2afb251`); **migrated 2026-04-20 to [`swift-sockets/Kernel.Socket.Connect+CrossPlatform.POSIX.swift`](../../swift-sockets/Sources/Sockets/Kernel.Socket.Connect%2BCrossPlatform.POSIX.swift)** (`2c63378 + 9a83433`). Four POSIX-typed overloads (Storage+length, IPv4, IPv6, Unix) plus two RFC-valued overloads now route through `POSIX.Kernel.Socket.Connect.connect` → `ISO_9945.Kernel.Socket.Connect.awaitCompletion` (poll POLLOUT + getsockopt SO_ERROR) on EINTR. Latent L2/L3 ambiguity on the four POSIX-typed overloads tracked in `swift-kernel/HANDOFF-socket-family-l2-l3-ambiguity.md`. Windows has no analogous [PLAT-ARCH-008e] violation: `Kernel.Socket.Connect` namespace and `Kernel.Socket.Address.{Storage,IPv4,IPv6,Unix}` are declared in iso-9945 (L2 POSIX spec), not L1 primitives — Windows consumers use `Windows.Kernel.Socket.connect(_:address:addressLength:)` directly via Winsock. Cross-platform Windows closure via RFC-valued surface tracked in `swift-sockets/HANDOFF-windows-socket-unifier-closure.md`. |

### Out-of-scope enumeration (for transparency)

The following L3 additions exist but are NOT violations of [PLAT-ARCH-008e]:

| Site | Why not a violation |
|------|---------------------|
| `POSIX.Kernel.IO.Read.readAll(_:, into:)` at [`swift-posix/POSIX.Kernel.IO.Read.swift:101`](../../swift-posix/Sources/POSIX%20Kernel%20File/POSIX.Kernel.IO.Read.swift) | Check 1 fails: iso-9945 has no `readAll` method. This is a novel L3 composed operation (partial-read loop + EINTR retry), not a shadow of L2 raw. Pure L3 value-add. |
| `POSIX.Kernel.Error.Code.posixMessage` ([`swift-posix/POSIX Core/`](../../swift-posix/Sources/POSIX%20Core/)) | Platform convenience (strerror wrapper); deferred-to-L2 per `swift-posix/Research/post-modularization-design-notes.md` §3. Not an L2-raw shadow pattern. |
| `Kernel.Glob.match(...)` at [`swift-posix/Kernel.Glob+Match.swift`](../../swift-posix/Sources/POSIX%20Kernel%20Glob/Kernel.Glob+Match.swift) | Direct extension on the L1 `Kernel.Glob` type, not under `POSIX.Kernel` namespace. iso-9945 has no matching implementation (Glob traversal is L3 policy per `swift-posix/Research/l3-policy-design.md` §"POSIX Kernel Glob"). Pure L3 implementation, not a shadow. |
| `Windows.Kernel.Glob.Match.match(...)` at [`swift-windows/Windows.Kernel.Glob.Match.swift`](../../swift-windows/Sources/Windows%20Kernel/Windows.Kernel.Glob.Match.swift) | Novel Windows-side L3 implementation parallel to POSIX Glob; no L2 `Windows.Kernel.Glob.Match` counterpart exists in windows-standard. Not a shadow. |
| `Darwin.Random.fill` / `Linux.Random.fill` / `Windows.Random.fill` | Novel L3 APIs. No `Kernel.Random.fill` inherited from L2 raw (each platform has its own random syscall family with no unified name). Rule does not apply. |
| `Linux.Thread.Affinity.apply` / `Windows.Thread.Affinity.apply` | Novel L3 APIs. No `Kernel.Thread.Affinity.apply` inherited from L2. Rule does not apply. |
| `System.Topology.NUMA.Discover.discover` (Darwin, Windows) | Novel L3 APIs. No L2 counterpart. Rule does not apply. |

### Summary

**17 findings: 0 critical, 17 high, 0 medium, 0 low. 15 resolved, 2 false positive, 0 open.**

**Resolution progress** (2026-04-20):
- Findings #1, #2 (Flush `flush`/`data`) — resolved at f541a08 (cross-platform `flush(_:)` delegate) + e9bafc5 (`data(_:)` owned by per-platform Darwin/Linux extensions). Row text updated 2026-04-26 per per-package audit.md hygiene sweep.
- Finding #17 (Connect) — resolved at 6741b6a.
- Findings #5, #6 (IO.Read) — resolved at 24cf586.
- Findings #7, #8, #9 (IO.Write) — resolved at 5b0ae3b.
- Finding #10 (Socket.Accept) — resolved at bfa092e.
- Findings #11, #12, #13 (Socket.Send) — resolved at 6a6d527.
- Findings #14, #15, #16 (Socket.Receive) — resolved at 5bd87f3.
- Findings #3, #4 (Flush `full`/`barrier`) — FALSE_POSITIVE (Phase A L2 rename eliminates the namespace-alias inheritance).

**Latent ambiguity caveat (reflected 2026-04-20, late session)**: post-landing verification revealed that the unifier delegates introduced by 24cf586 / 5b0ae3b / bfa092e / 6a6d527 / 5bd87f3 / 6741b6a create same-signature extension collisions with iso-9945's equivalent `ISO_9945.Kernel.*` declarations. The Read/Write collisions (#5–#9) surface immediately — `swift build --build-tests` fails with `ambiguous use of 'read(_:into:)'` / `'write(_:from:)'` in swift-kernel test support. The Socket collisions (#10–#17) are latent (no test calls them yet) but structurally identical. Fix dispatch: `HANDOFF-io-read-write-l2-l3-ambiguity.md` for Read/Write; Socket family tracked in that handoff's Addendum §4 as a separate follow-on. The RESOLVED status on Findings #5–#17 above refers to the unifier delegates landing; the ambiguity follow-up does not reopen them but will add a resolution-text amendment when the fix lands.

Every finding is on the POSIX side (retry / completion-await wrappers in swift-posix). Darwin, Linux, and Windows L3 packages currently contribute zero violations — their L3 additions are all novel APIs, not shadows of L2-raw methods inherited via namespace alias.

**Systemic pattern — the violation class is uniform**: the exact shape codified in [PLAT-ARCH-008e] is present ecosystem-wide for every POSIX syscall that can return EINTR (or, for connect, whose EINTR semantics require completion-await). The `while true { try Kernel.T.m(...); return } catch where error.code.isInterrupted { continue }` body is duplicated across 24 methods, and each one is shadowed by its L2-raw inheritance. The violation is not isolated; it is the default shape of the swift-posix → swift-kernel composition relationship as currently wired.

**Finding-#3 handoff scope (Flush family, Findings 1–4)**: `HANDOFF-kernel-file-flush-unifiers.md` is active and covers the Flush family's layering fix (Phase A renames L2 to spec-literal, Phase B extends swift-posix on Darwin with `data()` + `directory()`, Phase C adds explicit swift-kernel delegates for `flush` / `data` / `directory`). Findings 1 and 2 are covered by Phase C. Findings 3 and 4 (Darwin `full` / `barrier`) are FALSE_POSITIVE: Phase A's L2 rename eliminates the `Kernel.File.Flush.{full,barrier}` namespace-alias inheritance outright — after the rename, those names simply don't resolve on the unifier surface, so there is nothing left to shadow. `full` and `barrier` are Darwin-specific syscalls without cross-platform siblings; `POSIX.Kernel.File.Flush.{full,barrier}` is the intended terminal surface, and the absence of a cross-platform delegate is by design, not a gap.

**New violation scope (Findings 5–17, 13 open)**: IO.Read, IO.Write, Socket.Accept/Send/Receive/Connect. The structural fix mirrors Finding #3's three-phase shape (L2-name verification → swift-posix as single source → explicit file-level-guarded swift-kernel delegates per the `Kernel.File.Flush+CrossPlatform.POSIX.swift` pattern Phase C establishes). L2 names are already spec-literal for these (`read`, `pread`, `write`, `pwrite`, `accept`, `send`, `sendto`, `sendmsg`, `recv`, `recvfrom`, `recvmsg`, `connect`) — no Phase-A-style rename needed.

**Finding 17 (Connect) is qualitatively different from 5–16.** Findings 5–16 are retry-wrappers: on EINTR, the raw syscall is simply called again, so consumers on the raw path get *slower* behavior under signal interruption but not *wrong* behavior. Finding 17 Connect is a correctness fix: `connect(2)` EINTR means the handshake continues asynchronously — "call again" is wrong; the correct response is `poll(POLLOUT)` + `getsockopt(SO_ERROR)` to await completion and extract the final error. Consumers on the raw path get categorically wrong behavior under signal interruption, not just slow behavior. Connect warrants its own focused review separate from the routine retry-wrapper bundle.

**Remediation shape** (sequencing):

1. **Flush** — land `HANDOFF-kernel-file-flush-unifiers.md` first. Validates the three-phase pattern; resolves Findings 1, 2 (and confirms 3, 4 as FALSE_POSITIVE upon Phase A).
2. **Connect (#17)** — dispatch a focused handoff for `Kernel.Socket.Connect.connect` (all four address overloads). Single method, semantic correctness, awaitCompletion logic reviewed carefully.
3. **Bundled retry-wrappers (#5–#16)** — one handoff, five commits, each a concept-family. Upstream-only — no consumer migration in this handoff:
   - Commit 1: `Kernel.IO.Read.{read, pread}` cross-platform delegates (Findings 5, 6)
   - Commit 2: `Kernel.IO.Write.{write, pwrite, writeAll}` cross-platform delegates (Findings 7, 8, 9)
   - Commit 3: `Kernel.Socket.Accept.accept` cross-platform delegates (Finding 10)
   - Commit 4: `Kernel.Socket.Send.{send, to, message}` cross-platform delegates (Findings 11, 12, 13)
   - Commit 5: `Kernel.Socket.Receive.{receive, from, message}` cross-platform delegates (Findings 14, 15, 16)
   
   One review surface; granularity preserved per family; bisectable per concept.

   Windows side: most of these syscall concepts have direct `windows-standard` equivalents (`ReadFile`, `WriteFile`, `AcceptEx`, `WSASend`, `WSARecv`, `ConnectEx`); Windows has no EINTR, so `swift-windows` wrappers are trivial pass-throughs when they exist. Verify per-concept whether swift-windows hosts an L3 wrapper or whether swift-kernel's Windows file-guarded delegate can call windows-standard directly — matches the "skip the empty L3 tier" caveat in [PLAT-ARCH-008e].

4. **Terminal consumer migration** — a SEPARATE handoff, dispatched only after steps 1–3 land AND the sibling upstream fixes from `swift-file-system/Audits/audit.md` § Platform Compliance — 2026-04-20 (#1 `Kernel.Error.Code` predicates, #2 encoding unifiers, #3 Flush unifiers [= step 1 here], #4 path helpers, #5 Random, #6 hex) also land. Consumer migration crosses both audits — doing it once is the stated sequencing ("all upstreams first, then one consumer migration pass"). Batching a per-handoff sub-migration (e.g., "just the retry-wrapper call sites" as a Commit 6 here) would split consumer migration into two passes across audits; avoid. The terminal handoff sweeps consumer sites (swift-file-system, swift-io, and any other direct `POSIX.Kernel.*` / `ISO_9945.Kernel.*` hand-dispatch sites) in one pass, migrating each to the unified `Kernel.*` surface.

**Next agent dispatches proceed only after Finding #3 Phase C lands and validates the pattern.** The retry-wrapper bundle (#5–#16) reuses Phase C's file-naming and file-level-guard discipline verbatim; Connect's handoff (#17) reuses the same structure but with an additional awaitCompletion correctness review. Terminal consumer migration waits for both audits' upstreams.

**Rule-does-not-apply areas (confirmed clean)**: swift-darwin, swift-linux, swift-windows L3 packages. These host novel APIs only; extending the rule to them would require future L3 wrappers over their respective L2 raw (e.g., if `swift-linux` added an EINTR-retry wrapper for an epoll syscall). Monitor at next `/audit cluster platform` pass.
