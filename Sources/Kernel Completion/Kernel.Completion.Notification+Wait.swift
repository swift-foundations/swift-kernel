//
//  Kernel.Completion.Notification+Wait.swift
//  swift-kernel
//
//  Blocking wait for completion notifications.
//

// Windows has no counterpart: the completion mechanism IS the notification
// there (IOCP blocks in GetQueuedCompletionStatus), so a descriptor-read
// wait never exists. POSIX_Kernel_File is also absent from the Windows
// dependency graph.
#if !os(Windows)

    import POSIX_Kernel_File

    // MARK: - Blocking Wait

    extension Kernel.Completion.Notification {
        /// Blocks until the kernel signals available completions.
        ///
        /// Reads the notification eventfd counter (8-byte blocking read).
        /// Returns when at least one completion event is available for
        /// draining via ``Kernel/Completion/drain(_:)``.
        ///
        /// Retries on EAGAIN and EINTR. Per
        /// feedback_prefer_typed_throws_over_try_optional: never `try?` on
        /// this path — swallowing EAGAIN caused a hot-spin on Linux where
        /// the executor looped at 100% CPU without blocking.
        public borrowing func wait() {
            var counter: UInt64 = 0
            while true {
                let result = unsafe withUnsafeMutableBytes(of: &counter) { buf -> Bool in
                    do throws(Kernel.IO.Read.Error) {
                        _ = try unsafe Kernel.IO.Read.read(descriptor, into: buf)
                        return true  // success — counter consumed
                    } catch {
                        return false  // failed — retry
                    }
                }
                if result { return }
                // EAGAIN / EINTR / other transient — retry.
                // On a blocking eventfd, only EINTR is expected here.
                // On a non-blocking eventfd (shouldn't happen but has
                // historically caused the hot-spin), EAGAIN is retried
                // which busy-waits — still better than silently returning
                // and spinning the entire proactor loop.
                Kernel.Thread.yield()
            }
        }
    }

#endif
