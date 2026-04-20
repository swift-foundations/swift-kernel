// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)

public import Kernel_Socket_Primitives

// MARK: - Cross-platform Connect surface on POSIX
//
// The typed address types (`Kernel.Socket.Address.IPv4`, `IPv6`, `Unix`,
// `Storage`) and the `Kernel.Socket.Connect` namespace are declared in
// swift-iso-9945 (L2 POSIX). No equivalent surface exists on Windows today,
// so the cross-platform `Kernel.Socket.Connect.connect(_:, address:)` API is
// POSIX-scoped. Windows consumers use `Windows.Kernel.Socket.connect(...)`
// directly via the `UnsafePointer<sockaddr>` Winsock API.

extension Kernel.Socket.Connect {
    /// Connects a socket to a peer, awaiting completion if interrupted.
    ///
    /// Delegates to ``POSIX/Kernel/Socket/Connect/connect(_:address:length:)``
    /// in swift-posix (L3 policy). On `EINTR`, the policy wrapper does NOT
    /// retry `connect(2)` — the TCP handshake continues asynchronously in the
    /// kernel, so retrying would either race with an in-flight completion or
    /// throw `EALREADY` / `EISCONN`. Instead, the policy wrapper awaits
    /// completion via `poll(POLLOUT)` + `getsockopt(SO_ERROR)` and surfaces
    /// the final connection result.
    ///
    /// Raw access without EINTR completion-await is available via
    /// ``ISO_9945/Kernel/Socket/Connect/connect(_:address:length:)``.
    ///
    /// Non-blocking connect (socket in O_NONBLOCK mode returning `EINPROGRESS`)
    /// is out of scope for this wrapper — consumers managing non-blocking
    /// sockets should use the raw connect and drive completion themselves.
    ///
    /// - Parameters:
    ///   - descriptor: The socket descriptor.
    ///   - address: The peer address, as a `Storage` container.
    ///   - length: The size of the actual address within storage.
    /// - Throws: ``Kernel/Socket/Error`` on failure (excluding EINTR).
    @inlinable
    public static func connect(
        _ descriptor: borrowing Kernel.Socket.Descriptor,
        address: Kernel.Socket.Address.Storage,
        length: UInt32
    ) throws(Kernel.Socket.Error) {
        try POSIX.Kernel.Socket.Connect.connect(descriptor, address: address, length: length)
    }

    /// Connects a socket to an IPv4 peer, awaiting completion if interrupted.
    ///
    /// See ``connect(_:address:length:)`` for the completion-await semantic.
    ///
    /// - Parameters:
    ///   - descriptor: The socket descriptor.
    ///   - address: The IPv4 peer address.
    /// - Throws: ``Kernel/Socket/Error`` on failure (excluding EINTR).
    @inlinable
    public static func connect(
        _ descriptor: borrowing Kernel.Socket.Descriptor,
        address: Kernel.Socket.Address.IPv4
    ) throws(Kernel.Socket.Error) {
        try POSIX.Kernel.Socket.Connect.connect(descriptor, address: address)
    }

    /// Connects a socket to an IPv6 peer, awaiting completion if interrupted.
    ///
    /// See ``connect(_:address:length:)`` for the completion-await semantic.
    ///
    /// - Parameters:
    ///   - descriptor: The socket descriptor.
    ///   - address: The IPv6 peer address.
    /// - Throws: ``Kernel/Socket/Error`` on failure (excluding EINTR).
    @inlinable
    public static func connect(
        _ descriptor: borrowing Kernel.Socket.Descriptor,
        address: Kernel.Socket.Address.IPv6
    ) throws(Kernel.Socket.Error) {
        try POSIX.Kernel.Socket.Connect.connect(descriptor, address: address)
    }

    /// Connects a socket to a Unix domain peer, awaiting completion if interrupted.
    ///
    /// See ``connect(_:address:length:)`` for the completion-await semantic.
    ///
    /// - Parameters:
    ///   - descriptor: The socket descriptor.
    ///   - address: The Unix domain peer address.
    /// - Throws: ``Kernel/Socket/Error`` on failure (excluding EINTR).
    @inlinable
    public static func connect(
        _ descriptor: borrowing Kernel.Socket.Descriptor,
        address: Kernel.Socket.Address.Unix
    ) throws(Kernel.Socket.Error) {
        try POSIX.Kernel.Socket.Connect.connect(descriptor, address: address)
    }
}

#endif
