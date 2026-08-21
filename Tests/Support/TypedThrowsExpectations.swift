import Testing

public func expectThrows<E: Swift.Error, R>(
    _ validate: (E) -> Void,
    _ body: () throws(E) -> R
) {
    do {
        _ = try body()
        Issue.record("Expected error to be thrown")
    } catch {
        validate(error)
    }
}
