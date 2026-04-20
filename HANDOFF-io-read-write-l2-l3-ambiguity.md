# Investigation: Kernel.IO.Read/Write L2/L3 ambiguity blocks ecosystem tests

> To investigate: read this file for full context. The parent conversation
> is continuing separate work — avoid modifying files under "Do Not Touch."

## Issue

Every call site of `Kernel.IO.Read.read`, `.pread`, `Kernel.IO.Write.write`,
`.pwrite`, `.writeAll` reports `ambiguous use of '...'` — two candidate
declarations with identical signatures, one in module `ISO_9945_Kernel_File`
(L2 raw, swift-iso-9945) and one in `Kernel_File` (L3 unifier, swift-kernel).

The collision exists because `ISO_9945.Kernel` is a typealias of
`Kernel_Primitives.Kernel`, so iso-9945's `extension ISO_9945.Kernel.IO.Write`
lands methods on the same type that the L3 unifier extends. Both declare
`write(_:from:)` with identical signatures; Swift's name lookup cannot
disambiguate.

Introduced by swift-kernel commit **5b0ae3b** (2026-04-20) —
*"Kernel File: add cross-platform Kernel.IO.Write unifiers delegating through
L3 platform policy"* — and its Read sibling. The unifier methods themselves
comply with [PLAT-ARCH-008e] (explicit definition delegating to
`POSIX.Kernel.IO.Write.write`, not namespace-alias inheritance). The problem
is that iso-9945's L2 extension already occupies the same namespace slot
because of the typealias.

Symptom: `Kernel_Test_Support` target fails to compile →
`swift test` blocked across every downstream package, including
swift-file-system, swift-io, and the swift-kernel tests themselves.

The Flush fix (639a428 etc.) worked by renaming L2 to POSIX man-page names
(`fsync`/`fdatasync`/`fullFsync`/`barrierFsync`) distinct from L3's abstract
names (`flush`/`data`). For Read/Write the POSIX names literally *are*
`read`/`write`, so that route doesn't help — disambiguation requires
introducing a new namespace tier.

## Parent Context

The parent session landed swift-file-system's typed-path and error-payload
upgrade (41e1458, 228b2b4, 8f19d65, f098a44) plus Windows Path.View
conformances in swift-windows-standard (a3fefbf). Production targets
compile clean; the full test suite cannot run until this collision is
resolved. The parent attempted an `@_spi(Syscall)` fix on iso-9945's L2
methods and reverted it (rippled too broadly; incompatible with swift-posix's
`@inlinable`; many downstream callers rely on the current transitive
re-export of iso-9945 through `Kernel`).

**Cross-reference — `HANDOFF-platform-compliance-consumer-migration.md`** is
blocked on this ambiguity for test validation. The terminal consumer migration
across swift-file-system has six migration classes; the current state is:

- **Class 1** (error-code predicates, 17 sites) — **landed** in swift-file-system
  commit 93e3a50 (bundled into a "Save progress" commit alongside the parent's
  typed-path upgrade and test-naming migration). Does NOT depend on the
  Read/Write ambiguity. Out of scope for this handoff.
- **Classes 2, 3, 6** (File.Name encoding, Flush family, cross-ecosystem
  POSIX.Kernel.Socket.Accept) — pending; not dependent on Read/Write
  symbol resolution but dependent on a green `swift test`. Unblocked once
  this handoff lands.
- **Classes 4, 5** (path helpers, Random.fill) — already resolved 2026-04-20
  (41e1458).

Do not extend this handoff's scope to cover those consumer migrations;
`HANDOFF-platform-compliance-consumer-migration.md` is the owner.

## Relevant Files

L2 raw (to be renamed/namespaced):
- `swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.IO.Write.swift:25,133,170` — extensions on `ISO_9945.Kernel.IO.Write`
- `swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.IO.Read.swift:25,107` — extensions on `ISO_9945.Kernel.IO.Read`

