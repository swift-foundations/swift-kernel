# Investigation: Kernel.Socket.{Connect,Accept,Send,Receive} L2/L3 ambiguity — latent twin of the Read/Write collision

> To investigate: read this file for full context. Load `/platform` first
> (see `[PLAT-ARCH-008e]`, `[PLAT-ARCH-008d]`). Companion handoff at
> `/Users/coen/Developer/swift-foundations/swift-sockets/HANDOFF-windows-socket-unifier-closure.md`
> is a sibling but strictly out of scope here — it covers Windows surface
> closure, this one covers the POSIX-side overload-resolution collision.

## Issue

`Kernel.Socket.{Connect,Accept,Send,Receive}.*` currently resolve through
two overlapping extension layers whose signatures are structurally
identical:

- **L2** — `swift-iso-9945/Sources/ISO 9945 Kernel Socket/*.swift` declares
  `extension ISO_9945.Kernel.Socket.{Connect,Accept,Send,Receive}`. Because
  `ISO_9945.Kernel` is a typealias of `Kernel_Primitives.Kernel`, these
  extensions land on the shared `Kernel.Socket.{Connect,Accept,Send,Receive}`
  namespace declared at L1. Methods throw without EINTR retry / completion-
  await.
- **L3 domain** — `swift-sockets/Sources/Sockets/Kernel.Socket.*+CrossPlatform.POSIX.swift`
  declares `extension Kernel.Socket.{Connect,Accept,Send,Receive}` with the
  same method shapes, delegating through `POSIX.Kernel.Socket.*` (swift-posix)
  for EINTR retry / completion-await. Recently migrated out of swift-kernel
  (commits `2c63378` remove + `9a83433` add — see reflection
  `swift-institute/Research/Reflections/2026-04-20-socket-unifier-rfc-composition-and-swift-sockets-migration.md`).

The swift-sockets L3 file extends `Kernel.Socket.Connect.connect(…)` (etc.)
with identical signatures to iso-9945's `extension ISO_9945.Kernel.Socket.Connect`,
which via typealias lands on the same `Kernel.Socket.Connect` namespace.
Swift's name lookup cannot disambiguate.

**Latent, not breaking** — the collision exists today but `swift build`
does not surface it because:

1. `swift-sockets` itself fails earlier on unrelated Phase-2 IO-refactor
   debt (`Sockets.Error.swift` imports a removed `IO_Core` target and
   references a removed `IO.Error` type — see the sibling Windows-closure
   handoff for details). The unifier files never get to type-check past
   that pre-existing breakage.
2. No consumer outside swift-sockets' own sources currently calls
   `Kernel.Socket.Connect.connect(…)` / `Accept.accept(…)` / `Send.send(…)` /
   `Receive.receive(…)` through the Kernel namespace. Grep of swift-kernel,
   swift-io, swift-file-system returns only README and doc-comment
   references at `swift-io/Sources/IO Events/README.md:34,444` and
   `swift-io/Tests/Support/Basic.Capabilities.swift:50`. None of those are
   live call sites.

The moment the Phase-2 swift-sockets refactor lands and any consumer
invokes a Socket unifier method, the ambiguity will surface as the exact
compile error already seen (and resolved) on IO.Read/Write:

```
ambiguous use of 'accept(_:)' — candidates in
  'ISO_9945_Kernel_Socket' and 'Sockets'
```

This handoff is the preventative follow-on to the Read/Write ambiguity
resolution already landed:

- Read/Write ambiguity fix — swift-iso-9945 `9aa06e6` (adds
  `@_disfavoredOverload` to 10 L2 Read/Write declarations).
- Read/Write handoff Addendum §4 — documented the latent socket twin and
  deferred it to a separate handoff. This IS that handoff.

## Parent Context

### Architectural sequence (how we got here)

1. **2026-04-20 morning**: L3 Composition audit (`swift-kernel/Audits/audit.md`
   §L3 Composition) enumerated 17 POSIX retry-wrapper shadows of iso-9945
   methods that should delegate explicitly per `[PLAT-ARCH-008e]`. Findings
   #5–9 are Read/Write; Findings #10–17 are Socket family.
