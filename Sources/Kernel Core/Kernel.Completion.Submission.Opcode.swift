//
//  Kernel.Completion.Submission.Opcode.swift
//  swift-kernel
//
//  Platform-agnostic operation opcodes.
//
//  The driver backend maps these to platform-specific opcodes
//  (io_uring IORING_OP_*, IOCP function calls).
//

extension Kernel.Completion.Submission {
    /// Platform-agnostic operation type.
    ///
    /// Raw values are our abstraction — NOT io_uring opcode numbers.
    /// The backend driver maps these to the correct platform opcode.
    public struct Opcode: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        /// No-op — useful for testing and wakeup.
        public static let nop      = Self(rawValue: 0)
        /// Positioned read into buffer.
        public static let read     = Self(rawValue: 1)
        /// Positioned write from buffer.
        public static let write    = Self(rawValue: 2)
        /// Close a file descriptor.
        public static let close    = Self(rawValue: 3)
        /// Accept a connection.
        public static let accept   = Self(rawValue: 4)
        /// Initiate a connection.
        public static let connect  = Self(rawValue: 5)
        /// Send data on a socket.
        public static let send     = Self(rawValue: 6)
        /// Receive data from a socket.
        public static let recv     = Self(rawValue: 7)
        /// Cancel a pending operation (by userData).
        public static let cancel   = Self(rawValue: 8)
        /// Sync file data to storage.
        public static let fsync    = Self(rawValue: 9)
    }
}