L3 unifier (keep as-is; it's correct per [PLAT-ARCH-008e]):
- `swift-kernel/Sources/Kernel File/Kernel.IO.Write+CrossPlatform.POSIX.swift:39` — L3 unifier for Write
- `swift-kernel/Sources/Kernel File/Kernel.IO.Read+CrossPlatform.POSIX.swift` — sibling for Read

L3 platform policy (calls L2 raw internally; must update to new L2 path):
- `swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.IO.Write.swift:66,92,125,150,169,185` — `@inlinable` EINTR-retry wrappers
- `swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.IO.Read.swift:60,83,117,143,162` — same for Read

Consumer call sites (migrate to chosen disambiguation):
- `swift-kernel/Sources/Kernel Completion/Kernel.Completion.Notification+Wait.swift:28`
- `swift-kernel/Tests/Support/Kernel.IO.Test.Helpers.swift:61,109,133`
- `swift-kernel/Tests/Support/Kernel.Event.Test.Support.swift:49,59`
- `swift-kernel/Tests/Kernel Tests/Kernel Tests.swift:98,105,133,156,166`
- `swift-kernel/Tests/Kernel Tests/Kernel.Lock.Integration Tests.swift:42`
- `swift-io/Tests/IO Blocking Tests/IO.Blocking.Binding.Tests.swift` (one site)
- `swift-io/Tests/Support/Event.Actor+Basic.swift` (one site)
- `swift-io/Tests/Support/Kernel.Thread.Actor+Basic.swift` (one site)
- `swift-file-system/Sources/File System Core/File.System.Write+Shared.swift:99,150` — inline `Kernel.IO.Write.write(fd, from: slice)` calls inside custom partial-write loops (not a literal `writeAll` — the outer loop already handles slice advancement). The adjacent `catch let error as Kernel.IO.Write.Error` at `:111,:162` disambiguates implicitly once the call site resolves, so no catch-clause edit is needed on migration.
- `swift-file-system/Sources/File System/Kernel.Thread.Actor+File.System.swift` — one site (untracked file; owned by in-progress work)

L2 tests (unaffected if L2 retains `ISO_9945.Kernel.IO.*` access path):
- `swift-iso-9945/Tests/ISO 9945 Kernel Tests/ISO 9945.Kernel.IO.{Read,Write} Tests.swift`

Docs / README references (update after code lands):
- `swift-kernel/README.md:69,75`
- `swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.IO.{Read,Write}.swift` doc comments referencing `Kernel.IO.{Read,Write}.{read,write}`

## Do Not Touch

All four repos are currently clean; no uncommitted files. But the parent
session has unpushed local commits in swift-file-system (41e1458, 228b2b4,
8f19d65, f098a44, 93e3a50) and swift-windows-standard (a3fefbf) — do not
reset or force-push. Continue on `main` per
`[feedback_handoff_branch_prescriptions]`.

## Scope

Resolve the `Kernel.IO.Read/Write` ambiguity so `swift build --build-tests`
passes in every dependent package on Darwin + Linux. Restore `swift test`
for swift-file-system, swift-io, swift-kernel.

### Recommended approach — Option A: `Raw` sub-namespace on L2

1. **Add the namespace**: `extension Kernel.IO.Write { public enum Raw {} }`
   and the same for `Kernel.IO.Read`. Declaration home: swift-kernel-primitives
   (L1) so both L2 and L3 see it. One empty enum per type, nothing else.

2. **Move L2 method bodies**: in swift-iso-9945, change
   `extension ISO_9945.Kernel.IO.Write { public static func write(...) }` to
   `extension ISO_9945.Kernel.IO.Write.Raw { public static func write(...) }`.
   Same for `pwrite`, `writeAll`, span overloads, and all of Read. Methods
   keep their names (`write`, `pwrite`, `writeAll`, `read`, `pread`); the
   disambiguator is the `.Raw.` path segment.

3. **Update L3 platform-policy wrappers** in swift-posix: change
   `Kernel.IO.Write.write(descriptor, from: buffer)` to
   `Kernel.IO.Write.Raw.write(descriptor, from: buffer)` inside the
   `@inlinable` EINTR-retry bodies. Same for Read. `@inlinable` stays
   (no SPI involvement, `.Raw.*` methods are plain public).

4. **Update consumer call sites** that currently rely on the iso-9945 raw
   being visible through the `Kernel` re-export chain:
   - `swift-kernel/Sources/Kernel Completion/Kernel.Completion.Notification+Wait.swift:28`
     should use the L3 unifier (`Kernel.IO.Read.read`) now that it's
     unambiguous and EINTR-safe — a semantic improvement over the current
     raw-L2 call that relied on the outer retry loop.
   - swift-kernel tests and test support files: migrate to the L3 unifier
     where tests want EINTR-safe behavior; migrate to `.Raw.*` where tests
     specifically exercise the raw syscall path.
   - swift-file-system / swift-io internal helpers: same choice per site.
     For `File.System.Write+Shared.swift:99,150` specifically: migrate to the
     L3 unifier (`Kernel.IO.Write.write`, post-`.Raw.`-split). The outer loop
     already handles partial writes; delegating EINTR retry to L3 is a
     semantic improvement, not a behavior change, because the current code
     surfaces EINTR to the outer loop as a `Kernel.IO.Write.Error` it does
     not re-try — the L3 unifier fixes that bug incidentally.

5. **Verify on Darwin + Linux**: `swift build --build-tests && swift test`
   in swift-kernel, swift-iso-9945, swift-posix, swift-file-system, swift-io.
   712/712 in swift-file-system was the pre-collision baseline.

### Rejected alternatives (documented to prevent retreading)

- **Option B — rename L3 unifier** to `writeBytes` or similar. Defeats the
  point of [PLAT-ARCH-008e] naming parity and diverges from the Flush
  precedent in spirit.
- **Option C — revert 5b0ae3b**. Removes the unifier entirely; re-opens
  swift-kernel audit.md [PLAT-ARCH-008e] Findings #5–9 (IO.Read is #5–6,
  IO.Write is #7–9) — the L3 unifier would stop existing, so consumers lose
  the EINTR-safe cross-platform entry point they were added to provide. (Note:
  5b0ae3b is the IO.Write commit; 24cf586 is the IO.Read commit. A revert
  would need both.)
- **Option D — strip `public import ISO_9945_Kernel_File` from swift-posix**.
  Breaks transitive consumers (many files in swift-kernel's own targets
  import `POSIX_Kernel_File` and rely on iso-9945 types flowing through).
- **`@_spi(Syscall)` on L2 methods** (parent attempted, reverted). Two
  blockers: swift-posix's `@inlinable` L3 wrappers cannot reference SPI
  methods from another module; and removing `@inlinable` + rewiring all
  consumer imports proved to ripple further than the rename.

### Per-phase commits

Commit each phase as a checkpoint per [HANDOFF-019]:
1. swift-kernel-primitives — add `Kernel.IO.{Read,Write}.Raw` empty namespaces
2. swift-iso-9945 — move L2 raw methods to `.Raw.`
3. swift-posix — retarget internal calls to `.Raw.`
4. swift-kernel — update Kernel.Completion.Notification+Wait + tests + test support
5. swift-io + swift-file-system — update remaining consumer call sites
6. Docs/README touchup

### Out of scope

- **Windows-side IO**: no collision exists — Windows has no swift-windows L3
  platform-policy peer for IO.Read/Write; the L3 unifier file comments note
  this ("L3 platform tier empty exception").
- **Flush family**: already resolved via rename (639a428). Do not re-touch.
- **Socket I/O or Completion collisions**: any are separate — this handoff
  is scoped to `Kernel.IO.Read` and `Kernel.IO.Write` only.
- **Raw-vs-policy audit elsewhere**: don't sweep the whole ecosystem for
  similar collisions in this handoff; file any new ones as fresh findings.

## Findings Destination

- Commits land in the five repos listed under the per-phase sequence.
- Append a `## Findings` section to this file on completion, listing the
  final SHAs and any semantic changes consumers should know about (e.g.,
  which test sites switched from raw to L3-unified — a behavior change from
  "may throw EINTR" to "transparently retries EINTR").
- Close swift-kernel audit.md [PLAT-ARCH-008e] Findings **#5–9** (IO.Read is
  #5–6, IO.Write is #7–9; the Socket.Receive Findings #14–16 are a separate
  family not affected here) with the resolution SHAs. The Findings were
  marked RESOLVED at 24cf586 / 5b0ae3b; that resolution introduced the
  ambiguity — update the status text to cite 24cf586 / 5b0ae3b as the
  L3-unifier trigger and the Raw-namespace migration as the follow-on
  correctness fix, keeping the RESOLVED state.
