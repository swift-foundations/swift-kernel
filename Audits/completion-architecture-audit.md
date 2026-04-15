# Kernel.Completion Architecture Audit: L1 Vocabulary Purity

> Tier 2 — Cross-package architectural analysis.
> Depends on: unified-completion-api-design.md, kernel-completion-driver-redesign.md

## Executive Summary

L1 `Kernel Completion Primitives` (17 files, ~699 LOC) is **dead code**. Zero importers.
L3 `Kernel Completion` (21 files, ~1,170 LOC) is the sole live definition of all
completion types. The L1 target is a vestigial snapshot from before the L3 redesign.

Applying [PLAT-ARCH-012] to every L3 type: **7 of 21 types are genuine cross-platform
vocabulary** (Token, Event, Event.Result, Event.Flags, Event.Count, Error, namespace).
The remaining 14 are composition — resource lifecycle, driver witness, submission
descriptors, notification, capabilities — all correctly at L3.

**Recommendation**: Delete vestigial L1. Extract the 7 vocabulary types to a new L1
`Kernel Completion Primitives` target (~150 LOC, 7 files). This mirrors the clean
L1 Event Primitives pattern (4 types, 5 files, 307 LOC).

---

## Finding 1: L1 Completion Primitives Is Dead Code

### Evidence

```
Kernel_Completion_Primitives:
  - Package.swift reference:  swift-primitives/Package.swift:337 (product declaration)
  - Swift file imports:       0 (grep across entire workspace)
  - L3 dependency:            None (L3 exports only Kernel_Core)
  - L3 type redefinition:     ALL 16 types redefined at L3
```

L3 `Kernel Completion` defines `extension Kernel { public struct Completion: ~Copyable { } }`
independently. No re-export, no import. L1 and L3 definitions are incompatible:

| Aspect | L1 (vestigial) | L3 (live) |
|--------|----------------|-----------|
| `Completion` struct | Stores `descriptor`, `driver` (Copyable) | Stores `driver` (~Copyable), `notification`, `capabilities` |
| `Driver` | Copyable, takes `borrowing Descriptor` | `~Copyable`, closures capture State, no fd parameter |
| `Event.flags` | `Options` (opaque shell) | `Flags` (semantic: `.more` for multishot) |
| `Event.Result` | `@_spi(Syscall)` init | `package` init |
| Harvest/drain | `harvest(deadline:into:)` | `drain(_ visitor:)` |
| Notification | Absent | `Notification?` (~Copyable struct) |
| Capabilities | `Driver.Capabilities` (has `ringSize`) | `Completion.Capabilities` (no `ringSize`) |

The L3 types represent the post-redesign state per `kernel-completion-driver-redesign.md`
(status: CONVERGED). The L1 types are pre-redesign artifacts.

### Cause

The redesign (kernel-completion-driver-redesign.md) was implemented entirely at L3.
L1 was not updated or deleted. The unified-completion-api-design.md originally placed
the resource + driver at L1, but the implementation naturally evolved everything to L3
because:

1. `Driver` became `~Copyable` — a composition decision, not vocabulary
2. `Notification` was added — platform-specific (eventfd on Linux, absent on IOCP)
3. `Capabilities` lost `ringSize` — recognized as internal backend detail
4. `Submission.Flags` are all io_uring-shaped
5. Descriptor was absorbed into State class — composition mechanism

Each change moved further from vocabulary toward composition. The L1 target was
correctly bypassed.

---

## Finding 2: Type-by-Type [PLAT-ARCH-012] Assessment

**Test applied**: "Would this type exist if only IOCP existed and io_uring didn't?"

This is the most discriminating test because io_uring and IOCP are structurally
different proactor implementations:

- io_uring: shared-memory ring, batch SQE submission, non-blocking CQ drain
- IOCP: API-based, immediate Win32 syscall per operation, blocking dequeue

### Genuine Vocabulary (L1 candidates)

| Type | IOCP equivalent | Verdict |
|------|----------------|---------|
| `Kernel.Completion` (namespace) | Yes — completion I/O is a universal concept | **L1 namespace** |
| `Kernel.Completion.Token` | `Kernel.IO.Completion.Port.Key` (ULONG_PTR) | **L1 vocabulary** |
| `Kernel.Completion.Event` | `Kernel.IO.Completion.Port.Entry` (dequeued result) | **L1 vocabulary** |
| `Kernel.Completion.Event.Result` | `Entry.Bytes.transferred` + status | **L1 vocabulary** |
| `Kernel.Completion.Event.Flags` | Completion status flags (universal concept) | **L1 vocabulary (shell)** |
| `Kernel.Completion.Event.Count` | Count of dequeued completions | **L1 vocabulary** |
| `Kernel.Completion.Error` | Kernel boundary error domain | **L1 vocabulary** |

**7 types pass**. Completion events, correlation tokens, and error domains exist in
every completion-based I/O system. These are "our concepts, our naming" per
[PLAT-ARCH-012].

