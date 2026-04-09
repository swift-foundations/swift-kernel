# Handoff: Refactor Kernel Completion to Match Kernel Event Pattern

> To resume: read this file, then read the Kernel Event files as the reference
> implementation. Load /implementation and /code-surface. Ask if anything is unclear.

## Goal

Bring `Kernel.Completion` (proactor witness) to the same quality bar as the
just-completed `Kernel.Event` (reactor witness). Apply the same patterns:
`~Copyable` Driver, zero-allocation hot path, zero `@_spi(Syscall)` in L3,
normative doc comments, three-boundary model, ownership-first L1 types.

Then: design the IOCP backend stub for Windows (future).

## Reference Implementation

The Kernel Event target is the template. Read these files first:

| File | Pattern to follow |
|------|-------------------|
| `Sources/Kernel Event/Kernel.Event.Driver.swift` | `~Copyable` witness, init in type body, normative doc comments |
| `Sources/Kernel Event/Kernel.Event.Source+Kqueue.swift` | State class holds L1 struct, instance methods, zero SPI, `kevents()` helper |
| `Sources/Kernel Event/Kernel.Event.Source.swift` | `~Copyable` resource, `consuming` init, `platform()` factory |

## Current State

- **17 files** in `Sources/Kernel Completion/`
- **Witness pattern**: Already correct (struct of closures wrapping io_uring backend)
- **Resource**: `Kernel.Completion` is `~Copyable`, not Sendable — correct
- **Driver**: `Kernel.Completion.Driver` is **Copyable** — should be `~Copyable`
- **Backend**: `Kernel.Completion+IOUring.swift` (~400 LOC) works but has issues below
- **L1 io_uring**: Already a `~Copyable` struct (`Kernel.IO.Uring`) — no enum→struct needed
- **Research**: `Research/unified-completion-api-design.md` (IN_PROGRESS) specifies planned changes

## What Needs to Change

### 1. Make Driver `~Copyable`

Same as Event: enforce single-ownership at the type level.

```swift
// Before
public struct Driver { ... }

// After
public struct Driver: ~Copyable { ... }
```

Cascade: `Completion.init` takes `consuming Driver`. Closures still capture
shared state via reference (Ring class).

### 2. Move Driver.init into Type Body

Per [API-IMPL-008]. Init contains all closure construction. Doc comments are
normative (written first, not post-hoc).

### 3. Descriptor Encapsulation

Currently `Completion` exposes `descriptor` via `@_spi(Internal)`:
```swift
@_spi(Internal) public let descriptor: Kernel.Descriptor
```

The descriptor is passed to every Driver closure. After refactoring, the Driver
closures should capture the descriptor via the State class (like Event does).
Remove the `descriptor` stored property from `Completion` — the Driver closures
own all kernel interaction.

**Exception**: `notification: Int32` (the eventfd raw fd for epoll integration)
must remain accessible to the IO.Event.Loop. Consider a public property or a
dedicated accessor.

### 4. Harvest → Callback Drain

The research doc specifies changing from array-based harvest to callback drain:

```swift
// Before
func harvest(deadline: Kernel.Time.Deadline?, into events: inout [Event]) throws(Error) -> Int

// After
func drain(_ visitor: (Event) -> Void) throws(Error) -> Int
```

**Rationale**: The CQ ring is shared memory. The L1 `drainCompletions(visitor:)`
already uses callbacks. An intermediate array is unnecessary allocation.

**Deadline removal**: epoll handles blocking (Linux); IOCP IS the loop (Windows).
The Completion driver doesn't block — it drains what's available.

### 5. Rename `_drain` → `_close`

Current witness has `_drain` for cleanup. Rename to `_close` to match Event's
pattern and avoid confusion with the new callback `drain` operation.

### 6. Zero `@_spi(Syscall)` in L3

Same approach as Event:
- State class holds L1 `Kernel.IO.Uring` struct (already `~Copyable`)
- Instance methods replace static calls where possible
- Wakeup encapsulation: add a method to the L1 io_uring that creates the
  eventfd and returns a `Kernel.Wakeup.Channel` + the raw notification fd
- `Kernel.Completion.Token` boundary crossing uses `.map { }.retag()` instead
  of rawValue extraction

### 7. Normative Doc Comments

Same three-boundary model adapted for proactor:
1. **Backend**: raw CQE → `Kernel.Completion.Event` (translation only)
2. **Driver**: token validation / staleness (if applicable)
3. **Caller**: consumes valid completion events