- A post-session reflection on the L2-alias-vs-L3-unifier pattern would be
  valuable — this will likely recur for any other syscall family whose L3
  unifier name matches the POSIX man-page name.

## Constraints

- swift-6.3+ / swift 6 language mode (per ecosystem `[PATTERN-005]`).
- `[PLAT-ARCH-008e]` — the L3 unifier composes over the L3 platform-policy
  tier (swift-posix) which composes over L2 raw; do not collapse the tiers.
- `[PATTERN-005a]` strict memory safety — `.Raw.*` methods remain `unsafe`
  at invocation; L3 wrappers preserve the existing `unsafe try` shape.
- `[feedback_handoff_branch_prescriptions]` — work on `main` unless a branch
  is actively contested; the repos here have unpushed work but no conflicts.
- `[feedback_prefer_typed_throws_over_try_optional]` — if any test or
  consumer call site is caught between "want raw syscall" and "want
  EINTR-safe", prefer the L3 unifier; the EINTR retry in swift-posix is the
  intended default.

---

## Addendum from the originating session (2026-04-20)

This is added by the session that **landed the offending commits** (24cf586,
5b0ae3b, bfa092e, 6a6d527, 5bd87f3 on swift-kernel main; audit update folded
into 2afb251). It sharpens the handoff with two pieces of context the
investigator did not have.

