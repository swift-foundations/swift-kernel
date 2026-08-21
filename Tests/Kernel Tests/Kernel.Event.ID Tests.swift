#if !os(Windows)

    @_spi(Syscall) import Error_Primitives
    import Kernel_Test_Support
    @_spi(Syscall) import Path_Primitives
    import Tagged_Primitives_Standard_Library_Integration
    import Testing

    @testable @_spi(Syscall) import Kernel

    @Suite("Kernel.Event.ID Tests")
    struct EventIDTests {

        @Test
        func `ID can be created from UInt literal`() {
            let id: Kernel.Event.ID = 42
            #expect(id == 42)
        }

        @Test
        func `ID zero is valid`() {
            let id: Kernel.Event.ID = 0
            #expect(id == 0)
        }

        @Test
        func `ID max value`() {
            let id = Kernel.Event.ID(_unchecked: UInt.max)
            #expect(id.underlying == UInt.max)
        }

        @Test
        func `ID from descriptor reflects the fd raw value`() throws {

            let pipe = try Kernel.Pipe.pipe()
            let id = Kernel.Event.ID(pipe.read._rawValue)
            #expect(id.underlying == UInt(bitPattern: Int(pipe.read._rawValue)))
        }

        @Test
        func `Round-trip from descriptor through ID is symmetric`() throws {

            let pipe = try Kernel.Pipe.pipe()
            let originalRaw = pipe.read._rawValue
            let id = Kernel.Event.ID(pipe.read._rawValue)
            #expect(id.underlying <= UInt(Int32.max))
            #expect(Int32(id.underlying) == originalRaw)
        }

        @Test
        func `ID is Equatable`() {
            let a: Kernel.Event.ID = 42
            let b: Kernel.Event.ID = 42
            let c: Kernel.Event.ID = 43
            #expect(a == b)
            #expect(a != c)
        }

        @Test
        func `ID is Hashable`() {
            var set = Set<Kernel.Event.ID>()
            set.insert(Kernel.Event.ID(_unchecked: 1))
            set.insert(Kernel.Event.ID(_unchecked: 2))
            set.insert(Kernel.Event.ID(_unchecked: 1))
            #expect(set.count == 2)
        }

        @Test
        func `ID is Sendable`() {
            let id: Kernel.Event.ID = 42
            let sendable: any Sendable = id
            #expect(sendable is Kernel.Event.ID)
        }

        @Test
        func `ID is Comparable`() {
            let a: Kernel.Event.ID = 10
            let b: Kernel.Event.ID = 20
            #expect(a < b)
            #expect(b > a)
        }
    }

#endif
