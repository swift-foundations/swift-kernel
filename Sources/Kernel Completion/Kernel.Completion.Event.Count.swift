//
//  Kernel.Completion.Event.Count.swift
//  swift-kernel-primitives
//
//  Phantom-tagged count of completion events.
//

extension Kernel.Completion.Event {
    /// Count of completion events.
    ///
    /// Phantom-tagged cardinal for type-safe event counting.
    /// Backend conversions use `.retag()` to cross between
    /// platform-specific and cross-platform count types.
    public typealias Count = Tagged<Kernel.Completion.Event, Cardinal>
}
