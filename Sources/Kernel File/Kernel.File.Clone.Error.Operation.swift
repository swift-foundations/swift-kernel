extension Kernel.File.Clone.Error {

    public enum Operation: Swift.String, Sendable, Equatable {
        case clonefile
        case copyfile
        case ficlone
        case copyFileRange
        case duplicateExtents
        case statfs
        case stat
        case copy
    }
}
