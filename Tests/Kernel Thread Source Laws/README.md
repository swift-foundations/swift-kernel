# Kernel.Thread.run source laws

These fixtures record the compile-time laws of structured borrowed thread
execution. They are intentionally outside every SwiftPM target and are not
executed or typechecked by the package. Each `negative-*.swift.fixture` file is
expected to be rejected by Swift for the reason stated in its leading comment.
The positive fixtures record move-only input/output and transfer of a
non-Sendable operation-capture region without an `@Sendable` requirement.

The fixtures remain source-only until the repository's compiler-probe
moratorium is lifted and a dedicated diagnostic harness owns their execution.
