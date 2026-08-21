public import Path_Primitives

extension Kernel.File {

    public static func open(
        _ path: borrowing Path.Borrowed,
        configuration: Open.Configuration = .init()
    ) throws(Open.Error) -> Handle {

        let requirements = Direct.Requirements(path)

        let resolved: Direct.Mode.Resolved
        do throws(Kernel.File.Direct.Error) {
            resolved = try configuration.cache.resolve(given: requirements)
        } catch {

            resolved = .buffered
        }

        var kernelOptions: Open.Options = []
        if configuration.create { kernelOptions.insert(.create) }
        if configuration.truncate { kernelOptions.insert(.truncate) }
        #if os(Linux)
            if resolved == .direct { kernelOptions.insert(.direct) }
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            if resolved == .direct { kernelOptions.insert(.noCache) }
        #endif

        let descriptor = try Open.open(
            path: path,
            mode: configuration.mode,
            options: kernelOptions,
            permissions: .standard
        )

        return Handle(
            descriptor: descriptor,
            mode: resolved,
            requirements: requirements
        )
    }
}
