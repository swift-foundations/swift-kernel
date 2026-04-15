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
