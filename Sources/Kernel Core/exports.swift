// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-kernel open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-kernel project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

@_exported public import Kernel_Primitives_Core
@_exported public import Clock_Primitives
@_exported public import Kernel_Descriptor_Primitives
@_exported public import Kernel_Environment_Primitives
@_exported public import Error_Primitives
@_exported public import Kernel_IO_Primitives
@_exported public import Kernel_Memory_Primitives
@_exported public import Kernel_Permission_Primitives
@_exported public import Kernel_Process_Primitives
@_exported public import Random_Primitives
@_exported public import Kernel_Syscall_Primitives
@_exported public import Kernel_Time_Primitives
@_exported public import Kernel_Outcome_Primitives
@_exported public import Kernel_System_Primitives
@_exported public import Path_Primitives
@_exported public import Kernel_File_Primitives
@_exported public import Kernel_Socket_Primitives
@_exported public import Kernel_Thread_Primitives
@_exported public import Kernel_Event_Primitives
@_exported public import Kernel_Completion_Primitives
@_exported public import Kernel_Terminal_Primitives
@_exported public import Kernel_Glob_Primitives
@_exported public import System_Primitives
@_exported public import Queue_Primitives
@_exported public import Dimension_Primitives
@_exported public import Reference_Primitives
@_exported public import Ownership_Primitives

#if arch(x86_64) || arch(i386)
    @_exported public import X86_Standard
#elseif arch(arm64) || arch(arm)
    @_exported public import ARM_Standard
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD)
    @_exported public import POSIX_Kernel
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @_exported public import Darwin_Kernel
    @_exported public import Darwin_System
#elseif os(Linux) || os(Android) || os(OpenBSD)
    @_exported public import Linux_Kernel
    @_exported public import Linux_System
#elseif os(Windows)
    @_exported public import Windows_Kernel
#endif
