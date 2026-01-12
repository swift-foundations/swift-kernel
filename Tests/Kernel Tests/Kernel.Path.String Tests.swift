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
import Kernel_Primitives
import Kernel_Test_Support
import Test_Primitives
import Testing

extension Kernel.Path.String {
    #TestSuites
}

#if !os(Windows)

    // MARK: - Error<Body> Property Tests

    extension Kernel.Path.String.Test.Unit {

        @Test(".body extraction returns body error")
        func bodyExtraction() {
            enum TestError: Error, Equatable { case test }
            let error: Kernel.Path.String.Error<TestError> = .body(.test)
            #expect(error.body == .test)
            #expect(error.conversion == nil)
        }

        @Test(".conversion extraction returns conversion error")
        func conversionExtraction() {
            enum TestError: Error { case test }
            let error: Kernel.Path.String.Error<TestError> = .conversion(.interiorNUL(index: 0))
            #expect(error.conversion == .interiorNUL(index: 0))
            #expect(error.body == nil)
        }

        @Test(".mapBody preserves conversion errors")
        func mapBodyPreservesConversion() {
            enum A: Error { case a }
            enum B: Error { case b }
            let original: Kernel.Path.String.Error<A> = .conversion(.interiorNUL(index: 1))
            let mapped = original.mapBody { _ in B.b }
            #expect(mapped.conversion == .interiorNUL(index: 1))
        }

        @Test(".mapBody transforms body errors")
        func mapBodyTransformsBody() {
            enum A: Error, Equatable { case a }
            enum B: Error, Equatable { case b }
            let original: Kernel.Path.String.Error<A> = .body(.a)
            let mapped = original.mapBody { _ in B.b }
            #expect(mapped.body == .b)
        }
    }

    // MARK: - Single Path (Conversion-Only Overload)

    extension Kernel.Path.String.Test.Unit {

        @Test("with passes valid string to body")
        func singlePathValid() throws {
            let result = try Kernel.Path.scope("/tmp/test") { path in
                path.unsafeCString.pointee
            }
            #expect(result == Int8(47))  // ASCII '/'
        }

        @Test("with rejects interior NUL at start (conversion-only)")
        func singlePathNULAtStart() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Kernel.Path.scope("\0/tmp/file") { _ in () } }
            )
        }

        @Test("with rejects interior NUL in middle (conversion-only)")
        func singlePathNULInMiddle() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Kernel.Path.scope("/tmp/\0file") { _ in () } }
            )
        }

        @Test("with rejects interior NUL at end (conversion-only)")
        func singlePathNULAtEnd() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Kernel.Path.scope("/tmp/file\0") { _ in () } }
            )
        }
    }

    // MARK: - Single Path (Throwing-Body Overload / Wrapper Tests)

    extension Kernel.Path.String.Test.Unit {

        /// Dummy error type to force throwing-body overload selection.
        private enum Dummy: Error { case sentinel }

        @Test("with wraps conversion errors (throwing-body overload)")
        func singlePathNULWrapped() {
            typealias E = Kernel.Path.String.Error<Dummy>
            expectThrows(
                { (error: E) in
                    #expect(error.conversion == .interiorNUL(index: 0))
                    #expect(error.body == nil)
                },
                { () throws(E) in
                    _ = try Kernel.Path.scope("\0/tmp/file") { (_: borrowing Kernel.Path) throws(Dummy) in
                        ()  // never reached
                    }
                }
            )
        }

        @Test("with wraps body errors")
        func singlePathBodyErrorWrapped() {
            enum Body: Error, Equatable { case boom }
            typealias E = Kernel.Path.String.Error<Body>
            expectThrows(
                { (error: E) in
                    #expect(error.body == .boom)
                    #expect(error.conversion == nil)
                },
                { () throws(E) in
                    _ = try Kernel.Path.scope("/tmp/x") { (_: borrowing Kernel.Path) throws(Body) in
                        throw .boom
                    }
                }
            )
        }
    }

    // MARK: - Two Paths (Conversion-Only Overload)

    extension Kernel.Path.String.Test.Unit {

        @Test("with two paths passes valid strings")
        func twoPaths() throws {
            var saw1 = false
            var saw2 = false
            try Kernel.Path.scope("/path1", "/path2") { p1, p2 in
                saw1 = p1.unsafeCString.pointee == Int8(47)
                saw2 = p2.unsafeCString.pointee == Int8(47)
            }
            #expect(saw1)
            #expect(saw2)
        }

        @Test("with two paths rejects NUL in first (index 0)")
        func twoPathsNULInFirst() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Kernel.Path.scope("bad\0path", "/valid") { _, _ in () } }
            )
        }

        @Test("with two paths rejects NUL in second (index 1)")
        func twoPathsNULInSecond() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 1)) },
                { () throws(E) in _ = try Kernel.Path.scope("/valid", "bad\0path") { _, _ in () } }
            )
        }
    }

    // MARK: - Three Paths (Conversion-Only Overload)

    extension Kernel.Path.String.Test.Unit {

        @Test("with three paths passes valid strings")
        func threePaths() throws {
            var count = 0
            try Kernel.Path.scope("/a", "/b", "/c") { p1, p2, p3 in
                if p1.unsafeCString.pointee == Int8(47) { count += 1 }
                if p2.unsafeCString.pointee == Int8(47) { count += 1 }
                if p3.unsafeCString.pointee == Int8(47) { count += 1 }
            }
            #expect(count == 3)
        }

        @Test("with three paths rejects NUL in first (index 0)")
        func threePathsNULInFirst() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 0)) },
                { () throws(E) in _ = try Kernel.Path.scope("bad\0", "/b", "/c") { _, _, _ in () } }
            )
        }

        @Test("with three paths rejects NUL in second (index 1)")
        func threePathsNULInSecond() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 1)) },
                { () throws(E) in _ = try Kernel.Path.scope("/a", "bad\0", "/c") { _, _, _ in () } }
            )
        }

        @Test("with three paths rejects NUL in third (index 2)")
        func threePathsNULInThird() {
            typealias E = Kernel.Path.String.Conversion.Error
            expectThrows(
                { (error: E) in #expect(error == .interiorNUL(index: 2)) },
                { () throws(E) in _ = try Kernel.Path.scope("/a", "/b", "bad\0") { _, _, _ in () } }
            )
        }
    }

    // MARK: - Edge Cases

    extension Kernel.Path.String.Test.EdgeCase {

        @Test("empty string is valid (no interior NUL)")
        func emptyString() throws {
            let result = try Kernel.Path.scope("") { path in
                path.unsafeCString.pointee
            }
            #expect(result == 0)  // null terminator
        }

        @Test("unicode path is valid")
        func unicodePath() throws {
            try Kernel.Path.scope("/tmp/\u{65E5}\u{672C}\u{8A9E}/\u{6587}\u{4EF6}.txt") { path in
                #expect(path.unsafeCString.pointee == Int8(47))
            }
        }

        @Test("long path is valid")
        func longPath() throws {
            let longComponent = String(repeating: "a", count: 200)
            try Kernel.Path.scope("/tmp/\(longComponent)") { path in
                #expect(path.unsafeCString.pointee == Int8(47))
            }
        }
    }

#endif
