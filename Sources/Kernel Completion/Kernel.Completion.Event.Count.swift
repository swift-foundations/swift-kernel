//
//  Kernel.Completion.Event.Count.swift
//  swift-kernel
//
//  Phantom-tagged count of completion events.
//

extension Kernel.Completion.Event {
    /// Count of completion events.
    ///
    /// Phantom-tagged cardinal matching the L1 pattern
    /// (`Kernel.IO.Uring.Completion.Count`). The io_uring backend
    /// converts via `.retag(Kernel.Completion.Event.self)`.
    public typealias Count = Tagged<Kernel.Completion.Event, Cardinal>
}
