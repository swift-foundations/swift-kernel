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

extension Kernel.Thread {
    /// Structured execution on one dedicated operating-system thread.
    ///
    /// `Run` owns the failure vocabulary for structured thread execution.
    public enum Run: Sendable {}
}

extension Kernel.Thread {
    /// Runs an operation on one dedicated operating-system thread and waits
    /// for that thread to finish.
    ///
    /// The input and operation are borrowed for the dynamic extent of this
    /// call. The operation executes exactly once on the created thread. This
    /// function does not return until that thread has been physically joined,
    /// so neither borrow remains accessible when the caller resumes.
    ///
    /// The output is transferred back to the caller without requiring it to
    /// be copyable. An operation failure retains its exact error type.
    ///
    /// ## Safety Invariant
    ///
    /// Swift requires the operating-system entry closure to escape even when
    /// its handle is joined immediately. `withoutActuallyEscaping` bridges that
    /// representational mismatch. The bridge is sound because this function
    /// creates exactly one thread, invokes the operation exactly once, joins
    /// the handle before leaving either scoped closure, and performs no access
    /// to the input pointer or operation after the join. `withUnsafePointer`
    /// keeps the input address valid for that entire interval. A creation
    /// failure starts no thread. A join failure is surfaced only for a handle
    /// freshly returned by `spawn`; joining self and detachment are impossible
    /// within this API.
    ///
    /// - Parameters:
    ///   - input: The value borrowed by the thread operation.
    ///   - operation: Nonescaping work executed on the dedicated thread.
    /// - Returns: The operation's sending result after physical join.
    /// - Throws: ``Kernel/Thread/Run/Error`` identifying creation, join, or
    ///   operation failure without erasing the operation's error type.
    public static func run<
        Input: ~Copyable & ~Escapable & Sendable,
        Output: ~Copyable,
        Failure: Swift.Error
    >(
        _ input: borrowing Input,
        _ operation: @Sendable (borrowing Input) throws(Failure) -> sending Output
    ) throws(Kernel.Thread.Run.Error<Failure>) -> sending Output {
        let incoming = Ownership.Transfer.Value<Swift.Result<Output, Failure>>.Incoming()
        let token = incoming.token

        try withoutActuallyEscaping(operation) { operation throws(Kernel.Thread.Run.Error<Failure>) in
            try withUnsafePointer(to: input) { input throws(Kernel.Thread.Run.Error<Failure>) in
                let handle: Kernel.Thread.Handle

                do throws(Kernel.Thread.Error) {
                    handle = try Kernel.Thread.spawn {
                        do throws(Failure) {
                            let output = try operation(unsafe input.pointee)
                            token.store(.success(output))
                        } catch {
                            token.store(.failure(error))
                        }
                    }
                } catch {
                    throw .creation(error)
                }

                do throws(Kernel.Thread.Error) {
                    try handle.joinChecked()
                } catch {
                    throw .join(error)
                }
            }
        }

        guard let result = incoming.consume() else {
            preconditionFailure("Kernel.Thread.run operation completed without producing a result")
        }

        switch consume result {
        case .success(let output):
            return output
        case .failure(let error):
            throw .operation(error)
        }
    }
}
