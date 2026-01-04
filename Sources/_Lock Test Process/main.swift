//
//  main.swift
//  _Lock Test Process
//
//  A helper executable for multi-process file locking tests.
//
//  Usage:
//    _Lock\ Test\ Process <command> <file> [options]
//
//  Commands:
//    lock-exclusive <file>       Acquire exclusive lock, wait for signal, release
//    lock-shared <file>          Acquire shared lock, wait for signal, release
//    try-exclusive <file>        Try to acquire exclusive lock (non-blocking)
//    try-shared <file>           Try to acquire shared lock (non-blocking)
//    deadline-exclusive <file>   Acquire exclusive lock with deadline
//    deadline-shared <file>      Acquire shared lock with deadline
//
//  Options:
//    --range <start>-<end>       Lock byte range (default: whole file)
//    --hold <seconds>            Hold lock for N seconds instead of waiting for stdin
//    --deadline-ms <ms>          Deadline in milliseconds (for deadline-* commands)
//    --signal-ready              Print "READY" when lock is acquired
//
//  Exit codes:
//    0  Success (lock acquired, or released)
//    1  Lock would block (for try-* commands)
//    2  Lock timed out (for deadline-* commands)
//    3  Error (invalid arguments, file not found, etc.)
//

import Binary
import Kernel
internal import SystemPackage

#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#elseif os(Windows)
    internal import WinSDK
#endif

// MARK: - IO Helpers

func writeStdout(_ message: String) {
    _ = try? FileDescriptor.standardOutput.writeAll(message.utf8)
}

func writeStderr(_ message: String) {
    _ = try? FileDescriptor.standardError.writeAll(message.utf8)
}

func readStdinByte() {
    var buffer: UInt8 = 0
    _ = try? withUnsafeMutableBytes(of: &buffer) { ptr in
        try FileDescriptor.standardInput.read(into: ptr)
    }
}

// MARK: - Argument Parsing

struct Arguments {
    enum Command {
        case lockExclusive
        case lockShared
        case tryExclusive
        case tryShared
        case deadlineExclusive
        case deadlineShared
    }

    let command: Command
    let filePath: String
    var range: Kernel.Lock.Range = .file
    var holdSeconds: Int? = nil
    var deadlineMs: Int = 1000  // Default 1 second
    var signalReady: Bool = false
}

func parseArguments() -> Arguments? {
    let args = CommandLine.arguments
    guard args.count >= 3 else {
        printUsage()
        return nil
    }

    let commandStr = args[1]
    let filePath = args[2]

    let command: Arguments.Command
    switch commandStr {
    case "lock-exclusive":
        command = .lockExclusive
    case "lock-shared":
        command = .lockShared
    case "try-exclusive":
        command = .tryExclusive
    case "try-shared":
        command = .tryShared
    case "deadline-exclusive":
        command = .deadlineExclusive
    case "deadline-shared":
        command = .deadlineShared
    default:
        writeStderr("Unknown command: \(commandStr)\n")
        printUsage()
        return nil
    }

    var result = Arguments(command: command, filePath: filePath)

    // Parse optional arguments
    var i = 3
    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--range":
            guard i + 1 < args.count else {
                writeStderr("--range requires an argument\n")
                return nil
            }
            i += 1
            let rangeStr = args[i]
            let parts = rangeStr.split(separator: "-")
            guard parts.count == 2,
                let start = Int64(parts[0]),
                let end = Int64(parts[1])
            else {
                writeStderr("Invalid range format. Use: start-end\n")
                return nil
            }
            result.range = .bytes(start: Kernel.File.Offset(start), end: Kernel.File.Offset(end))

        case "--hold":
            guard i + 1 < args.count else {
                writeStderr("--hold requires an argument\n")
                return nil
            }
            i += 1
            guard let seconds = Int(args[i]) else {
                writeStderr("Invalid hold seconds\n")
                return nil
            }
            result.holdSeconds = seconds

        case "--deadline-ms":
            guard i + 1 < args.count else {
                writeStderr("--deadline-ms requires an argument\n")
                return nil
            }
            i += 1
            guard let ms = Int(args[i]) else {
                writeStderr("Invalid deadline milliseconds\n")
                return nil
            }
            result.deadlineMs = ms

        case "--signal-ready":
            result.signalReady = true

        default:
            writeStderr("Unknown option: \(arg)\n")
            return nil
        }
        i += 1
    }

    return result
}

