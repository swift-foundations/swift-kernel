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
    /// The input is borrowed for the dynamic extent of this call. The
    /// operation and its capture region are transferred into the created
    /// thread and consumed there exactly once. This function does not return
    /// until that thread has been physically joined, so the input borrow has
    /// ended and the operation has been destroyed when the caller resumes.
    ///
    /// The output is transferred back to the caller without requiring it to
    /// be copyable. An operation failure retains its exact error type.
    ///
    /// ## Safety Invariant
    ///
    /// Swift requires the operating-system entry closure to escape even when
    /// its handle is joined immediately. `withoutActuallyEscaping` bridges that
    /// representational mismatch. The operation is `sending`, not `@Sendable`:
    /// its entire disconnected capture region is moved with the input pointer
    /// and result endpoint through `spawn`'s consuming-transfer overload. The
    /// actual escaping entry closure is captureless and therefore `@Sendable`.
    /// This function creates exactly one thread, invokes the transferred
    /// operation exactly once, joins the handle before leaving either scoped
    /// closure, and performs no access to the input pointer or operation after
    /// the join. `withUnsafePointer` keeps the input address valid for that
    /// entire interval.
    ///
    /// `Input` remains `Sendable` because a borrow does not disconnect the
    /// value's region or invalidate aliases outside the caller. Physical join
    /// bounds this API's access lifetime, but cannot prove that an unrelated
    /// alias is not accessed concurrently. Replacing `Sendable` would require
    /// consuming the input's region, which would break this API's promise that
    /// the caller may use or consume the input after `run` returns.
    ///
    /// A creation failure starts no thread. A join failure is surfaced only for
    /// a handle freshly returned by `spawn`; joining self and detachment are
    /// impossible within this API.
    ///
    /// - Parameters:
    ///   - input: The value borrowed by the thread operation.
    ///   - operation: Nonescaping work transferred to the dedicated thread.
    /// - Returns: The operation's sending result after physical join.
    /// - Throws: ``Kernel/Thread/Run/Error`` identifying creation, join, or
    ///   operation failure without erasing the operation's error type.
    public static func run<
        Input: ~Copyable & ~Escapable & Sendable,
        Output: ~Copyable,
        Failure: Swift.Error
    >(
        _ input: borrowing Input,
        _ operation: sending (borrowing Input) throws(Failure) -> sending Output
    ) throws(Kernel.Thread.Run.Error<Failure>) -> sending Output {
        let incoming = Ownership.Transfer.Value<Swift.Result<Output, Failure>>.Incoming()
        let token = incoming.token

        try withoutActuallyEscaping(operation) {
            operation throws(Kernel.Thread.Run.Error<Failure>) in
            try withUnsafePointer(to: input) { input throws(Kernel.Thread.Run.Error<Failure>) in
                let handle: Kernel.Thread.Handle

                do throws(Kernel.Thread.Error) {
                    let context = (input, operation, token)
                    handle = try Kernel.Thread.spawn(context) { context in
                        let (input, operation, token) = consume context
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
