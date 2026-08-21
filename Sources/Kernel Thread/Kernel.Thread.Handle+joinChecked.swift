extension Kernel.Thread.Handle {

    @inlinable
    public consuming func joinChecked() throws(Kernel.Thread.Error) {
        precondition(
            isCurrent == false,
            "Kernel.Thread.Handle.joinChecked() called from the thread being joined - this would deadlock"
        )
        try join()
    }
}
