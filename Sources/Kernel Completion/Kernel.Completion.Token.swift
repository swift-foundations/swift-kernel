//
//  Kernel.Completion.Token.swift
//  swift-kernel
//
//  Opaque correlation identifier for matching submissions
//  to their completions.
//

extension Kernel.Completion {
    /// Opaque correlation identifier for matching submissions to completions.
    ///
    /// The consumer assigns a token to each submission. The kernel returns
    /// the same token in the completion event. The consumer uses it to
    /// correlate the event with the original operation (e.g., resume a
    /// continuation, update a slab entry).
    ///
    /// Token values are opaque — the kernel does not interpret them.
    /// Typically a slab index, pointer, or sequential counter.
    public typealias Token = Tagged<Kernel.Completion, UInt64>
}

extension Kernel.Completion.Token {
    /// Create a token from a correlation identifier.
    public init(_ identifier: UInt64) {
        self = Self(__unchecked: (), identifier)
    }

    /// The zero token.
    public static let zero = Self(__unchecked: (), 0)
}
