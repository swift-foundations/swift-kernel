//
//  Kernel.Completion.Event.Result+Failure.swift
//  swift-kernel
//
//  Bridge from a raw kernel completion result to a typed Error_Primitives.Error.
//  The raw value's encoding convention is set by the platform factory's
//  drain implementation (e.g., Kernel.Completion+IOUring.swift encodes
//  POSIX failures as negated errno). This property undoes the convention
//  to produce a typed error.
//

extension Kernel.Completion.Event.Result {
    /// The failure error, or `nil` if the result is a success.
    ///
    /// Constructs a ``Kernel/Error`` from the platform-encoded raw
    /// value. On POSIX platforms (Linux, Darwin) the raw value for
    /// failures is a negated errno; this property negates it back to
    /// recover the original code.
    ///
    /// ```swift
    /// if let error = event.result.failure {
    ///     // handle Error_Primitives.Error
    /// }
    /// let value = event.result.value!  // success path
    /// ```
    public var failure: Error_Primitives.Error? {
        guard !isSuccess else { return nil }
        return Error_Primitives.Error(code: .posix(-rawValue))
    }
}
