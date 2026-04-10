//
//  Kernel.Completion.Event.Result.swift
//  swift-kernel
//
//  Typed operation result from a completion event.
//

extension Kernel.Completion.Event {
    /// Result of a completed operation.
    ///
    /// Positive values indicate success (typically bytes transferred).
    /// Negative values indicate failure (negated errno on POSIX).
    /// Zero indicates success with no data (e.g., close, nop).
    ///
    /// The specific interpretation depends on the operation:
    /// - read/write/send/recv: bytes transferred (positive) or error (negative)
    /// - accept: new file descriptor (positive) or error (negative)
    /// - nop/close: 0 on success, negative errno on failure
    ///
    /// Error code extraction is platform-specific. The IO layer
    /// creates ``Kernel/Error/Code`` from the raw value based on
    /// the platform's error reporting convention.
    public struct Result: Sendable, Equatable, Hashable {
        package let rawValue: Int32

        package init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Whether the operation completed successfully (result >= 0).
        public var isSuccess: Bool { rawValue >= 0 }

        /// The result value if the operation succeeded, or nil on failure.
        ///
        /// For read/write/send/recv: bytes transferred.
        /// For accept: raw file descriptor value (use the IO layer
        /// to create a typed ``Kernel/Descriptor``).
        /// For nop/close: 0.
        public var value: Int32? {
            isSuccess ? rawValue : nil
        }
    }
}
