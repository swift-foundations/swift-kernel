//
//  Kernel.Completion.Event.Result+Failure.swift
//  swift-kernel
//
//  Bridge from a raw kernel completion result to a typed Kernel.Error.
//  The raw value's encoding convention is set by the platform factory's
//  drain implementation (e.g., Kernel.Completion+IOUring.swift encodes
//  POSIX failures as negated errno). This property undoes the convention
//  to produce a typed error.
//

@_spi(Syscall) import Kernel_Completion_Primitives

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
    ///     // handle Kernel.Error
    /// }
    /// let value = event.result.value!  // success path
    /// ```
    public var failure: Kernel.Error? {
        guard !isSuccess else { return nil }
        return Kernel.Error(code: .posix(-rawValue))
    }
}
