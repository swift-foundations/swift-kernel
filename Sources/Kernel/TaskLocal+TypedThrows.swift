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

extension TaskLocal {
    /// Typed throws wrapper for `TaskLocal.withValue`.
    ///
    /// The stdlib `TaskLocal.withValue` uses `rethrows`, which erases typed error
    /// information. This overload preserves the concrete error type `E` via a
    /// `Result` bridge.
    @inlinable
    public func withValue<R, E: Swift.Error>(
        _ valueDuringOperation: Value,
        operation: () throws(E) -> R
    ) throws(E) -> R {
        let result: Result<R, E> = self.withValue(valueDuringOperation) {
            do throws(E) {
                return .success(try operation())
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }

    /// Typed throws wrapper for `TaskLocal.withValue` (async).
    ///
    /// The stdlib `TaskLocal.withValue` uses `rethrows`, which erases typed error
    /// information. This overload preserves the concrete error type `E` via a
    /// `Result` bridge.
    @inlinable
    public func withValue<R: Sendable, E: Swift.Error>(
        _ valueDuringOperation: Value,
        operation: () async throws(E) -> R
    ) async throws(E) -> R {
        let result: Result<R, E> = await self.withValue(valueDuringOperation) {
            do throws(E) {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }
}
