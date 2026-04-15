# Audit: Kernel Event Target

**Date**: 2026-04-09
**Scope**: `Sources/Kernel Event/` (10 files)
**Skills**: code-surface, implementation, platform, ecosystem-data-structures
**Baseline**: Builds clean on macOS (Swift 6.3). All typed throws. ~Copyable ownership correct.

---

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 2     |
| MEDIUM   | 3     |
| LOW      | 6     |

---

## HIGH Findings

### H1. Unnecessary Two-Level Registry Dictionary

**Files**: `Kernel.Event.Driver+Kqueue.swift:36-44`, `Kernel.Event.Driver+Epoll.swift:40-47`
**Rules**: [IMPL-INTENT], [IMPL-002]

Each factory (`kqueue()`, `epoll()`) creates a fresh state object with a `Dictionary<Int32, Dictionary<Kernel.Event.ID, Entry>>`. The outer dictionary is keyed by the kqueue/epoll fd's raw `Int32`. Since each state instance serves exactly one Source, the outer dictionary always has exactly one entry.

**Impact**: Every registry access extracts `_rawValue` for the outer key (~10 sites per backend), then performs an outer lookup that always succeeds, before reaching the actual ID-keyed inner dictionary. This leaks mechanism into every closure body and adds pointless indirection.

**Current** (mechanism):
```swift
let kqFd = kq._rawValue                    // Extract raw value for outer key
state.registry.withLock { outer in
    guard var inner = outer.remove(kqFd)    // Always succeeds — one entry
    ...
    inner.set(id, entry)
    outer.set(kqFd, consume inner)          // Reinsert the one entry
}
```

**Fix**: Flatten to `Mutex<Dictionary<Kernel.Event.ID, Entry>>`:
```swift
state.registry.withLock { entries in
    entries.set(id, entry)
}
```

Eliminates all `_rawValue` extractions for the outer key, all `outer.remove(kqFd)` / `outer.set(kqFd, ...)` ceremony, and all `guard ... else { throw .invalidDescriptor }` checks on the outer key (which cannot fail by construction).

**Cascade**: Every closure in both factories (`_register`, `_modify`, `_deregister`, `_arm`, `_poll`, `_close`) simplifies.

---

### H2. Epoll Scratch Buffer Allocated But Unused

**File**: `Kernel.Event.Driver+Epoll.swift:198-201` (allocated), `:373` (not used), `:427` (deallocated)
**Rules**: [IMPL-INTENT]

The epoll factory allocates a `Memory.Buffer.Mutable` scratch buffer (256 * stride bytes) mirroring the kqueue pattern, but the `_poll` closure creates a local `Swift.Array<Kernel.Event.Poll.Event>` instead of using it. The scratch buffer is deallocated in `_close` but never read or written.

**Kqueue** (uses scratch buffer correctly):
```swift
let count = try unsafe scratchBuffer.withRebound(to: Kernel.Kqueue.Event.self) { ... }
```

**Epoll** (ignores scratch buffer, allocates array each poll):
```swift
var rawEvents = Swift.Array<Kernel.Event.Poll.Event>(
    repeating: ..., count: buffer.count
)
```

**Fix**: Either (a) use the scratch buffer in epoll's poll closure like kqueue does, or (b) remove the scratch buffer allocation from the epoll factory. Option (b) is simpler if `Kernel.Event.Poll.wait` requires `inout [...]`. Option (a) is better for performance if a raw-buffer overload exists.

---

## MEDIUM Findings

### M1. Driver Closure Properties Are `public` — Should Be `package`

**File**: `Kernel.Event.Driver.swift:23-52`
**Rules**: [API-IMPL-008], [MEM-SAFE-023] (by analogy — closures are not unsafe pointers, but the encapsulation principle applies)

The stored closure properties `_register`, `_modify`, `_deregister`, `_arm`, `_poll`, `_close` are `public let` with underscore prefixes. `Source` is the public facade and calls through these — no external consumer should call them directly.

The `_` prefix is a convention hint that the access level should enforce. Since `Source` and `Driver` are in the same target, `package` access suffices.

**Fix**: Change all six closure properties from `public let` to `package let`. The `init` can remain `public` for downstream driver creation.

---

### M2. File Names Misattribute Content

**Files**: `Kernel.Event.Driver+Kqueue.swift`, `Kernel.Event.Driver+Epoll.swift`
**Rules**: [API-IMPL-006], [API-IMPL-007]

File names suggest they extend `Kernel.Event.Driver`, but primary content is:
- Factory method on `Kernel.Event.Source` (`.kqueue()`, `.epoll()`)
- State class nested under `Kernel.Event.Source` (`KqueueState`, `Epoll.State`)
- Error conversion init on `Kernel.Event.Driver.Error`

**Fix**: Rename to `Kernel.Event.Source+Kqueue.swift` and `Kernel.Event.Source+Epoll.swift`. This correctly identifies the primary extension target. The error conversion inits are secondary content — acceptable in an extension file.

---

### M3. `Triggering` Enum Nested in `Capabilities` Body

**File**: `Kernel.Event.Driver.Capabilities.swift:26-33`
**Rules**: [API-IMPL-005], [API-IMPL-008]

`Capabilities` body contains nested enum `Triggering` — two type declarations in one file.