### Composition (L3, correctly placed)

| Type | Why L3 | IOCP analysis |
|------|--------|---------------|
| `Completion` (resource struct) | ~Copyable lifecycle with submit/flush/drain/close | IOCP port has different lifecycle (CreateIoCompletionPort) |
| `Driver` (~Copyable witness) | Closure-based composition mechanism | IOCP needs different closure signatures |
| `Notification` | Platform-specific: eventfd on Linux, absent on IOCP | IOCP IS the notification — `Notification?` is nil |
| `Capabilities` | `multishot`/`providedBuffers` are io_uring features | IOCP: both false. Valid as feature flags but L3-shaped. |
| `Submission` | Flat operation descriptor | IOCP has no submission ring — uses direct Win32 calls |
| `Submission.Opcode` | 10-operation enum | IOCP maps opcode → Win32 function, not opcode → SQE field |
| `Submission.Address` | Buffer pointer wrapped as UInt64 | OVERLAPPED has LPVOID but in different context |
| `Submission.Length` | UInt32 "structurally determined by io_uring SQE layout" | Comments self-identify as io_uring-shaped |
| `Submission.Offset` | UInt64 "structurally determined by io_uring SQE layout" | Comments self-identify as io_uring-shaped |
| `Submission.Flags` | bufferSelect/linked/drain/fixedFile = IOSQE_* flags | All io_uring-specific. No IOCP equivalent. |
| `Submission.Count` | Tagged cardinal for submission batch size | IOCP has no submission count (immediate syscalls) |
| `Buffer` | Namespace for kernel-managed buffer pools | IOCP has no kernel-managed buffer pools |
| `Buffer.Group` | Buffer group identifier | No IOCP equivalent |
| `+IOUring.swift` | io_uring backend | Platform-specific L3 composition |

**14 types are composition**. The Submission tree is the clearest signal: its field widths
are io_uring SQE-shaped, its flags are IOSQE_* flags, and the submit-then-flush model
is ring-shaped. IOCP submits via direct Win32 calls with OVERLAPPED — no submission ring.

The Submission abstraction is valid L3 composition that unifies:
- io_uring: fill SQE fields → submit batch
- IOCP: map opcode → ReadFile/WSASend/AcceptEx call (immediate)

This is the same kind of cross-platform unification that `Kernel.Event.Source` does for
kqueue/epoll. But it's composition, not vocabulary.

---

## Finding 3: LOC Comparison Validates the Split

| Package | Current | After extraction |
|---------|---------|-----------------|
| **L1 Completion Primitives** | 699 LOC, 17 files (dead) | ~150 LOC, 7 files (vocabulary) |
| **L3 Kernel Completion** | 1,170 LOC, 21 files | ~1,020 LOC, 14 files (composition) |

Compare to the clean reference pattern:

| L1 package | Types | Files | LOC | LOC/type |
|------------|-------|-------|-----|----------|
| Event Primitives | 4 | 5 | 307 | ~77 |
| Completion Primitives (proposed) | 7 | 7 | ~150 | ~21 |

Completion's lower LOC/type is expected: most vocabulary types are one-line typealiases
(`Token = Tagged<...>`) or small structs (`Event.Result` with a rawValue and one
computed property). Event Primitives has denser types with OptionSet constants and
CustomStringConvertible conformances.

---

## Finding 4: IOCP Integration Path

The existing research (kernel-completion-driver-redesign.md Q6) validates that the
current L3 witness shape is IOCP-compatible:

| Driver operation | io_uring implementation | IOCP implementation |
|-----------------|------------------------|---------------------|
| `_submit` | Fill SQE in shared memory | Call ReadFile/WSASend/AcceptEx with OVERLAPPED |
| `_flush` | `io_uring_enter()` → returns count | Returns `.zero` (immediate submission) |
| `_drain` | Non-blocking CQ ring read | GetQueuedCompletionStatusEx with timeout=0 |
| `_close` | Teardown state (deinit unmaps ring) | CloseHandle(port) |

### IOCP-Specific Considerations

**Drain semantics**: The current drain is non-blocking (drain-after-notification).
For IOCP, this means `GetQueuedCompletionStatusEx(timeout: 0)`. The event loop on
Windows would need a different structure:

- Linux: epoll_wait (blocks) → eventfd fires → drain (non-blocking CQ read)
- Windows: IOCP IS the event loop primitive — drain blocks in GQCS with timeout

This means the Windows event loop may bypass the drain-after-notification model
entirely, using `drain(timeout: N)` as its primary blocking wait. The current
witness signature `((Event) -> Void) -> Event.Count` would need to be augmented
for IOCP:

**Option A**: Add optional timeout parameter to drain
```swift
package let _drain: (Kernel.Time.Deadline?, (Kernel.Completion.Event) -> Void) -> Event.Count
```

