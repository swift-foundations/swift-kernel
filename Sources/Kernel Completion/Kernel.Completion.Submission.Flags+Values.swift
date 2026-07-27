//
//  Kernel.Completion.Submission.Flags+Values.swift
//  swift-kernel
//
//  Platform-specific submission flag constants.
//
//  The shell (empty OptionSet) lives at L1 in Kernel Completion
//  Primitives. This file adds the io_uring–shaped constants per
//  [PLAT-ARCH-013] shell + values pattern.
//

#if os(Linux)

    extension Kernel.Completion.Submission.Flags {
        /// Select a buffer from the specified buffer group at completion time.
        ///
        /// io_uring: `IOSQE_BUFFER_SELECT`. Requires `bufferGroup` to be set.
        /// Used with multishot recv for kernel-managed buffer pools.
        public static let bufferSelect = Self(rawValue: 1 << 0)

        /// Link this operation to the next submission.
        ///
        /// io_uring: `IOSQE_IO_LINK`. The next submission executes only
        /// after this one completes successfully. Failure cancels the chain.
        public static let linked = Self(rawValue: 1 << 1)

        /// Drain the submission queue before executing this operation.
        ///
        /// io_uring: `IOSQE_IO_DRAIN`. Ensures all prior submissions
        /// complete before this one begins. Serialization barrier.
        public static let drain = Self(rawValue: 1 << 2)

        /// Use a registered (fixed) file descriptor.
        ///
        /// io_uring: `IOSQE_FIXED_FILE`. Required for SQPOLL mode.
        /// The target descriptor must be pre-registered with the ring.
        public static let fixedFile = Self(rawValue: 1 << 3)
    }

#endif
