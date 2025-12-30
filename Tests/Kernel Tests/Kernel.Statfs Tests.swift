//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import StandardsTestSupport
import Testing

@testable import Kernel

extension Kernel.Statfs {
    #TestSuites
}

// MARK: - Unit Tests

extension Kernel.Statfs.Test.Unit {
    @Test("Statfs memberwise init")
    func memberwiseInit() {
        let fs = Kernel.Statfs(
            type: 0x1234,
            blockSize: 4096,
            blocks: 1000000,
            freeBlocks: 500000,
            availableBlocks: 400000,
            files: 100000,
            freeFiles: 50000,
            fsid: 0xABCD,
            nameMax: 255
        )

        #expect(fs.type == 0x1234)
        #expect(fs.blockSize == 4096)
        #expect(fs.blocks == 1000000)
        #expect(fs.freeBlocks == 500000)
        #expect(fs.availableBlocks == 400000)
        #expect(fs.files == 100000)
        #expect(fs.freeFiles == 50000)
        #expect(fs.fsid == 0xABCD)
        #expect(fs.nameMax == 255)
        #expect(fs.fsTypeName == nil) // Default is nil
    }

    @Test("Statfs with fsTypeName")
    func withFsTypeName() {
        let fs = Kernel.Statfs(
            type: 0x1234,
            blockSize: 4096,
            blocks: 1000000,
            freeBlocks: 500000,
            availableBlocks: 400000,
            files: 100000,
            freeFiles: 50000,
            fsid: 0xABCD,
            nameMax: 255,
            fsTypeName: "apfs"
        )

        #expect(fs.fsTypeName == "apfs")
    }

    @Test("Statfs is equatable")
    func equatable() {
        let fs1 = Kernel.Statfs(
            type: 1,
            blockSize: 4096,
            blocks: 1000,
            freeBlocks: 500,
            availableBlocks: 400,
            files: 100,
            freeFiles: 50,
            fsid: 1,
            nameMax: 255
        )

        let fs2 = Kernel.Statfs(
            type: 1,
            blockSize: 4096,
            blocks: 1000,
            freeBlocks: 500,
            availableBlocks: 400,
            files: 100,
            freeFiles: 50,
            fsid: 1,
            nameMax: 255
        )

        let fs3 = Kernel.Statfs(
            type: 2, // Different type
            blockSize: 4096,
            blocks: 1000,
            freeBlocks: 500,
            availableBlocks: 400,
            files: 100,
            freeFiles: 50,
            fsid: 1,
            nameMax: 255
        )

        #expect(fs1 == fs2)
        #expect(fs1 != fs3)
    }

    @Test("Statfs is hashable")
    func hashable() {
        let fs1 = Kernel.Statfs(
            type: 1,
            blockSize: 4096,
            blocks: 1000,
            freeBlocks: 500,
            availableBlocks: 400,
            files: 100,
            freeFiles: 50,
            fsid: 1,
            nameMax: 255
        )

        let fs2 = Kernel.Statfs(
            type: 2,
            blockSize: 4096,
            blocks: 1000,
            freeBlocks: 500,
            availableBlocks: 400,
            files: 100,
            freeFiles: 50,
            fsid: 1,
            nameMax: 255
        )

        var set = Set<Kernel.Statfs>()
        set.insert(fs1)
        set.insert(fs1) // Duplicate
        set.insert(fs2)

        #expect(set.count == 2)
    }
}

// MARK: - Computed Property Tests

extension Kernel.Statfs.Test.Unit {
    @Test("availableBlocks <= freeBlocks (typical)")
    func availableVsFree() {
        // In real filesystems, availableBlocks is typically <= freeBlocks
        // (root-reserved blocks)
        let fs = Kernel.Statfs(
            type: 1,
            blockSize: 4096,
            blocks: 1000,
            freeBlocks: 500,
            availableBlocks: 400, // Less than freeBlocks
            files: 100,
            freeFiles: 50,
            fsid: 1,
            nameMax: 255
        )

        #expect(fs.availableBlocks <= fs.freeBlocks)
    }
}
