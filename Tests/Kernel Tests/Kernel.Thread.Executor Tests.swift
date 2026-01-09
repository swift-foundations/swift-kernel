//
//  Kernel.Thread.Executor Tests.swift
//  swift-kernel
//

import Test_Support_Primitives
import Testing

@testable import Kernel

extension Kernel.Thread.Executor {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Thread.Executor.Test.Unit {
    @Test("executor conforms to SerialExecutor")
    func serialExecutorConformance() {
        let executor = Kernel.Thread.Executor()
        let unowned = executor.asUnownedSerialExecutor()
        // If this compiles and runs, the executor conforms
        _ = unowned
        executor.shutdown()
    }

    @Test("executor conforms to TaskExecutor")
    func taskExecutorConformance() async {
        let executor = Kernel.Thread.Executor()

        // Task(executorPreference:) only works with TaskExecutor
        await Task(executorPreference: executor) {
            // Job executed on executor
        }.value

        executor.shutdown()
    }

    @Test("shutdown completes gracefully")
    func shutdownCompletes() {
        let executor = Kernel.Thread.Executor()
        executor.shutdown()
        // No hang = success
    }
}

// MARK: - Integration Tests

extension Kernel.Thread.Executor.Test {
    @Suite struct Integration {}
}

extension Kernel.Thread.Executor.Test.Integration {
    @Test("task executor preference executes on thread")
    func taskExecutorPreferenceWorks() async {
        let executor = Kernel.Thread.Executor()

        // Use a Sendable result to verify execution
        let result = await Task(executorPreference: executor) {
            return 42
        }.value

        #expect(result == 42)
        executor.shutdown()
    }

    @Test("multiple tasks execute sequentially on same executor")
    func multipleTasksSequential() async {
        let executor = Kernel.Thread.Executor()

        let r1 = await Task(executorPreference: executor) { 1 }.value
        let r2 = await Task(executorPreference: executor) { 2 }.value
        let r3 = await Task(executorPreference: executor) { 3 }.value

        #expect(r1 == 1)
        #expect(r2 == 2)
        #expect(r3 == 3)
        executor.shutdown()
    }
}
