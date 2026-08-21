extension Kernel.Completion.Event.Result {

    public var failure: Error_Primitives.Error? {
        guard !isSuccess else { return nil }
        return Error_Primitives.Error(code: .posix(-rawValue))
    }
}
