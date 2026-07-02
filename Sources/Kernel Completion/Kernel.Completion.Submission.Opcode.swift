
//
//  Kernel.Completion.Submission.Opcode.swift
//  swift-kernel-primitives
//
//  Platform-agnostic operation opcodes carrying per-variant data
//  as associated values so fields are unrepresentable for the wrong
//  opcode.
//


public import Memory_Primitives
#if os(Windows)
// Per-file member visibility for `Kernel.File.Offset`: the `File` alias on
// `Windows.Kernel` is declared in the L3 Windows_Kernel_File module, which
// this target's exports (Kernel_Core) do not re-export.
public import Windows_Kernel_File
#endif

extension Kernel.Completion.Submission {
    /// Platform-agnostic operation descriptor.
    ///
    /// Each variant carries exactly the data the backend needs to fill
    /// the platform submission entry. Fields that don't apply to an
    /// opcode cannot be set — the type system prevents the defect class
    /// where a cancel SQE silently received a buffer offset as its
    /// target.
    ///
    /// ## Stream Mode
    ///
    /// For `read` and `write`, `offset: nil` signals stream mode
    /// (read/write at the file's current position). The backend
    /// translates `nil` to the platform sentinel (`UInt64.max` for
    /// io_uring) at the SQE fill boundary.
    public enum Opcode: Sendable, Equatable, Hashable {
        /// Empty operation that round-trips through the kernel —
        /// used for testing and for forcing a completion to wake a
        /// consumer waiting on the queue.
        case noOperation

        /// Read bytes into a buffer. `offset: nil` means stream mode.
        case read(
            address: Memory.Address,
            length: Memory.Address.Count,
            offset: Kernel.File.Offset?
        )

        /// Write bytes from a buffer. `offset: nil` means stream mode.
        case write(
            address: Memory.Address,
            length: Memory.Address.Count,
            offset: Kernel.File.Offset?
        )

        /// Close the target descriptor.
        case close

        /// Accept an incoming connection on the target listening socket.
        case accept

        /// Initiate a connection to `address` (a `sockaddr_*` pointer).
        case connect(
            address: Memory.Address,
            length: Memory.Address.Count
        )

        /// Send bytes on a socket.
        case send(
            address: Memory.Address,
            length: Memory.Address.Count
        )

        /// Receive bytes from a socket.
        case receive(
            address: Memory.Address,
            length: Memory.Address.Count
        )

        /// Cancel a pending operation by correlation token.
        case cancel(target: Kernel.Completion.Token)

        /// Synchronize file contents to persistent storage.
        ///
        /// Platform-neutral: backed by `fsync(2)` / `IORING_OP_FSYNC` on
        /// POSIX, `FlushFileBuffers` on Windows. The opcode name
        /// describes the domain operation ("synchronize"), not a
        /// specific platform syscall.
        case synchronize

        #if !os(Windows)
        /// Register single-shot readiness interest on the target descriptor.
        ///
        /// Backed by `IORING_OP_POLL_ADD` on Linux. The opcode name
        /// describes the domain operation ("readiness"), not a specific
        /// platform syscall.
        ///
        /// Absent on Windows: the payload is `Kernel.Event.Interest` —
        /// epoll/kqueue vocabulary whose target does not exist there —
        /// and the only producer (IO Events) is likewise POSIX-gated.
        /// The IOCP path will express readiness through the completion
        /// port itself.
        case readiness(events: Kernel.Event.Interest)
        #endif
    }
}
