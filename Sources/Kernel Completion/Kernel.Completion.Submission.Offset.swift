//
//  Kernel.Completion.Submission.Offset.swift
//  swift-kernel
//
//  Typed file offset for positioned I/O operations.
//

extension Kernel.Completion.Submission {
    /// File offset for positioned read/write operations.
    ///
    /// Zero for the beginning of the file. `.current` signals
    /// "use the file's current position" (maps to UInt64.max
    /// on io_uring, ignored on IOCP).
    ///
    /// Shares tag with ``Length`` (both use `Submission`). Distinct
    /// because UInt64 ≠ UInt32 — structurally determined by io_uring
    /// SQE layout (`off: u64`, `len: u32`).
    public typealias Offset = Tagged<Kernel.Completion.Submission, UInt64>
}

extension Kernel.Completion.Submission.Offset {
    /// Beginning of the file.
    public static let zero = Self(__unchecked: (), 0)

    /// Use the file's current position (stream operations).
    public static let current = Self(__unchecked: (), UInt64.max)
}