2. **2026-04-20 late morning**: Socket unifiers land in swift-kernel —
   `bfa092e` (Accept), `6a6d527` (Send), `5bd87f3` (Receive), `6741b6a`
   (Connect). Each adds `extension Kernel.Socket.X { public static func
   y(…) { POSIX.Kernel.Socket.X.y(…) } }` in
   `swift-kernel/Sources/Kernel Core/Kernel.Socket.*+CrossPlatform.POSIX.swift`.
   These collided with iso-9945's `extension ISO_9945.Kernel.Socket.X` via
   typealias from the moment they landed, but tests did not exercise them.
3. **2026-04-20 midday**: `2afb251` adds RFC-valued Connect overloads
   (`RFC_791.IPv4.Address`, `RFC_4291.IPv6.Address`) in swift-kernel,
   inheriting the same ambiguity shape (though RFC types don't collide
   with iso-9945 — only the POSIX-typed overloads do).
4. **2026-04-20 afternoon**: Read/Write ambiguity surfaces in
   `Kernel_Test_Support`; investigated in
   `HANDOFF-io-read-write-l2-l3-ambiguity.md`. Resolution landed as
   `9aa06e6` (swift-iso-9945 `@_disfavoredOverload` on 10 Read/Write L2
   methods). Addendum §4 flags the Socket family twin.
5. **2026-04-20 late afternoon**: Architectural reconsideration (per the
   reflection) moves the Socket unifier files out of swift-kernel into
   swift-sockets — `2c63378` (remove from swift-kernel) + `9a83433` (add to
   swift-sockets) + RFC dep migration. Audit.md `[PLAT-ARCH-008e]` Findings
   #10–#17 row paths are now stale (they reference
   `swift-kernel/Kernel.Socket.*+CrossPlatform.POSIX.swift` files that
   have been deleted); the unifiers live at
   `swift-sockets/Sources/Sockets/Kernel.Socket.*+CrossPlatform.POSIX.swift`.
   The ambiguity pattern persists — only the path changed.

### Reflection insights that frame this handoff

`swift-institute/Research/Reflections/2026-04-20-socket-unifier-rfc-composition-and-swift-sockets-migration.md`
establishes three patterns load-bearing on the proposed fix:

- **Pattern 1 — prior art reverses first-principles designs**. Rust
  PR #78802 empirically rejected C-sockaddr-layout compatibility for IP
  value types with measured evidence that marshalling cost is negligible
  versus syscall cost. The decision to keep RFC types host-order and
  compose at the API boundary (research:
  `swift-institute/Research/ip-address-value-type-memory-layout.md`
  commit `b0a8f5d`) is why the L3 unifier converts RFC types to iso-9945
  sockaddr wrappers at the unifier seam. Relevant here because the fix
  must not perturb that seam.
- **Pattern 2 — domain-specific cross-platform unification lives in the
  domain L3 package**. swift-sockets, not swift-kernel, hosts the Socket
  unifier today. The ambiguity fix MUST preserve that boundary: the
  `@_disfavoredOverload` applies to iso-9945 (upstream L2), not to
  swift-sockets. Reopening swift-kernel as the unifier home is explicitly
  forbidden.
- **Pattern 3 — docstring claims about binary behavior decay to falsehood
  without empirical verification**. The session that authored the
  migration discovered the RFC types' "network byte order" docstring was
  wrong via an experiment, not a code review. Relevant here because the
  L3 unifier's RFC→sockaddr marshalling relies on the `.bigEndian` swap;
  any fix that touches the unifier body (this handoff does NOT — scope is
  iso-9945 only) must verify the marshalling still holds empirically, not
  via docstring inspection.

### Mechanical parallel to Read/Write

The Read/Write fix applied `@_disfavoredOverload` to 10 `public static
func` declarations in swift-iso-9945. Socket family requires the same
mechanical shape applied to 10 declarations across 4 files (collision
count coincidentally equal). See Scope below.

## Relevant Files

### L2 raw (target of `@_disfavoredOverload`)

