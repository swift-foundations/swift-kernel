import Path_Primitives
public import String_Primitives

extension Swift.String {

    @inlinable
    public init(_ path: borrowing Path) {
        #if os(Windows)
            self = unsafe Swift.String(decodingCString: path.view.pointer, as: UTF16.self)
        #else
            self = unsafe Swift.String(cString: path.view.pointer)
        #endif
    }
}

extension Swift.String {

    @inlinable
    public init(_ view: borrowing Path.Borrowed) {
        #if os(Windows)
            self = unsafe Swift.String(decodingCString: view.pointer, as: UTF16.self)
        #else
            self = unsafe Swift.String(cString: view.pointer)
        #endif
    }
}

extension Swift.String {

    public init(_ string: borrowing String) {
        #if os(Windows)
            self = unsafe Swift.String(decodingCString: string.view.pointer, as: UTF16.self)
        #else
            self = unsafe Swift.String(cString: string.view.pointer)
        #endif
    }
}
