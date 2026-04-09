//
//  Kernel.Completion.Submission.Length.swift
//  swift-kernel
//
//  Typed buffer length for submission operations.
//

extension Kernel.Completion.Submission {
    /// Buffer length for read/write/send/recv operations.
    ///
    /// The driver backend writes this to the platform SQE's
    /// len field. Clamped to UInt32 range.
    ///
    /// Shares tag with ``Offset`` (both use `Submission`). Distinct
    /// because UInt32 ≠ UInt64 — structurally determined by io_uring
    /// SQE layout (`len: u32`, `off: u64`).
    public typealias Length = Tagged<Kernel.Completion.Submission, UInt32>
}

extension Kernel.Completion.Submission.Length {
    /// Create a length from a byte count.
    public init(_ count: Int) {
        precondition(count >= 0 && count <= Int(UInt32.max))
        self = Self(__unchecked: (), UInt32(count))
    }

    /// Zero length.
    public static let zero = Self(__unchecked: (), 0)
}
