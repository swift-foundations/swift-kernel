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

import Kernel
import Kernel_Test_Support
import Testing

extension Path.String {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if !os(Windows)

    // MARK: - Error<Body> Property Tests

    extension Path.String.Test.Unit {

        @Test
        func `.body extraction returns body error`() {
            enum TestError: Swift.Error, Equatable { case test }
            let error: Path.String.Error<TestError> = .body(.test)
            #expect(error.body == .test)
            #expect(error.conversion == nil)
        }

        @Test
        func `.conversion extraction returns conversion error`() {
            enum TestError: Swift.Error { case test }
            let error: Path.String.Error<TestError> = .conversion(.interiorNUL(index: 0))
            #expect(error.conversion == .interiorNUL(index: 0))
            #expect(error.body == nil)
        }

        @Test
        func `.mapBody preserves conversion errors`() {
            enum A: Swift.Error { case a }
            enum B: Swift.Error { case b }
            let original: Path.String.Error<A> = .conversion(.interiorNUL(index: 1))
            let mapped = original.mapBody { _ in B.b }
            #expect(mapped.conversion == .interiorNUL(index: 1))
        }

        @Test
        func `.mapBody transforms body errors`() {
            enum A: Swift.Error, Equatable { case a }
            enum B: Swift.Error, Equatable { case b }
            let original: Path.String.Error<A> = .body(.a)
            let mapped = original.mapBody { _ in B.b }
            #expect(mapped.body == .b)
        }
    }

    // MARK: - Single Path (Conversion-Only Overload)

    extension Path.String.Test.Unit {

        @Test
        func `with passes valid string to body`() throws {
            let result = try Path.scope("/tmp/test") { path in
                unsafe path.pointer.pointee
            }
            #expect(result == UInt8(47))  // ASCII '/'
        }

        @Test
        func `with rejects interior NUL at start (conversion-only)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Path.scope("\0/tmp/file") { _ in () } }
            )
        }

        @Test
        func `with rejects interior NUL in middle (conversion-only)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Path.scope("/tmp/\0file") { _ in () } }
            )
        }

        @Test
        func `with rejects interior NUL at end (conversion-only)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Path.scope("/tmp/file\0") { _ in () } }
            )
        }
    }

    // MARK: - Single Path (Throwing-Body Overload / Wrapper Tests)

    extension Path.String.Test.Unit {

        /// Dummy error type to force throwing-body overload selection.
        private enum Dummy: Swift.Error { case sentinel }

        @Test
        func `with wraps conversion errors (throwing-body overload)`() {
            typealias E = Path.String.Error<Dummy>
            expectThrows(
                { (error: E) in
                    #expect(error.conversion == .interiorNUL(index: 0))
                    #expect(error.body == nil)
                },
                { () throws(E) in
                    _ = try Path.scope("\0/tmp/file") { (_: borrowing Path.Borrowed) throws(Dummy) in
                        ()  // never reached
                    }
                }
            )
        }

        @Test
        func `with wraps body errors`() {
            enum Body: Swift.Error, Equatable { case boom }
            typealias E = Path.String.Error<Body>
            expectThrows(
                { (error: E) in
                    #expect(error.body == .boom)
                    #expect(error.conversion == nil)
                },
                { () throws(E) in
                    _ = try Path.scope("/tmp/x") { (_: borrowing Path.Borrowed) throws(Body) in
                        throw .boom
                    }
                }
            )
        }
    }

    // MARK: - Two Paths (Conversion-Only Overload)

    extension Path.String.Test.Unit {

        @Test
        func `with two paths passes valid strings`() throws {
            var saw1 = false
            var saw2 = false
            try Path.scope("/path1", "/path2") { p1, p2 in
                saw1 = unsafe p1.pointer.pointee == UInt8(47)
                saw2 = unsafe p2.pointer.pointee == UInt8(47)
            }
            #expect(saw1)
            #expect(saw2)
        }

        @Test
        func `with two paths rejects NUL in first (index 0)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Path.scope("bad\0path", "/valid") { _, _ in () } }
            )
        }

        @Test
        func `with two paths rejects NUL in second (index 1)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 1)) },
                { () throws(E) in _ = try Path.scope("/valid", "bad\0path") { _, _ in () } }
            )
        }
    }

    // MARK: - Three Paths (Conversion-Only Overload)

    extension Path.String.Test.Unit {

        @Test
        func `with three paths passes valid strings`() throws {
            var count = 0
            try Path.scope("/a", "/b", "/c") { p1, p2, p3 in
                if unsafe p1.pointer.pointee == UInt8(47) { count += 1 }
                if unsafe p2.pointer.pointee == UInt8(47) { count += 1 }
                if unsafe p3.pointer.pointee == UInt8(47) { count += 1 }
            }
            #expect(count == 3)
        }

        @Test
        func `with three paths rejects NUL in first (index 0)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Path.scope("bad\0", "/b", "/c") { _, _, _ in () } }
            )
        }

        @Test
        func `with three paths rejects NUL in second (index 1)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 1)) },
                { () throws(E) in _ = try Path.scope("/a", "bad\0", "/c") { _, _, _ in () } }
            )
        }

        @Test
        func `with three paths rejects NUL in third (index 2)`() {
            typealias E = Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 2)) },
                { () throws(E) in _ = try Path.scope("/a", "/b", "bad\0") { _, _, _ in () } }
            )
        }
    }

    // MARK: - Edge Cases

    extension Path.String.Test.EdgeCase {

        @Test
        func `empty string is valid (no interior NUL)`() throws {
            let result = try Path.scope("") { path in
                unsafe path.pointer.pointee
            }
            #expect(result == 0)  // null terminator
        }

        @Test
        func `unicode path is valid`() throws {
            try Path.scope("/tmp/\u{65E5}\u{672C}\u{8A9E}/\u{6587}\u{4EF6}.txt") { path in
                let first = unsafe path.pointer.pointee
                #expect(first == UInt8(47))
            }
        }

        @Test
        func `long path is valid`() throws {
            let longComponent = Swift.String(repeating: "a", count: 200)
            try Path.scope("/tmp/\(longComponent)") { path in
                let first = unsafe path.pointer.pointee
                #expect(first == UInt8(47))
            }
        }
    }

#endif
