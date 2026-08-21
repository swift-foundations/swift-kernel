extension Kernel.Thread {

    @safe
    public final class Local<Payload: AnyObject>: @unchecked Sendable {
        @usableFromInline
        let _slot: _PlatformSlot

        @inlinable
        public init() throws(Kernel.Thread.Error) {
            #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
                _slot = try unsafe _PlatformSlot(destructor: _kernelThreadLocalRelease)
            #elseif os(Windows)
                _slot = _PlatformSlot()
            #endif
        }

        @inlinable
        public var value: Payload? {
            get {
                guard let opaque = unsafe _slot.value else { return nil }
                return unsafe Unmanaged<Payload>.fromOpaque(opaque).takeUnretainedValue()
            }
            set {
                if let oldOpaque = unsafe _slot.value {
                    unsafe Unmanaged<Payload>.fromOpaque(oldOpaque).release()
                }
                if let newValue {
                    let retained = unsafe Unmanaged.passRetained(newValue).toOpaque()
                    unsafe (_slot.value = retained)
                } else {
                    unsafe (_slot.value = nil)
                }
            }
        }
    }
}

#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    @usableFromInline
    internal typealias _PlatformSlot = ISO_9945.Kernel.Thread.Key

    @usableFromInline
    internal func _kernelThreadLocalRelease(_ raw: UnsafeMutableRawPointer) {
        unsafe Unmanaged<AnyObject>.fromOpaque(raw).release()
    }

#elseif os(Windows)
    @usableFromInline
    internal typealias _PlatformSlot = Windows.`32`.Kernel.Thread.Index
#endif
