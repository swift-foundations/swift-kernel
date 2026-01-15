// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Swift.String Convenience APIs

extension Kernel.Environment {
    /// Gets an environment variable.
    ///
    /// - Parameter name: The variable name.
    /// - Returns: The value as a Swift String, or nil if not set.
    @inlinable
    public static func get(_ name: Swift.String) -> Swift.String? {
        name.withKernelString { namePtr in
            guard let owned = get(namePtr) else {
                return nil
            }
            return Swift.String(owned)
        }
    }

    /// Sets an environment variable.
    ///
    /// - Parameters:
    ///   - name: The variable name.
    ///   - value: The value to set.
    ///   - overwrite: If true, overwrite existing value.
    /// - Throws: `Kernel.Environment.Error` on failure.
    @inlinable
    public static func set(
        _ name: Swift.String,
        to value: Swift.String,
        overwrite: Bool = true
    ) throws(Kernel.Environment.Error) {
        try name.withKernelString { (namePtr) throws(Kernel.Environment.Error) in
            try value.withKernelString { (valuePtr) throws(Kernel.Environment.Error) in
                try set(namePtr, to: valuePtr, overwrite: overwrite)
            }
        }
    }

    /// Unsets an environment variable.
    ///
    /// - Parameter name: The variable name.
    /// - Throws: `Kernel.Environment.Error` on failure.
    @inlinable
    public static func unset(_ name: Swift.String) throws(Kernel.Environment.Error) {
        try name.withKernelString { (namePtr) throws(Kernel.Environment.Error) in
            try unset(namePtr)
        }
    }
}

// MARK: - Convenience Query APIs

extension Kernel.Environment {
    /// Checks if an environment variable is set to a specific value.
    ///
    /// - Parameters:
    ///   - name: The name of the environment variable.
    ///   - value: The value to compare against.
    /// - Returns: `true` if the variable equals the value, `false` otherwise.
    @inlinable
    public static func isSet(_ name: Swift.String, to value: Swift.String) -> Bool {
        get(name) == value
    }

    /// Checks if an environment variable is set (regardless of value).
    ///
    /// - Parameter name: The name of the environment variable.
    /// - Returns: `true` if set, `false` if not set.
    @inlinable
    public static func isSet(_ name: Swift.String) -> Bool {
        get(name) != nil
    }
}
