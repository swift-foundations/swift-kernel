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

extension Kernel.Library {
    /// Dynamic library loading operations.
    ///
    /// Raw wrappers for dlopen, dlsym, dlclose (POSIX)
    /// and LoadLibraryW, GetProcAddress, FreeLibrary (Windows).
    ///
    /// ## Thread Safety
    ///
    /// - `open` is thread-safe (OS provides synchronization)
    /// - `close` is NOT thread-safe with concurrent `symbol` lookups on the same handle
    /// - Caller MUST externally synchronize `close` vs in-flight `symbol` calls
    /// - Symbol pointers are **invalid** after `close(handle)` — caller must ensure
    ///   no references remain
    ///
    /// ## Symbol Pointer Lifetime
    ///
    /// - Returned `UnsafeRawPointer` is valid only while the library remains loaded
    /// - Caller is responsible for correct casting and calling convention
    /// - `UnsafeRawPointer` is NOT a function pointer; cast must respect platform ABI
    public enum Dynamic {}
}

// MARK: - POSIX Implementation

#if !os(Windows)

    #if canImport(Darwin)
        public import Darwin
    #elseif canImport(Glibc)
        public import Glibc
    #elseif canImport(Musl)
        public import Musl
    #endif

    extension Kernel.Library.Dynamic {
        /// Opens a dynamic library.
        ///
        /// - Parameters:
        ///   - path: Path to the library, or `nil` for the main executable.
        ///   - options: Loading options. Default: `.now` (fail-early).
        /// - Returns: Handle to the loaded library.
        /// - Throws: `Error.open` with dlerror message.
        ///
        /// ## Examples
        ///
        /// ```swift
        /// // Load a specific library
        /// let handle = try "/usr/lib/libfoo.dylib".withCString { path in
        ///     try Kernel.Library.Dynamic.open(path: path, options: .now)
        /// }
        ///
        /// // Open main executable for symbol lookup
        /// // Note: The returned handle is primarily for dlsym; closing it is
        /// // platform-dependent and not recommended for portable code.
        /// let main = try Kernel.Library.Dynamic.open(path: nil, options: .now)
        /// ```
        @inlinable
        public static func open(
            path: UnsafePointer<CChar>?,
            options: Options = .now
        ) throws(Error) -> Handle {
            // Clear stale error (I1.1)
            _ = dlerror()

            guard let handle = dlopen(path, options.rawValue) else {
                // Capture immediately (I1.2)
                throw .open(captureError())
            }
            return Handle(rawValue: handle)
        }

        /// Closes a dynamic library.
        ///
        /// - Parameter handle: The library handle to close.
        /// - Throws: `Error.close` on failure.
        ///
        /// - Warning: Closing invalidates all symbol pointers from this library.
        ///   Caller must externally synchronize with any in-flight symbol usage.
        @inlinable
        public static func close(_ handle: Handle) throws(Error) {
            // Clear stale error (I1.1)
            _ = dlerror()

            guard dlclose(handle.rawValue) == 0 else {
                // Capture immediately (I1.2)
                throw .close(captureError())
            }
        }

        /// Looks up a symbol in a library or scope.
        ///
        /// - Parameters:
        ///   - name: The symbol name (C string).
        ///   - scope: Where to search — a loaded `Handle` or special scope.
        /// - Returns: Pointer to the symbol.
        /// - Throws: `Error.symbol` if not found.
        ///
        /// - Warning: The returned pointer is only valid while the library
        ///   remains loaded. Caller must ensure handle is not closed.
        ///   Caller is responsible for correct casting and calling convention.
        ///
        /// - Note: If a symbol legitimately resolves to NULL (no dlerror),
        ///   this is treated as failure due to the non-optional return type.
        ///   This is a documented limitation (I4.2).
        ///
        /// ## Examples
        ///
        /// ```swift
        /// // Look up in default scope (any loaded library)
        /// let mallocPtr = try "malloc".withCString { name in
        ///     try Kernel.Library.Dynamic.symbol(name: name, in: .default)
        /// }
        ///
        /// // Look up in a specific library
        /// let funcPtr = try "my_function".withCString { name in
        ///     try Kernel.Library.Dynamic.symbol(name: name, in: .handle(libHandle))
        /// }
        /// ```
        @inlinable
        public static func symbol(
            name: UnsafePointer<CChar>,
            in scope: Scope
        ) throws(Error) -> UnsafeRawPointer {
            // Clear stale error (I1.1, I4.1)
            _ = dlerror()

            let sym = dlsym(scope.dlsymHandle, name)

            // Check for error (sym can legitimately be NULL for data symbols)
            if let errorCStr = dlerror() {
                throw .symbol(Message(String(cString: errorCStr)))
            }

            guard let sym else {
                // NULL with no dlerror — documented limitation (I4.2)
                throw .symbol(Message("symbol resolved to NULL (no dlerror)"))
            }

            return UnsafeRawPointer(sym)
        }
    }

    // MARK: - POSIX Error Capture

    extension Kernel.Library.Dynamic {
        /// Captures dlerror() into an owned message.
        ///
        /// MUST be called immediately after a failing syscall (I1.2).
        /// Creates owned Swift String from thread-local error buffer (I1.3).
        @usableFromInline
        internal static func captureError() -> Message {
            if let cstr = dlerror() {
                return Message(String(cString: cstr))
            }
            return Message("unknown error")
        }
    }