func printUsage() {
    let usage = """
        Usage: _Lock\\ Test\\ Process <command> <file> [options]

        Commands:
          lock-exclusive <file>       Acquire exclusive lock, wait, release
          lock-shared <file>          Acquire shared lock, wait, release
          try-exclusive <file>        Try exclusive lock (non-blocking)
          try-shared <file>           Try shared lock (non-blocking)
          deadline-exclusive <file>   Acquire exclusive lock with deadline
          deadline-shared <file>      Acquire shared lock with deadline

        Options:
          --range <start>-<end>       Lock byte range (default: whole file)
          --hold <seconds>            Hold lock for N seconds
          --deadline-ms <ms>          Deadline in milliseconds (default: 1000)
          --signal-ready              Print "READY" when lock acquired

        Exit codes:
          0  Success
          1  Lock would block (try-* commands)
          2  Lock timed out (deadline-* commands)
          3  Error

        """
    writeStderr(usage)
}

// MARK: - Main

#if !os(Windows)

    func main() throws -> Int32 {
        guard let args = parseArguments() else {
            return 3
        }

        // Open the file
        let fd = open(args.filePath, O_RDWR)
        guard fd >= 0 else {
            writeStderr("Failed to open file: \(args.filePath)\n")
            return 3
        }
        defer { close(fd) }

        let kind: Kernel.Lock.Kind
        let acquire: Kernel.Lock.Acquire

        switch args.command {
        case .lockExclusive:
            kind = .exclusive
            acquire = .wait
        case .lockShared:
            kind = .shared
            acquire = .wait
        case .tryExclusive:
            kind = .exclusive
            acquire = .try
        case .tryShared:
            kind = .shared
            acquire = .try
        case .deadlineExclusive:
            kind = .exclusive
            acquire = .timeout(.milliseconds(args.deadlineMs))
        case .deadlineShared:
            kind = .shared
            acquire = .timeout(.milliseconds(args.deadlineMs))
        }

        // Acquire lock
        var token: Kernel.Lock.Token
        do {
            token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: fd),
                range: args.range,
                kind: kind,
                acquire: acquire
            )
        } catch {
            switch error {
            case .contention:
                if case .try = acquire {
                    writeStdout("WOULD_BLOCK\n")
                    return 1
                } else {
                    writeStdout("TIMED_OUT\n")
                    return 2
                }
            default:
                writeStderr("Failed to acquire lock: \(error)\n")
                return 3
            }
        }

        // Signal ready if requested
        if args.signalReady {
            writeStdout("READY\n")
        }

        // Hold lock
        if let seconds = args.holdSeconds {
            sleep(UInt32(seconds))
        } else {
            // Wait for newline on stdin
            readStdinByte()
        }

        // Release lock
        try token.release()

        writeStdout("RELEASED\n")

        return 0
    }

    do {
        exit(try main())
    } catch {
        writeStderr("Error: \(error)\n")
        exit(3)
    }

#else

    // Windows implementation
    func main() throws -> Int32 {
        guard let args = parseArguments() else {
            return 3
        }

        // Open the file
        let maybeHandle = args.filePath.withCString(encodedAs: UTF16.self) { widePath in
            CreateFileW(
                widePath,
                DWORD(GENERIC_READ) | DWORD(GENERIC_WRITE),
                0,  // No sharing
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_ATTRIBUTE_NORMAL),
                nil
            )
        }

        guard let handle = maybeHandle, handle != INVALID_HANDLE_VALUE else {
            writeStderr("Failed to open file: \(args.filePath)\n")
            return 3
        }
        defer { CloseHandle(handle) }

        let kind: Kernel.Lock.Kind
        let acquire: Kernel.Lock.Acquire

        switch args.command {
        case .lockExclusive:
            kind = .exclusive
            acquire = .wait
        case .lockShared:
            kind = .shared
            acquire = .wait
        case .tryExclusive:
            kind = .exclusive
            acquire = .try
        case .tryShared:
            kind = .shared
            acquire = .try
        case .deadlineExclusive:
            kind = .exclusive
            acquire = .timeout(.milliseconds(args.deadlineMs))
        case .deadlineShared:
            kind = .shared
            acquire = .timeout(.milliseconds(args.deadlineMs))
        }

        // Acquire lock
        var token: Kernel.Lock.Token
        do {
            token = try Kernel.Lock.Token(
                descriptor: Kernel.Descriptor(rawValue: handle),
                range: args.range,
                kind: kind,
                acquire: acquire
            )
        } catch {
            switch error {
            case .contention:
                if case .try = acquire {
                    writeStdout("WOULD_BLOCK\n")
                    return 1
                } else {
                    writeStdout("TIMED_OUT\n")
                    return 2
                }
            default:
                writeStderr("Failed to acquire lock: \(lockError)\n")
                return 3
            }
        }

        // Signal ready if requested
        if args.signalReady {
            writeStdout("READY\n")
        }

        // Hold lock
        if let seconds = args.holdSeconds {
            Sleep(DWORD(seconds * 1000))
        } else {
            // Wait for newline on stdin
            readStdinByte()
        }

        // Release lock
        try token.release()

        writeStdout("RELEASED\n")

        return 0
    }

    do {
        exit(try main())
    } catch {
        writeStderr("Error: \(error)\n")
        exit(3)
    }

#endif
