#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    public import POSIX_Kernel_Descriptor
#endif

extension Kernel.Completion {

    public struct Driver: ~Copyable {

        package let _submit:
            (
                Kernel.Completion.Submission,
                borrowing Kernel.Descriptor
            ) throws(Kernel.Completion.Error) -> Void

        package let _flush: () throws(Kernel.Completion.Error) -> Submission.Count

        package let _drain:
            (
                (Kernel.Completion.Event) -> Void
            ) -> Event.Count

        package let _close: () -> Void

        package let _overflowCount: () -> Event.Count

        public init(
            submit:
                @escaping (Kernel.Completion.Submission, borrowing Kernel.Descriptor) throws(Kernel
                .Completion.Error) -> Void,
            flush: @escaping () throws(Kernel.Completion.Error) -> Submission.Count,
            drain: @escaping ((Kernel.Completion.Event) -> Void) -> Event.Count,
            close: @escaping () -> Void,
            overflowCount: @escaping () -> Event.Count = { .zero }
        ) {
            self._submit = submit
            self._flush = flush
            self._drain = drain
            self._close = close
            self._overflowCount = overflowCount
        }
    }
}
