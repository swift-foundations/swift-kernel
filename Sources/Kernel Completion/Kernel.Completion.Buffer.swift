//
//  Kernel.Completion.Buffer.swift
//  swift-kernel-primitives
//
//  Namespace for completion-layer buffer types.
//

extension Kernel.Completion {
    /// Buffer management types for completion-based I/O.
    ///
    /// Provided buffer groups allow the kernel to select a buffer
    /// at completion time, eliminating pre-allocated per-operation
    /// buffers. Used with multishot recv for zero-allocation reads.
    public enum Buffer {}
}