Collision map (iso-9945 declaration site ↔ swift-sockets unifier site).
All iso-9945 methods listed below receive `@_disfavoredOverload`.

| iso-9945 declaration | swift-sockets unifier (matching signature) |
|---|---|
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Accept.swift:41` — `accept(_:Kernel.Socket.Descriptor) -> Result` | `swift-sockets/.../Kernel.Socket.Accept+CrossPlatform.POSIX.swift:42` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Accept.swift:85` — `accept(_:Kernel.Descriptor) -> Result` | `swift-sockets/.../Kernel.Socket.Accept+CrossPlatform.POSIX.swift:61` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Connect.swift:39` — `connect(_, address: Storage, length:)` | `swift-sockets/.../Kernel.Socket.Connect+CrossPlatform.POSIX.swift:61` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Connect.swift:55` — `connect(_, address: IPv4)` | `swift-sockets/.../Kernel.Socket.Connect+CrossPlatform.POSIX.swift:78` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Connect.swift:63` — `connect(_, address: IPv6)` | `swift-sockets/.../Kernel.Socket.Connect+CrossPlatform.POSIX.swift:94` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Connect.swift:71` — `connect(_, address: Unix)` | `swift-sockets/.../Kernel.Socket.Connect+CrossPlatform.POSIX.swift:110` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Send.swift:35` — `send(_, from span:, options:)` | `swift-sockets/.../Kernel.Socket.Send+CrossPlatform.POSIX.swift:44` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Send.swift:100` — `message(_, header:, options:)` | `swift-sockets/.../Kernel.Socket.Send+CrossPlatform.POSIX.swift:103` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Receive.swift:34` — `receive(_, into span:, options:)` | `swift-sockets/.../Kernel.Socket.Receive+CrossPlatform.POSIX.swift:46` |
| `swift-iso-9945/.../ISO 9945.Kernel.Socket.Receive.swift:102` — `message(_, header:, options:)` | `swift-sockets/.../Kernel.Socket.Receive+CrossPlatform.POSIX.swift:95` |

### L2 raw (NOT part of this fix — no collision)

iso-9945 also declares these methods; swift-sockets has no matching
unifier overloads, so no `@_disfavoredOverload` is needed:

- `ISO 9945.Kernel.Socket.Send.swift:65` — `to(_, from span:, options:, address:, addressLength:)`. No swift-sockets sibling; call sites would resolve unambiguously through iso-9945 today.
- `ISO 9945.Kernel.Socket.Receive.swift:62` — `from(_, into span:, options:)`. No swift-sockets sibling.

Do NOT add `@_disfavoredOverload` to these. If swift-sockets later adds
`Kernel.Socket.Send.to(…)` / `Kernel.Socket.Receive.from(…)` unifiers —
or when the handoff's Out of Scope §"Span overloads parity" follow-on is
reconsidered — the same mechanical treatment applies THEN, not
speculatively now.

### L3 domain (unchanged by this handoff)

- `swift-sockets/Sources/Sockets/Kernel.Socket.Connect+CrossPlatform.POSIX.swift`
- `swift-sockets/Sources/Sockets/Kernel.Socket.Accept+CrossPlatform.POSIX.swift`
- `swift-sockets/Sources/Sockets/Kernel.Socket.Send+CrossPlatform.POSIX.swift`
- `swift-sockets/Sources/Sockets/Kernel.Socket.Receive+CrossPlatform.POSIX.swift`

These remain the canonical `Kernel.Socket.*` surface for consumers post-
fix. No body edits. No imports change. No renames. The fix operates
entirely upstream.

### Audit row stale-path amendment (minor collateral)

`swift-kernel/Audits/audit.md` Findings #10–#17 currently reference
`swift-kernel/Kernel.Socket.*+CrossPlatform.POSIX.swift` paths. Those
files no longer exist at those paths (migrated to swift-sockets in
`2c63378` + `9a83433`). This handoff may append a one-line amendment per
row citing the post-migration path + noting the ambiguity fix lands here.
Alternatively, defer the audit-path amendment to a later bookkeeping pass
— it is NOT a correctness blocker for the fix.

## Do Not Touch

- **swift-sockets source files** `Sockets.Error.swift`,
  `Sockets.TCP.Connection.swift`, `Sockets.TCP.Listener.swift`. These
  reference a removed `IO_Core` target and a removed `IO.Error` type
  from the user's active Phase-2 IO refactor. Do not attempt to fix in
  this scope. The ambiguity fix is orthogonal — `@_disfavoredOverload`
  applied to iso-9945 lands cleanly even while swift-sockets' `main` is
  broken for those unrelated reasons.
- **swift-sockets unifier bodies** (the four `+CrossPlatform.POSIX.swift`
  files). Do not modify. The ambiguity is resolved upstream, not by
  perturbing the unifier.
- **Windows-side socket surface** (`swift-windows-standard/Sources/Windows
  Kernel Socket Standard/*`). That's the sibling handoff's scope.
- **The migration architecture**. The reflection establishes swift-sockets
  as the home for socket unifiers; do not propose re-centralizing into
  swift-kernel to "resolve ambiguity at the source." That was explicitly
  reversed.
- **swift-kernel audit row SHAs**. Findings #10–#17 cite
  `bfa092e / 6a6d527 / 5bd87f3 / 6741b6a` as the unifier-landing SHAs.
  Those stay — they're historically accurate. Any amendment mentioning
  the ambiguity fix is additive, never replacement.

## Scope

Resolve the `Kernel.Socket.{Connect,Accept,Send,Receive}.*` ambiguity so
consumer code calling `Kernel.Socket.Connect.connect(…)` (etc.) resolves
unambiguously to the swift-sockets L3 unifier. Zero behavior change for
consumers; raw L2 access remains reachable via the qualified
`ISO_9945.Kernel.Socket.*` path.

### Recommended approach — `@_disfavoredOverload` on iso-9945 (mirror of 9aa06e6)

Mechanical parallel to the Read/Write fix. One line added above each of
the ten `public static func` declarations listed in § Relevant Files.

```swift
// swift-iso-9945/Sources/ISO 9945 Kernel Socket/ISO 9945.Kernel.Socket.Connect.swift
extension ISO_9945.Kernel.Socket.Connect {
    @_disfavoredOverload
    public static func connect(
        _ descriptor: borrowing Kernel.Socket.Descriptor,
        address: Kernel.Socket.Address.Storage,
        length: UInt32
    ) throws(Kernel.Socket.Error) {
        // body unchanged
    }
    // repeat for IPv4, IPv6, Unix overloads
}
```

After this lands:

- `Kernel.Socket.Connect.connect(descriptor, address: .ipv4(…))` resolves
  to the swift-sockets L3 unifier (EINTR-completion-aware).
- `ISO_9945.Kernel.Socket.Connect.connect(descriptor, address: .ipv4(…))`
  resolves to the L2 raw syscall (no retry).
- No consumer call site edits needed.

### Why NOT import-demotion (lesson from the Read/Write investigation)

The Read/Write handoff's Addendum §3 initially proposed demoting
`ISO_9945_Kernel_File` imports in swift-posix from `public import` to
`internal import` via `InternalImportsByDefault`. That failed because
every POSIX retry wrapper in swift-posix is `@inlinable` and `@inlinable`
bodies cannot reference symbols from internally-imported modules. The
demotion surfaced immediate compile errors.

The same would fail here. swift-sockets' unifier files declare each
method `@inlinable` (see
`Kernel.Socket.Connect+CrossPlatform.POSIX.swift:60` et al.) and delegate
through `POSIX.Kernel.Socket.Connect.connect(…)`. If the iso-9945 import
in swift-posix's `POSIX Kernel Socket` target (or swift-sockets'
`Sockets` target) were demoted, the `@inlinable` bodies lose the right to
reference iso-9945-declared types in their call paths. The Read/Write
investigation already exhausted this route; do not re-retread.

### Rejected alternatives (documented to prevent retreading)

- **Rename L2 spec-literal methods** (Phase-A-style, as used for Flush
  `fsync` / `fdatasync` / `fullFsync` / `barrierFsync`). POSIX already
  names these exactly `connect`, `accept`, `send`, `sendmsg`, `recv`,
  `recvmsg` — there's no spec-literal alternative. Identical to the
  Read/Write `read` / `write` case. Rejected by the Read/Write handoff
  Addendum §6 rule: *when the spec-literal name equals the intent-level
  name, post-hoc disambiguation is required; Phase-A does not apply.*
- **Rename the L3 unifier methods**. The Read/Write precedent rejected
  this for Read/Write; symmetry applies.
- **`@_spi(Syscall)` on L2 methods**. The Read/Write parent session
  attempted this and reverted. The swift-sockets unifier is `@inlinable`;
  `@inlinable` bodies cannot reference SPI from another module without
  mirroring the per-file `@_spi` discipline from swift-iso-9945
  internally. For the same reason import-demotion failed, this fails.
- **Revert the unifier landings** (`bfa092e / 6a6d527 / 5bd87f3 /
  6741b6a`). Re-opens Findings #10–#17. The unifiers are correct; the
  ambiguity is an orthogonal disambiguation problem.
- **Move the Socket unifier home back to swift-kernel**. Contradicts
  Pattern 2 of the reflection; the migration to swift-sockets was
  deliberate architectural work.
- **Promote `Kernel.Socket.{Connect,Accept,Send,Receive}` namespace and
  `Kernel.Socket.Address.*` types to L1 (swift-kernel-primitives)**. Out
  of scope for a disambiguation fix. The sibling Windows-closure handoff
  is the right venue for cross-platform namespace placement; this scope
  is limited to preventing the POSIX-side overload-resolution collision.

### Per-phase commits

One phase, one commit:

1. **swift-iso-9945**: apply `@_disfavoredOverload` to all ten `public
   static func` declarations in `Sources/ISO 9945 Kernel Socket/`. Commit
   message mirrors `9aa06e6`:

   > ISO 9945 Kernel Socket: @_disfavoredOverload on Connect/Accept/Send/Receive L2
   >
   > Preventative twin of the Read/Write fix (9aa06e6). swift-sockets'
   > cross-platform socket unifiers (`Kernel.Socket.{Connect,Accept,Send,
   > Receive}.*`) land extensions on the same underlying type that iso-9945
   > extends because `ISO_9945.Kernel = Kernel_Primitives.Kernel` via
   > typealias. Swift's overload resolution ambiguates between the L2 raw
   > and L3 unifier entries.
   >
   > Tag the ten colliding L2 `public static func` declarations with
   > `@_disfavoredOverload` so the L3 unifier wins resolution cleanly;
   > raw L2 access remains reachable via the qualified
   > `ISO_9945.Kernel.Socket.*` path. Mirrors the architecture established
   > at 9aa06e6 for `Kernel.IO.{Read,Write}`.
   >
   > Latent today because (a) no tests invoke the Kernel-namespace Socket
   > unifiers yet, and (b) swift-sockets' `main` fails earlier on
   > unrelated Phase-2 IO refactor debt (tracked in
   > `swift-foundations/swift-sockets/HANDOFF-windows-socket-unifier-closure.md`).
   > Landing this fix now eliminates the ambiguity as a blocker the
   > moment either of those unblocks.
   >
   > Resolves the Socket-family latent caveat flagged in
   > `swift-kernel/HANDOFF-io-read-write-l2-l3-ambiguity.md` Addendum §4.
   > Related audit rows (`swift-kernel/Audits/audit.md` §L3 Composition
   > Findings #10-#17) remain RESOLVED at the unifier-landing SHAs
   > (bfa092e / 6a6d527 / 5bd87f3 / 6741b6a); this is the follow-on
   > correctness fix the Read/Write handoff's Addendum §4 anticipated.

2. **Optional** — swift-kernel audit amendment. ONE line appended to each
   of rows #10–#17 in `audit.md` pointing at the post-migration path and
   noting the follow-on `@_disfavoredOverload` SHA:

   > 2026-04-21 follow-on: ambiguity-with-L2 fixed by `@_disfavoredOverload`
   > on iso-9945 Socket declarations (`{SHA}`). Unifier (now in
   > `swift-sockets/Sources/Sockets/Kernel.Socket.*+CrossPlatform.POSIX.swift`
   > post-migration in `2c63378 + 9a83433`) wins resolution cleanly.

   The path amendment from the migration (`swift-kernel/…` → `swift-sockets/…`)
   can fold into this line or be deferred. Not a correctness blocker.

### Verification

Because the ambiguity is latent, the before/after signal is not a
failing-to-passing test. The verification targets are:

1. `swift build --build-tests` green across swift-iso-9945, swift-kernel,
   swift-posix, swift-file-system, swift-io on Darwin + Linux. (Baseline
   from Read/Write fix: 90/90 swift-kernel, 560/560 swift-iso-9945,
   20/20 swift-posix, 712/712 swift-file-system, 61/61 swift-io.)
2. **Positive signal**: once swift-sockets' Phase-2 IO refactor lands and
   Sockets tests unblock, those tests compile against the unifier without
   ambiguity errors. Not verifiable in this handoff's scope; document the
   assumption and move on.
3. **Smoke test** (optional, recommended): add a single compile-time
   check in `swift-kernel/Tests/Kernel Tests/` that instantiates a call
   like `_ = try Kernel.Socket.Accept.accept(sockDescriptor)` inside a
   `#if canImport(Sockets)` guard (or similar) to force resolution
   through the L3 unifier. If the smoke test compiles without ambiguity,
   the fix is verified. If swift-sockets isn't importable from the
   swift-kernel test target in this configuration, skip it; overload
   resolution is deterministic from `@_disfavoredOverload` and prior
   Read/Write precedent.

### Out of scope

- **Windows-side socket closure**. Tracked separately in
  `swift-foundations/swift-sockets/HANDOFF-windows-socket-unifier-closure.md`.
  Its Phase A (add `Windows.Kernel.Socket.Address.{Storage,IPv4,IPv6}` +
  typed overloads in swift-windows-standard) and Phase B (four new
  `Kernel.Socket.*+CrossPlatform.Windows.swift` files in swift-sockets)
  establish the Windows RFC-valued unifier surface. That work is BLOCKED
  on swift-sockets `main` building; when it unblocks, the Windows-closure
  handoff is the right venue. Ambiguity fix landing first is beneficial —
  the Windows files will declare fresh `Kernel.Socket.{Connect,Accept,Send,
  Receive}` namespace entries and consume the same `@_disfavoredOverload`
  discipline for any Windows-side L2 layer that eventually materializes.
- **Promoting Socket types to L1**. The `Kernel.Socket.Address.{Storage,
  IPv4,IPv6,Unix}`, `Kernel.Socket.Accept.Result`,
  `Kernel.Socket.Message.Header`, and the `Connect` / `Accept` / `Send` /
  `Receive` namespaces all live in swift-iso-9945 (L2 POSIX spec) today.
  Audit rows #10–#17 call out this as the Windows-gap blocker. Solving it
  is architectural work for the sibling Windows-closure handoff, not this
  one. Within THIS scope, the POSIX-typed surface stays POSIX-only; the
  cross-platform currency is RFC values (see commit `2afb251`).
- **`to(_, from:, options:, address:, addressLength:)` and
  `from(_, into:, options:)` overloads in iso-9945**. No swift-sockets
  unifier counterpart today; no collision. Tag with
  `@_disfavoredOverload` only when / if swift-sockets adds matching
  unifier overloads in a future pass. Preemptive tagging now would be
  semantically wrong (disfavoring an overload with no competing overload
  is noise) and violates `[feedback_no_degrade_noncopyable]`-style "don't
  add guards for conditions that can't happen."
- **Span adapter overloads** in iso-9945 Read/Write were tagged with
  `@_disfavoredOverload` in `9aa06e6`; the Socket family L2 layer has
  *no* span adapter overloads today (iso-9945 Socket methods already take
  `Span<UInt8>` / `MutableSpan<UInt8>` as their primary shape). Nothing
  to tag that isn't already listed.
- **Audit.md §L3 Composition column text full rewrite**. The rows'
  status-column prose still references swift-kernel paths; a cleaner
  rewrite is a separate bookkeeping task. The one-liner amendment is
  sufficient for this handoff.
- **Reflection [skill] action item** (Pattern 2 → platform-skill rule
  codifying "domain-specific cross-platform unification lives in the
  domain L3 package"). Out of scope for the fix; tracked in the
  reflection's Action Items and deferred to a platform-skill update pass.

## Findings Destination

After landing the fix:

1. Commit lands in swift-iso-9945 per § Per-phase commits.
2. Optional audit-amendment commit in swift-kernel.
3. Append a `## Findings` section to this file mirroring the shape of
   `HANDOFF-io-read-write-l2-l3-ambiguity.md`'s Findings section:
   - Resolution summary (`@_disfavoredOverload` on ten declarations).
   - Verification (build-green across the five packages).
   - Any surprises encountered during landing.
   - Commit SHA.
   - Reflection prompt on whether the Addendum §4 anticipation was
     accurate (expected: yes, straightforward mechanical parallel).
4. Close out the Addendum §4 reference in
   `HANDOFF-io-read-write-l2-l3-ambiguity.md` with a one-line pointer
   to this handoff's landing SHA. That handoff stays in place (its
   primary scope is Read/Write; Addendum §4 was informational).

## Constraints

- swift-6.3+ / swift 6 language mode (per ecosystem `[PATTERN-005]`).
- `[PLAT-ARCH-008e]` — the L3 unifier composes over the L3 platform-
  policy tier (swift-posix) which composes over L2 raw; do not collapse
  the tiers.
- `[PLAT-ARCH-008d]` — domain packages own their cross-platform
  unification surface. Mirror the reflection's Pattern 2: swift-sockets
  is the Socket unifier's home; do not re-centralize.
- `[feedback_prefer_typed_throws_over_try_optional]` — not directly
  relevant but preserved; the bodies are unchanged so typed-throws
  discipline is intact.
- `[feedback_handoff_branch_prescriptions]` — work on `main` unless a
  branch is actively contested. swift-iso-9945 main is clean; land
  directly.
- **Do not touch the RFC→sockaddr marshalling seam** in
  `Kernel.Socket.Connect+CrossPlatform.POSIX.swift:118–198`. Per Pattern
  3 of the reflection, changes there require empirical re-verification.
  This handoff's fix is upstream of the marshalling seam — iso-9945's
  decorators do not perturb the byte-order conversion or the `bigEndian`
  swap.
- **Strict memory safety** (`[PATTERN-005a]`) — `@_disfavoredOverload`
  is a pure resolution-priority attribute; it does not relax or tighten
  any `unsafe` annotation on the method bodies. The existing `unsafe`
  markers in the bodies stay.

## Proposal staleness per [HANDOFF-016]

- **Assumes**: iso-9945 Socket method signatures listed in § Relevant
  Files match what's in swift-sockets' unifiers today. Re-verify via
  `grep -nE "public static func (connect|accept|send|receive|message)"`
  across both packages before applying — signatures may have drifted if
  a sibling session has been editing. As of 2026-04-21 the counts are:
  Accept ×2, Connect ×4, Send ×2, Receive ×2 = 10 matching pairs.
- **Assumes**: swift-sockets unifier files remain `@inlinable` —
  necessary for the `@_disfavoredOverload` approach to hold (because
  import-demotion is blocked by `@inlinable` per the Read/Write lesson).
  If a future refactor moves the unifier bodies out of `@inlinable`, the
  import-demotion alternative (Read/Write handoff Addendum §3) becomes
  viable again; this handoff's recommendation would still be cheaper
  (one line per method) versus (one internal-import per file + every
  affected downstream consumer).
- **Assumes**: swift-sockets' Phase-2 IO refactor (`Sockets.Error`,
  `Sockets.TCP.Connection`, `Sockets.TCP.Listener`) remains broken as of
  this handoff's writing. If it has since been unblocked, the ambiguity
  becomes non-latent and this handoff's priority increases from
  "preventative" to "unblocks test run." Check swift-sockets `main` with
  `swift build` before deciding commit timing.
- **Assumes**: audit.md rows #10–#17 have NOT been rewritten since the
  2026-04-20 migration (`2c63378 + 9a83433`) — their paths still point
  at the removed `swift-kernel/Kernel.Socket.*+CrossPlatform.POSIX.swift`
  locations. If a prior session has already amended them, fold this
  handoff's optional amendment into the existing amendment style rather
  than duplicating.
- **Assumes**: no other ecosystem package has introduced a third-party
  `extension Kernel.Socket.{Connect,Accept,Send,Receive}` with matching
  signatures (e.g., a third L3 domain package attempting its own
  unifier). Grep `extension Kernel\.Socket\.(Connect|Accept|Send|Receive)`
  across all packages before applying. As of 2026-04-21, only iso-9945
  (L2) and swift-sockets (L3) declare such extensions.

---

## Appendix A — Relation to `HANDOFF-windows-socket-unifier-closure.md`

The sibling handoff in `swift-foundations/swift-sockets/` covers the
Windows gap: typed `Windows.Kernel.Socket.Address.*` wrappers in
swift-windows-standard (Phase A), and four Windows-platform unifier
files in swift-sockets mirroring the POSIX RFC-valued surface (Phase B).

**Composition between the two handoffs**:

- This handoff is FIRST. It fixes overload resolution on POSIX today.
- Windows-closure handoff is SECOND. It cannot start until swift-sockets
  `main` builds (which requires the Phase-2 IO refactor — out of scope
  for both).
- When Windows-closure starts, its four new
  `Kernel.Socket.*+CrossPlatform.Windows.swift` files declare fresh
  namespace entries (`extension Kernel.Socket { public enum Connect {} }`
  etc. at file head, since Windows today has no iso-9945 equivalent).
  Those declarations will NOT collide with iso-9945 (which is
  `#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)`-gated
  at the L2 source). Windows's fresh namespace declarations stand alone
  on Windows; iso-9945's declarations stand alone on POSIX; the
  `@_disfavoredOverload` landed here makes swift-sockets' POSIX
  unifier win on POSIX. Three disjoint surfaces with no cross-platform
  ambiguity.
- **Cross-handoff contract**: the Windows-closure handoff's Phase B
  files must NOT add `@_disfavoredOverload` — they are the ONLY socket
  unifier on Windows (no L2 raw competitor). Adding it would be noise.

## Appendix B — Relation to the 2026-04-20 reflection

Three of the reflection's four patterns fed directly into this handoff's
shape:

- Pattern 2 ("domain L3 owns unifier") — established the "do not re-
  centralize into swift-kernel" constraint; codified as § Do Not Touch.
- Pattern 3 ("empirical verification of binary claims") — framed the "do
  not touch RFC→sockaddr marshalling seam" constraint.
- Pattern 4 ("memory staleness warnings are signals") — informed the
  § Proposal staleness section's insistence on re-verifying signatures
  and swift-sockets main state before landing.

Pattern 1 ("prior art reverses first-principles design") is not directly
load-bearing here because the proposed fix is mechanical precedent from
the Read/Write sibling landed hours earlier — the precedent IS the prior
art, and no reversal is needed. It is load-bearing on the *reflection*
Action Item to formalize swift-sockets-as-unifier-home in a platform
skill; that is out of this handoff's scope.

---

## Appendix C — Ambiguity counts table (for the Findings section)

Fill in during landing:

| Package | Methods tagged | Sites compared | Build clean | Tests |
|---|---|---|---|---|
| swift-iso-9945 | 10 | 10 | pending | pending |
| swift-kernel | 0 (scope boundary) | — | pending | pending |
| swift-posix | 0 (scope boundary) | — | pending | pending |
| swift-sockets | 0 (scope boundary; still blocked by IO refactor) | — | blocked | blocked |
| swift-file-system | 0 | — | pending | pending |
| swift-io | 0 | — | pending | pending |
