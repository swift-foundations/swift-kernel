//
//  Kernel.Completion.Event.Flags.swift
//  swift-kernel
//
//  Typed completion event flags.
//
//  Opaque at the platform-agnostic layer. Platform packages
//  (swift-linux, swift-windows) add semantic extensions
//  (e.g., hasMore, bufferID for io_uring multishot).
//

extension Kernel.Completion.Event {
    /// Platform-specific completion flags.
    ///
    /// Opaque at this layer. Platform packages add semantic
    /// accessors (e.g., `hasMore` for io_uring multishot,
    /// `bufferID` for provided buffer selection).
    public struct Flags: Sendable, Equatable, Hashable {
        @_spi(Syscall) public let _rawValue: UInt32

        @_spi(Syscall)
        public init(_rawValue: UInt32) {
            self._rawValue = _rawValue
        }

        /// No flags.
        public static let none = Flags(_rawValue: 0)
    }
}
