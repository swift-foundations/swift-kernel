//
//  Kernel.Completion.Submission.Count.swift
//  swift-kernel-primitives
//
//  Phantom-tagged count of completion submissions.
//

extension Kernel.Completion.Submission {
    /// Count of completion submissions.
    ///
    /// Phantom-tagged cardinal for type-safe submission counting.
    /// Backend conversions use `.retag()` to cross between
    /// platform-specific and cross-platform count types.
    public typealias Count = Tagged<Kernel.Completion.Submission, Cardinal>
}
