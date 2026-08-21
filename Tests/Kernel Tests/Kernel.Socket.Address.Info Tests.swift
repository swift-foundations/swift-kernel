import Kernel
import Testing

#if !os(Windows)

    extension Kernel.Socket.Address.Info {
        @Suite
        struct Test {
            @Suite struct Get {}
        }
    }

    extension Kernel.Socket.Address.Info.Test.Get {
        @Test
        func `get(host:) resolves localhost through the unified Kernel surface`()
            throws(Kernel.Socket.Address.Info.Error)
        {

            let hints = Kernel.Socket.Address.Info.Hints()
            let list = try Kernel.Socket.Address.Info.List.get(
                host: "localhost",
                hints: hints
            )
            _ = consume list
        }
    }

#endif
