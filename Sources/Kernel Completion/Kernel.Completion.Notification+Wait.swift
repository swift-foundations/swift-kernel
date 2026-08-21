#if !os(Windows)

    import POSIX_Kernel_File

    extension Kernel.Completion.Notification {

        public borrowing func wait() {
            var counter: UInt64 = 0
            while true {
                let result = withUnsafeMutableBytes(of: &counter) { buf -> Bool in
                    do throws(Kernel.IO.Read.Error) {
                        _ = try unsafe Kernel.IO.Read.read(descriptor, into: buf)
                        return true
                    } catch {
                        return false
                    }
                }
                if result { return }

                Kernel.Thread.yield()
            }
        }
    }

#endif
