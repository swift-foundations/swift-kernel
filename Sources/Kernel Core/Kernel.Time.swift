extension Instant {

    @inlinable
    package init(seconds: Int64, nanoseconds: Int32) {
        self.init(
            _unchecked: (),
            secondsSinceUnixEpoch: seconds,
            nanosecondFraction: nanoseconds
        )
    }

    @inlinable
    package init(seconds: Int64) {
        self.init(seconds: seconds, nanoseconds: 0)
    }

    @inlinable
    package var seconds: Int64 { secondsSinceUnixEpoch }

    @inlinable
    package var nanoseconds: Int32 { nanosecondFraction }

    @inlinable
    package var totalNanoseconds: Int64 {
        secondsSinceUnixEpoch * 1_000_000_000 + Int64(nanosecondFraction)
    }

    @inlinable
    package init(totalNanoseconds: Int64) {
        self.init(
            seconds: totalNanoseconds / 1_000_000_000,
            nanoseconds: Int32(totalNanoseconds % 1_000_000_000)
        )
    }
}
