//
//  Kernel.Completion.Submission.Address.swift
//  swift-kernel
//
//  Typed buffer memory address for submission operations.
//

extension Kernel.Completion.Submission {
    /// Buffer memory address for read/write/send/recv operations.
    ///
    /// Wraps the raw pointer value as a typed 64-bit address.
    /// The driver backend writes this to the platform SQE's
    /// addr/buffer field.
    ///
    /// This is the unsafe boundary — the primary consumer API
    /// (IO.Reader/IO.Writer) is Span-based and safe. Address
    /// exists for the kernel boundary layer.
    public struct Address: Sendable, Equatable, Hashable {
        @_spi(Syscall) public let _rawValue: UInt64

        @_spi(Syscall)
        public init(_rawValue: UInt64) {
            self._rawValue = _rawValue
        }

        /// Create an address from a raw pointer.
        @unsafe
        public init(_ pointer: UnsafeRawPointer) {
            self._rawValue = UInt64(UInt(bitPattern: pointer))
        }

        /// No buffer address (for operations that don't use a buffer).
        public static let none = Address(_rawValue: 0)
    }
}