### 1. Option A (`.Raw.` sub-namespace) is user-forbidden

During the diagnosis conversation the user stated, verbatim:

> "We forbid 'iso-9945 under Raw namespace'."

The recommended "Option A" at line 113 **must not be taken**. Any revised plan
that routes L2 raw through `ISO_9945.Kernel.IO.{Read,Write}.Raw.*` has to be
discarded. The remaining listed options (B, C, `@_spi(Syscall)`) remain
rejected for the reasons the investigator documented. The user's stated
preference was a **combination of `internal` and `public` imports**, with
the explicit constraint "I want to minimize downstream adjustments."

### 2. Option D's rejection needs re-examination — it is clean for Read/Write

The handoff rejects Option D ("strip `public import ISO_9945_Kernel_File`
from swift-posix") on the grounds that "many files in swift-kernel's own
targets import `POSIX_Kernel_File` and rely on iso-9945 types flowing
through." That claim is **true for Socket, false for Read/Write**:

- **Read/Write error types live at L1** — `Kernel.IO.Read.Error` at
  `swift-kernel-primitives/Sources/Kernel File Primitives/Kernel.IO.Read.Error.swift`,
  `Kernel.IO.Write.Error` adjacent. `Kernel.Descriptor`, `Kernel.File.Offset`,
  `UnsafeMutableRawBufferPointer`, `MutableSpan<UInt8>` are all L1 /
  stdlib. swift-posix's Read/Write public signatures reference **zero**
  iso-9945 types; demoting `ISO_9945_Kernel_File` to a non-re-exported
  import in swift-posix compiles.
- **Socket types live at iso-9945** — `Kernel.Socket.Accept.Result`,
  `Kernel.Socket.Address.Storage`, `Kernel.Socket.Message.{Options,Header}`
  are declared in `swift-iso-9945`. swift-posix's Socket public signatures
  reference these. Stripping the iso-9945 re-export from `POSIX_Kernel_Socket`
  breaks that surface. Option D as stated is **not** clean here.

### 3. Recommended revised plan — import demotion (Read/Write only)

Both swift-kernel and swift-posix enable `InternalImportsByDefault` and
`MemberImportVisibility` upcoming features (verified in their `Package.swift`).
The combination means a plain `import X` is internal-only, and extension
members from `X` are only visible to source files that directly import `X`.

Proposed:

1. `swift-posix/Sources/POSIX Kernel File/exports.swift` — remove
   `@_exported public import ISO_9945_Kernel_File`. Replace with a comment
   noting iso-9945 is used internally per-file.
2. `swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.IO.Read.swift`,
   `POSIX.Kernel.IO.Write.swift`, `POSIX.Kernel.File.Flush*.swift` —
   change `public import ISO_9945_Kernel_File` to plain
   `import ISO_9945_Kernel_File` (internal under InternalImportsByDefault).
3. Verify: `swift build --build-tests` clean in swift-kernel, swift-posix,
   swift-iso-9945.
4. If any consumer outside swift-posix hits "module not imported" for
   iso-9945 extension use, migrate that site to the L3 unifier
   (`Kernel.IO.Read.read`) — which is the audit's intended end state
   anyway (consumer-migration pass tracked by
   `HANDOFF-platform-compliance-consumer-migration.md`).

**Unknown to verify before committing**: whether `MemberImportVisibility`
actually suppresses iso-9945 extensions reached via
`@_exported public import POSIX_Kernel` → ... → iso-9945. `@_exported`
historically signaled "treat as if directly imported," which might bypass
MemberImportVisibility's direct-import requirement. If the demotion does
not resolve the ambiguity, file a secondary finding and fall back to
`@_disfavoredOverload` on iso-9945's Read/Write `public static func`
declarations — a one-line-per-method change that is narrow and reversible.

### 4. Scope warning — Socket family is latently broken with the same shape

The handoff says (§ Out of scope, line 188):

> "Socket I/O or Completion collisions: any are separate — this handoff is
>  scoped to Kernel.IO.Read and Kernel.IO.Write only."

Accurate as a scoping decision, but the Socket family **already has the same
ambiguity shape**, silent only because no tests call the unifiers yet:

- `Kernel.Socket.Accept.accept` (landed bfa092e, this session) — latent.
- `Kernel.Socket.Send.{send,to,message}` (landed 6a6d527, this session) — latent.
- `Kernel.Socket.Receive.{receive,from,message}` (landed 5bd87f3, this session) — latent.
- `Kernel.Socket.Connect.connect` (landed 6741b6a, **pre-existing, before this
  session**) — latent. The Connect commit was presumed working; it is
  architecturally broken the same way.

The import-demotion plan in §3 **does not** work for Socket as-is, because
swift-posix's Socket public surface references iso-9945 types. A separate
handoff is warranted to either (a) promote the socket types to L1 or
(b) apply `@_disfavoredOverload` to iso-9945's `Socket.{Accept,Send,Receive,
Connect}` methods. Do not fold this into the Read/Write fix; track
separately. The audit rows for Findings #10–#17 need a status caveat when
this secondary handoff opens.

### 5. Corrections to the "Findings Destination" section

- Line 200 reads "Findings **#5–9**" — accurate, but the audit update in
  commit 2afb251 transitioned those rows to RESOLVED with the landing SHAs
  (24cf586 for #5–6, 5b0ae3b for #7–9). This handoff's work will add a
  follow-on commit; the resolution text should be **amended**, not
  overwritten, to cite both the L3-unifier trigger (24cf586/5b0ae3b) and
  the ambiguity fix.
- The parent's attempt at `@_spi(Syscall)` was **not** revertible cleanly
  because the audit table had already been updated. Any future revert
  route must update the audit too. Mentioning this to save re-learning.

### 6. Reflection prompt

The investigator's line 207–209 ("a post-session reflection on the
L2-alias-vs-L3-unifier pattern would be valuable") is reinforced. The
originating session's failure was accepting the claim in the parent
audit — *"L2 names are already spec-literal, so no Phase-A-style rename
needed"* — without testing the compiler's actual resolution. The rule
that should emerge: **any [PLAT-ARCH-008e] remediation where the
spec-literal name equals the intent-level name requires a Phase-A-style
disambiguation before the L3 unifier lands, not after**.

---

## Findings (2026-04-20, executing session)

### Resolution: `@_disfavoredOverload` on iso-9945 Read/Write (fallback path)

The Addendum §3 import-demotion plan (internal-import ISO_9945_Kernel_File
from swift-posix) was attempted and reverted. Root cause: every
`POSIX.Kernel.IO.{Read,Write}` and `POSIX.Kernel.File.Flush*` wrapper is
`@inlinable`, and `@inlinable` bodies cannot reference symbols from an
internally-imported module. The compiler produces "property/method is
internal and cannot be referenced from an '@inlinable' function" diagnostics
at every call into `Kernel.IO.Read.read`, `isInterrupted`, `ISO_9945.Kernel.*`,
etc. Demoting would force stripping `@inlinable` from all POSIX retry
wrappers — a public-ABI change beyond this handoff's scope.

Applied fallback from Addendum §3 (" … fall back to `@_disfavoredOverload`
on iso-9945's Read/Write `public static func` declarations — a
one-line-per-method change that is narrow and reversible"). Ten `public
static func` declarations in `swift-iso-9945` received `@_disfavoredOverload`:

- `ISO 9945.Kernel.IO.Read.swift`: `read(_:into:)` buffer + span,
  `pread(_:into:at:)` buffer + span.
- `ISO 9945.Kernel.IO.Write.swift`: `write(_:from:)` buffer + span,
  `pwrite(_:from:at:)` buffer + span, `writeAll(_:from:)` buffer + span.

The L3 unifier in `swift-kernel/Kernel.IO.{Read,Write}+CrossPlatform.POSIX.swift`
now wins overload resolution unambiguously. Raw L2 access via
`ISO_9945.Kernel.IO.{Read,Write}.*` remains reachable at its qualified path.
No consumer call site needed migration: every `Kernel.IO.Read.read` /
`Kernel.IO.Write.write` call now resolves to the L3 unifier (EINTR-safe),
which matches the audit's intended end state.

### Verification

Clean builds + `swift test` (Darwin, Xcode 26.4.1 / Swift 6.3.1):

| Package             | Tests       | Status                                               |
|---------------------|-------------|------------------------------------------------------|
| swift-kernel        | 90 / 90     | pass                                                 |
| swift-iso-9945      | 560 / 560   | pass (one pre-existing duplicate `@Test` fixed)       |
| swift-posix         | 20 / 20     | pass                                                 |
| swift-file-system   | 712 / 712   | pass (matches pre-collision baseline)                |
| swift-io            | 61 / 61     | pass (clean build resolves swift-property-primitives linker cache) |

The `Kernel.IO.Read/Write` `ambiguous use of` diagnostics reported by the
handoff at 11 consumer call sites (plus `Kernel.Completion.Notification+Wait`,
the swift-kernel test support files, swift-io's binding/actor test support,
and `File.System.Write+Shared` inner calls) are all gone. No consumer call
site required editing; the `@_disfavoredOverload` change is transparent to
callers of `Kernel.IO.Read.*` / `Kernel.IO.Write.*`.

### Collateral fixes (unblocked the baseline)

The handoff scopes strictly to the ambiguity; these remaining items blocked
`swift test` but are not Read/Write:

1. **Duplicate `@Test` functions** — two repos each had a sibling pair of
   `@Test` functions with identical backtick-quoted names inside the same
   `@Suite`, which the swift-testing macro expansion promotes to a symbol
   redeclaration error:
    - `swift-iso-9945/Tests/ISO 9945 Kernel Tests/ISO 9945.Kernel.Thread.Handle Tests.swift:57`
      — renamed `\`Handle type exists\`()` → `\`Handle is @unchecked Sendable\`()`.
      The duplicate sat under the "Conformance Tests" section; the new name
      matches the section intent.
    - `swift-file-system/Tests/File System Core Tests/File.System.Stat Tests.swift:207`
      — renamed `\`info(followSymlinks: false) returns symbolicLink type for symlink\`()`
      → the same name suffixed `(Handle API)`, distinguishing it from the
      `File.System.Write.Atomic.write`-based sibling at `:95`.

