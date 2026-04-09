//
//  Kernel.Completion.Buffer.Group.swift
//  swift-kernel
//
//  Typed buffer group identifier.
//

extension Kernel.Completion.Buffer {
    /// Identifier for a provided buffer group.
    ///
    /// Buffer groups are registered with the completion ring.
    /// Submissions reference a group to request kernel buffer
    /// selection. The completion event's flags identify which
    /// buffer was selected.
    public typealias Group = Tagged<Kernel.Completion.Buffer, UInt16>
}

extension Kernel.Completion.Buffer.Group {
    /// Create a buffer group from an identifier.
    public init(_ id: UInt16) {
        self = Self(__unchecked: (), id)
    }

    /// No buffer group (not using provided buffers).
    public static let none = Self(__unchecked: (), 0)
}