**Fix**: Extract to `Kernel.Event.Driver.Capabilities.Triggering.swift`:
```swift
extension Kernel.Event.Driver.Capabilities {
    public enum Triggering: Sendable {
        case edge
        case level
    }
}
```

---

## LOW Findings

### L1. `KqueueState` Compound Name — Inconsistent With Epoll

**File**: `Kernel.Event.Driver+Kqueue.swift:36`
**Rules**: [API-NAME-001]

Epoll uses properly nested `Epoll.State`. Kqueue uses compound `KqueueState`. Both are internal scope (permitted per feedback `feedback_compound_package_scope`), but the inconsistency is unnecessary.

**Fix**: Add namespace enum and rename:
```swift
extension Kernel.Event.Source { enum Kqueue {} }
extension Kernel.Event.Source.Kqueue { final class State { ... } }
```

---

### L2. `Backend.platformDefault()` Compound Identifier

**File**: `Kernel.Event.Source.Backend.swift:19`
**Rules**: [API-NAME-002]

`platformDefault()` is a compound method name on a public API.

**Possible fix**: Rename to `Backend.default()` — but `default` is a keyword. Alternatives: `Backend.current()`, `Backend.auto()`. Or restructure: `Source.backend.default()` via Property accessor. Discuss before acting — the current name is clear even if compound.

---

### L3. Kqueue Wakeup Closure Uses Untyped `do { } catch { }`

**File**: `Kernel.Event.Driver+Kqueue.swift:110-119`
**Rules**: [IMPL-075], [PATTERN-009]

```swift
do {
    try Kernel.Kqueue.register(rawDescriptor: wakeupKq, events: [triggerEv])
} catch {
    if case .kevent(let code) = error as? Kernel.Kqueue.Error,  // ← error is `any Error`
```

**Fix**: Use `do throws(Kernel.Kqueue.Error)` and access `error` directly:
```swift
do throws(Kernel.Kqueue.Error) {
    try Kernel.Kqueue.register(rawDescriptor: wakeupKq, events: [triggerEv])
} catch where error.isKevent && (error.code == .POSIX.EBADF || ...) {
    // Benign
}
```

Or, if the register call throws an untyped error because it's the `rawDescriptor:` SPI overload, this may be a genuine limitation. Verify the SPI signature.

---

### L4. `nonisolated(unsafe) var eventfd` Missing Safety Comment

**File**: `Kernel.Event.Driver+Epoll.swift:52`
**Rules**: [MEM-SAFE-024] (spirit of)

The property is write-once-then-nil — set in `init`, nil'd in `_close`. No concurrent access. A `// SAFETY:` comment should document this invariant.

---

### L5. `Capabilities.maximum: Int` — Raw Int Quantity

**File**: `Kernel.Event.Driver.Capabilities.swift:12`
**Rules**: [IMPL-006]

Stores a quantity (max events per poll) as raw `Int`. Could use a typed count, but the type is simple configuration metadata. Very low priority.

---

### L6. Multiple Type Declarations in Backend Files

**Files**: `Kernel.Event.Driver+Kqueue.swift` (1 type: `KqueueState`), `Kernel.Event.Driver+Epoll.swift` (2 types: `Epoll`, `Epoll.State`)
**Rules**: [API-IMPL-005]

Platform-conditional files contain type declarations alongside extensions. Splitting each type into its own `#if os(...)`-guarded file is possible but adds file proliferation for internal types. Acceptable deviation per [PATTERN-016] — platform conditional boundaries motivate colocation.

---

## Positive Observations

- **Typed throws throughout** — every throwing function uses `throws(Kernel.Event.Driver.Error)`. [API-ERR-001] fully compliant.
- **Error type correctly nested** — `Kernel.Event.Driver.Error` uses `Swift.Error` qualification per [PLAT-ARCH-011]. Cases describe failure, not recovery. [API-ERR-002], [API-ERR-003] compliant.
- **~Copyable ownership correct** — `Entry: ~Copyable` for descriptor ownership, `Source: ~Copyable` for resource lifecycle, `Driver` correctly Copyable (witness of closures). `consuming` annotations on descriptor parameters. [IMPL-064], [IMPL-067] compliant.
- **Platform conditionals correct** — `#if os(...)` for platform identity (not `canImport`), conditionals confined to L3 files. [PATTERN-004a], [PLAT-ARCH-008] compliant.
- **No platform C types in public API** — all public surfaces use ecosystem types. [PLAT-ARCH-005a] compliant.
- **Sendable minimalism** — Driver and Source deliberately non-Sendable. [IMPL-068] compliant.
- **Dictionary_Primitives** correctly used for `~Copyable` Entry values. [DS-003], [IMPL-060] compliant.
- **Package.swift** — target published as product, ecosystem swift settings applied (`.strictMemorySafety()`, Swift 6, experimental features). [MEM-SAFE-001], [PATTERN-005], [PATTERN-002] compliant.

---

## Recommended Fix Order

1. **H1** — Flatten registry to single-level dictionary (biggest impact, touches all closures)
2. **H2** — Remove unused epoll scratch buffer (dead code removal, trivial)
3. **M1** — Narrow closure properties to `package` (one-line changes)
4. **M2** — Rename files (zero code change)
5. **M3** — Extract `Triggering` to own file (mechanical)
6. **L1–L6** — Address in any order; L3 (typed catch) most impactful of the lows