2. **`Swift.String` → `File.Path` in Atomic.Error / Streaming.Error tests**
   (the parent session's typed-path migration had not updated the error
   tests). Sites migrated:
    - `File.System.Write.Atomic Tests.swift`: 3 blocks (`destinationExists`,
      `renameFailed`, `directorySyncFailed`).
    - `File.System.Write.Atomic.Error Tests.swift`: 7 blocks covering
      `parentVerificationFailed`, `destinationStatFailed`,
      `tempFileCreationFailed`, `destinationExists`, `renameFailed`,
      `directorySyncFailedAfterCommit`, `directorySyncFailed`, and the
      `\`Error is Equatable\`` scaffolding.
    - `File.System.Write.Streaming.Error Tests.swift`: every `path:`-bearing
      case plus the `Equatable` EdgeCase scaffolding (9 sites).
    - `File.System.Write.Streaming Tests.swift:272` and
      `File.System.Write.Streaming.Error Tests.swift` `writeFailed` sites
      — removed the obsolete `path:` argument (Streaming.Error.writeFailed
      no longer carries `path:`; the case is `writeFailed(bytesWritten:,
      code:, message:)`). The pattern-match at the removed site was updated
      from `.writeFailed(let p, let bytes, …)` to `.writeFailed(let bytes, …)`.
   Type switch: `let path: Swift.String = "…"` → `let path: File.Path = "…"`
   using `ExpressibleByStringLiteral`. Where call sites called
   `error.description.contains(path)`, the argument was wrapped in
   `Swift.String(path)` (File.Path is `CustomStringConvertible`; the
   non-failable `String.init(_: Path)` is already exported).