**Option B**: Windows event loop uses IOCP drain as its main blocking primitive,
no separate readiness selector
```swift
// Windows: no epoll, IOCP IS the event loop
while !shouldHalt {
    drainJobs()
    completion.drain(timeout: deadline) { event in
        dispatch(event)
    }
}
```

**Option C**: Windows event loop uses WaitForMultipleObjects + GQCS combination

**Recommendation**: Defer this decision until Windows event loop architecture is
designed. The witness shape is extensible — adding a timeout parameter is additive,
not breaking. The current non-blocking drain is correct for Linux.

### L2 IOCP Vocabulary Available

`swift-windows-standard` provides 15 files of typed IOCP wrappers:

| L2 type | Maps to L3 concept |
|---------|-------------------|
| `Port.Key` (ULONG_PTR) | `Completion.Token` |
| `Port.Entry` (OVERLAPPED_ENTRY) | `Completion.Event` |
| `Port.Entry.Bytes.transferred` | `Event.Result.value` |
| `Port.Dequeue.batch` | `drain()` implementation |
| `Port.Overlapped` | Submission address/offset context |
| `Port.Read`/`Port.Write` | submit() with .read/.write opcode |
| `Port.Cancel.All` | submit() with .cancel opcode |
| `Port.Error` | `Completion.Error` conversion |

The L2 vocabulary is complete enough to build an IOCP backend. The gap is purely
at L3 — `Kernel.Completion+IOCP.swift` does not exist yet.

---

## Proposed Action

### Phase 1: Delete Vestigial L1

Remove the dead `Kernel Completion Primitives` target from `swift-kernel-primitives`.
Delete all 17 source files. Remove the Package.swift product/target/dependency entries.

**Risk**: Zero. No consumers exist.

### Phase 2: Extract Vocabulary to New L1

Create a clean `Kernel Completion Primitives` target containing only vocabulary types.
Mirror the L1 Event Primitives pattern.

**Files to create** (extracted from current L3):

| File | Type | Source (L3) |
|------|------|-------------|
| `Kernel.Completion.swift` | `public enum Completion {}` (namespace only) | New — L3's is a struct |
| `Kernel.Completion.Token.swift` | `Tagged<Kernel.Completion, UInt64>` | Identical to L3 |
| `Kernel.Completion.Event.swift` | Struct: token + result + flags | Identical to L3 |
| `Kernel.Completion.Event.Result.swift` | Wrapped Int32 | From L3, change `package` → `@_spi(Syscall)` per L1 convention |
| `Kernel.Completion.Event.Flags.swift` | OptionSet shell (`.more` stays) | From L3 |
| `Kernel.Completion.Event.Count.swift` | `Tagged<Event, Cardinal>` | From L3 |
| `Kernel.Completion.Error.swift` | Error enum | Identical to L3 |

**L3 changes**: Remove the 7 extracted type definitions. Import `Kernel_Completion_Primitives`.
L3's `Kernel.Completion` struct now extends the L1 namespace enum (same pattern as
L3 Event extending L1 Event namespace).

### Phase 3: IOCP Backend (Future)

Create `Kernel.Completion+IOCP.swift` in swift-kernel. Stub factory with
`#if os(Windows)` guard. Full implementation when Windows event loop is designed.

### Ordering

Phase 1 is independent and can ship immediately. Phase 2 requires coordinating
swift-primitives and swift-foundations changes. Phase 3 is deferred.

---

## Comparison: Event vs Completion Architecture (Post-Extraction)

| Aspect | L1 Event Primitives | L1 Completion Primitives (proposed) |
|--------|--------------------|------------------------------------|
| Namespace | `Kernel.Event` | `Kernel.Completion` |
| Correlation | `Event.ID` (Tagged<Event, UInt>) | `Completion.Token` (Tagged<Completion, UInt64>) |
| Result type | `Event.Interest` (OptionSet) | `Event.Result` (wrapped Int32) |
| Flags | `Event.Options` (OptionSet) | `Event.Flags` (OptionSet) |
| Count | — | `Event.Count` (Tagged<Event, Cardinal>) |
| Error | — (at L3) | `Completion.Error` (enum) |
| LOC | ~307 | ~150 |
| Files | 5 | 7 |

The asymmetry is justified:
- Completion needs Token (reactor uses Event.ID which doubles as fd number)
- Completion needs Result (reactor only needs Interest — readiness is boolean)
- Completion needs Error at L1 (reactor errors are L3 because kqueue/epoll differ)
- Completion needs Count (reactor's event count is tracked differently)

---

## References

- `swift-kernel/Research/unified-completion-api-design.md` — original L1/L3 design
- `swift-kernel/Research/kernel-completion-driver-redesign.md` — converged Driver design
- `swift-primitives/swift-kernel-primitives/Sources/Kernel Event Primitives/` — clean L1 reference
- `swift-microsoft/swift-windows-standard/Sources/Windows Kernel IO Standard/` — L2 IOCP vocabulary
- `HANDOFF.md` — investigation scope and questions