Doc comments on Driver, each closure property, and the public API methods.

### 8. `@safe` on L1 io_uring Struct

Same as kqueue/epoll — the `~Copyable` struct presents a safe API over unsafe
mmap'd memory internals.

## What Does NOT Change

- **Submission/Event value types**: Already well-structured (Opcode, Token, Flags, etc.)
- **Error type**: Already nested, typed throws, descriptive cases
- **File structure**: Already one type per file, correct naming
- **L1 io_uring structure**: Already `~Copyable` struct — no enum→struct needed
- **Proactor vs reactor distinction**: Different operations are correct (submit/flush/drain vs register/modify/arm/poll)

## Architecture Symmetry

| Aspect | Kernel.Event (done) | Kernel.Completion (TODO) |
|--------|--------------------|-----------------------|
| Resource | `Source: ~Copyable` | `Completion: ~Copyable` ✓ already |
| Driver | `Driver: ~Copyable` | `Driver` → make `~Copyable` |
| Batch I/O | `poll(deadline:into:)` | `harvest(deadline:into:)` → `drain(visitor:)` |
| Cleanup | `close()` | `_drain` → rename to `_close` |
| State | Local class in factory | `IOUring.Ring` class → verify same pattern |
| L1 type | `Kernel.Kqueue` / `Kernel.Event.Poll` struct | `Kernel.IO.Uring` struct ✓ already |
| Wakeup | `kq.wakeup()` / `epoll.wakeup(eventfd:)` | Add wakeup method to L1 |
| SPI in L3 | Zero | Currently uses SPI → eliminate |

## L1 io_uring: What Needs Adding

The L1 `Kernel.IO.Uring` is already a `~Copyable` struct. Unlike kqueue/epoll,
it does NOT need restructuring from enum to struct. But it needs:

1. **Wakeup method**: Encapsulate eventfd creation + registration + raw fd capture
2. **`@safe` annotation**: Safe API boundary marker
3. **Instance methods** where missing: Verify statics vs instance method split

Location: `/Users/coen/Developer/swift-primitives/swift-linux-primitives/Sources/Linux Kernel IO Uring Primitives/`

## IOCP (Windows) — Future

Windows uses I/O Completion Ports (IOCP). This is a separate backend for
`Kernel.Completion.Driver`, following the same witness pattern:

```swift
extension Kernel.Completion {
    public static func iocp() throws(Error) -> Kernel.Completion { ... }
}
```

**Key differences from io_uring**:
- IOCP IS the event loop (no separate epoll + eventfd bridge)
- Operations are submitted directly to the OS (no SQ ring)
- Completions are dequeued from the IOCP port (GetQueuedCompletionStatus)
- Buffer management is OS-assisted

**Scope**: Stub the factory method. Full implementation requires Windows platform
primitives which don't exist yet.

## Audit Checklist

After implementation, run the same 4-skill audit:

```
/audit against /implementation
/audit against /code-surface
/audit against /platform
/audit against /memory-safety
```

Expected: same quality bar as Kernel Event (zero violations, zero SPI in L3).

## Files to Change

### L3 (swift-kernel/Sources/Kernel Completion/)

| File | Change |
|------|--------|
| `Kernel.Completion.Driver.swift` | `~Copyable`, init in body, doc comments |
| `Kernel.Completion.swift` | Remove `descriptor` property, `consuming` Driver init |
| `Kernel.Completion+IOUring.swift` | State class holds L1 struct, zero SPI, callback drain |
| `exports.swift` | Review imports |

### L1 (swift-linux-primitives/)

| File | Change |
|------|--------|
| `Linux.Kernel.IO.Uring.swift` | Add `@safe`, verify instance methods, add wakeup |

### Research

| File | Change |
|------|--------|
| `Research/unified-completion-api-design.md` | Update status after implementation |

## Constraints

- Swift 6.3: `~Copyable` deferred init inside `do throws(E) {}` triggers compiler bug
- `Kernel.IO.Uring` is already `~Copyable, Sendable` — no restructure needed
- `Kernel.Completion.Token` is `Tagged<Kernel.Completion, UInt64>` — use `.map { }.retag()` at boundaries
- Thread-confined after `sending` transfer — no Mutex/Atomic needed
- The callback drain must work with `~Copyable` Event values if Event ever becomes `~Copyable`
- Linux-only for now (IOCP is future work)
- Build verification: macOS (cross-compilation check) + Linux Docker Swift 6.3
