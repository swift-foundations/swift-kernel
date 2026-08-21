public import Memory_Primitives

#if !os(Windows)

    public import Kernel_Event
#endif

#if os(Windows)

    public import Windows_Kernel_File
#endif

extension Kernel.Completion.Submission {

    public enum Opcode: Sendable, Equatable, Hashable {

        case noOperation

        case read(
            address: Memory.Address,
            length: Memory.Address.Count,
            offset: Kernel.File.Offset?
        )

        case write(
            address: Memory.Address,
            length: Memory.Address.Count,
            offset: Kernel.File.Offset?
        )

        case close

        case accept

        case connect(
            address: Memory.Address,
            length: Memory.Address.Count
        )

        case send(
            address: Memory.Address,
            length: Memory.Address.Count
        )

        case receive(
            address: Memory.Address,
            length: Memory.Address.Count
        )

        case cancel(target: Kernel.Completion.Token)

        case synchronize

        #if !os(Windows)

            case readiness(events: Kernel.Event.Interest)
        #endif
    }
}