### Deliberately out of scope

- **Socket family latency** (Addendum §4). `Kernel.Socket.{Accept,Send,Receive,
  Connect}` carry the same L2/L3 ambiguity shape silently (no tests invoke
  them as `Kernel.*`). Not addressed here; a separate handoff is warranted.
  `@_disfavoredOverload` at L2 will not work unchanged for Socket because
  swift-posix's Socket public surface references iso-9945 types directly —
  demoting the iso-9945 import in swift-posix would break `POSIX.Kernel.Socket`
  callers. Candidate remediations for the Socket handoff: (a) promote
  `Kernel.Socket.Accept.Result` / `Kernel.Socket.Address.Storage` / the
  Message types to L1 (kernel-primitives), then apply `@_disfavoredOverload`
  per Read/Write; or (b) restructure swift-posix's Socket surface to wrap
  iso-9945 types behind swift-posix types. Option (a) is smaller.
- **Flush family**: already disambiguated via Phase-A rename
  (`639a428` et al.). Nothing to do.
- **Windows-side Read/Write**: no ambiguity — `Windows.Kernel.IO.{Read,Write}`
  surfaces through the windows-standard namespace alias; no peer L3
  policy wrapper exists, matching the "L3 platform tier empty" exception.

### Platform-compliance follow-up (flagged, not fixed)

`swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.File.Flush+Data.Darwin.swift`
is a [PLAT-ARCH-002] violation. swift-posix is the POSIX-specification L3
policy tier shared by Darwin and Linux; Darwin-only fcntl operations
(`F_BARRIERFSYNC`, `F_FULLFSYNC` — invoked under `#if canImport(Darwin)`
at the top of the file) are platform-specific behavior that belongs in
`swift-darwin` (L3, adds EINTR-retry policy over the Darwin-specific L2
spec wrapper). Applying the [PLAT-ARCH-008d] syscall-vs-policy test: the
file DOES add policy (EINTR retry), and the policy is specific to one
platform (Darwin), so the correct home is the Darwin L3 tier, not the
POSIX L3 tier. The same logic applies to any future Linux-specific retry
wrappers; those would belong in `swift-linux`, not swift-posix. A Linux
sibling (`POSIX.Kernel.File.Flush+Data.Linux.swift`?) if it ever appears
has the same issue. Should be tracked in a separate compliance handoff.

### Resolution status in audit.md

`swift-kernel/Audits/audit.md` Findings #5–9 correctly remain **RESOLVED**
(the L3 unifiers landed at 24cf586 / 5b0ae3b). The resolution text does
not need overwriting — the unifier IS the intended end state. The
follow-on `@_disfavoredOverload` change here is a corrective measure that
restores the unifier's advertised behavior at Swift's overload resolution
level; it does not change Finding #5–9's outcome. If the audit text is
updated at all, append a terse one-liner per row along the lines of:

> 2026-04-20 follow-on: ambiguity-with-L2 fixed by `@_disfavoredOverload`
> on iso-9945 Read/Write declarations. Unifier now wins overload resolution
> cleanly.

I did not touch the audit table in this session — leaving that to the
committing session once SHAs exist.

### Commit status

Work is staged in the working tree, **not yet committed**. Per-phase
commits from the handoff's recipe do not map 1:1 onto the revised approach,
so the suggested commit layout is:

1. `swift-iso-9945`: `@_disfavoredOverload` on Read/Write L2 methods.
2. `swift-iso-9945`: duplicate `@Test` rename in `Kernel.Thread.Handle Tests`.
3. `swift-file-system`: typed-path migration in Write.Atomic{, .Error},
   Write.Streaming{, .Error} tests; duplicate `@Test` rename in `Stat Tests`;
   obsolete `path:` arg removed from `Streaming.Error.writeFailed` sites.

swift-kernel and swift-posix have **zero** source-tree changes in this
session (aside from the reverted import-demotion attempt, which was rolled
back to the pre-session state before committing any edits).

### Reflection reinforcement (for corpus triage)

Addendum §6's proposed rule holds: "any [PLAT-ARCH-008e] remediation where
the spec-literal name equals the intent-level name requires a Phase-A-style
disambiguation before the L3 unifier lands, not after." This session
applied `@_disfavoredOverload` as an after-the-fact disambiguator; a
Phase-A-like rename would have been prettier but there is no spec-literal
alternative to `read` / `write` / `pread` / `pwrite` (POSIX calls them
exactly that). The fallback-disambiguator is the correct terminal
answer for this family and any future family where L2 spec name equals
L3 intent name unavoidably. Candidate reflection: capture the
import-demotion-vs-disfavoredOverload decision as a rule:
*`internal import` cannot coexist with `@inlinable` bodies that reference
the module's public API; prefer `@_disfavoredOverload` on L2 when the L3
tier is `@inlinable`.*
