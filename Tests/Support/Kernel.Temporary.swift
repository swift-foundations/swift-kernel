public import Kernel
import Strings

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif os(Windows)
    import WinSDK
#endif

extension Kernel {

    public enum Temporary {}
}

extension Kernel.Temporary {

    public static var directory: Swift.String {
        #if os(Windows)

            if let temp = Kernel.Environment.get("TEMP") {
                return unsafe temp.withUnsafePointer { Swift.String(decodingCString: $0, as: UTF16.self) }
            }
            if let tmp = Kernel.Environment.get("TMP") {
                return unsafe tmp.withUnsafePointer { Swift.String(decodingCString: $0, as: UTF16.self) }
            }
            return "C:\\Temp"
        #else
            if let tmpdir = unsafe Kernel.Environment.get("TMPDIR") {
                return unsafe tmpdir.withUnsafePointer { unsafe Swift.String(cString: $0) }
            }
            return "/tmp"
        #endif
    }

    public static func filePath(prefix: Swift.String) -> Swift.String {
        #if os(Windows)
            let pid = Int(GetCurrentProcessId())
        #else
            let pid = Int(getpid())
        #endif
        let random = Int.random(in: 0..<Int.max)
        let name = "\(prefix)-\(pid)-\(random)"

        #if os(Windows)
            return directory + "\\" + name
        #else
            return directory + "/" + name
        #endif
    }
}
