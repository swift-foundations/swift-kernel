//
//  Kernel.Completion.Submission.Count.swift
//  swift-kernel
//
//  Phantom-tagged count of completion submissions.
//

extension Kernel.Completion.Submission {
    /// Count of completion submissions.
    ///
    /// Phantom-tagged cardinal matching the L1 pattern
    /// (`Kernel.IO.Uring.Submission.Count`). The io_uring backend
    /// converts via `.retag(Kernel.Completion.Submission.self)`.
    public typealias Count = Tagged<Kernel.Completion.Submission, Cardinal>
}