#endif

// MARK: - Windows Implementation

#if os(Windows)

    public import WinSDK

    extension Kernel.Library.Dynamic {
        /// Opens a dynamic library (Windows).
        ///
        /// - Parameter path: Path to the DLL (UTF-16, null-terminated).
        /// - Returns: Handle to the loaded library.
        /// - Throws: `Error.open` with formatted error message.
        ///
        /// ## Examples
        ///
        /// ```swift
        /// let handle = try "kernel32.dll".withCString(encodedAs: UTF16.self) { path in
        ///     try Kernel.Library.Dynamic.open(path: path)
        /// }
        /// ```
        public static func open(
            path: UnsafePointer<UInt16>
        ) throws(Error) -> Handle {
            guard let handle = LoadLibraryW(path) else {
                throw .open(captureLastError())
            }
            return Handle(rawValue: handle)
        }

        /// Closes a dynamic library (Windows).
        ///
        /// - Parameter handle: The library handle to close.
        /// - Throws: `Error.close` on failure.
        public static func close(_ handle: Handle) throws(Error) {
            guard FreeLibrary(handle.rawValue) else {
                throw .close(captureLastError())
            }
        }

        /// Looks up a symbol in a library (Windows).
        ///
        /// - Parameters:
        ///   - name: The symbol name (ANSI string, NOT UTF-16).
        ///   - handle: The library handle.
        /// - Returns: Pointer to the symbol.
        /// - Throws: `Error.symbol` if not found.
        ///
        /// - Note: Windows symbol names are ANSI, not UTF-16.
        /// - Warning: Caller is responsible for correct casting and calling convention.
        ///
        /// ## Examples
        ///
        /// ```swift
        /// let procPtr = try "GetCurrentProcessId".withCString { name in
        ///     try Kernel.Library.Dynamic.symbol(name: name, in: kernel32Handle)
        /// }
        /// ```
        public static func symbol(
            name: UnsafePointer<CChar>,
            in handle: Handle
        ) throws(Error) -> UnsafeRawPointer {
            guard let proc = GetProcAddress(handle.rawValue, name) else {
                throw .symbol(captureLastError())
            }
            return unsafeBitCast(proc, to: UnsafeRawPointer.self)
        }
    }

    // MARK: - Windows Error Capture

    extension Kernel.Library.Dynamic {
        /// Captures GetLastError + FormatMessage into owned message.
        ///
        /// MUST be called immediately after a failing syscall (I1.5).
        /// Always captures the error code; message formatting is best-effort.
        @usableFromInline
        internal static func captureLastError() -> Message {
            let code = Kernel.Error.Code.captureLastError()
            if let text = Kernel.Error.message(for: code) {
                return Message(text, code: code)
            }
            // Numeric fallback (N4) — always deterministic
            return Message("Windows error \(code.win32!)", code: code)
        }
    }

#endif
