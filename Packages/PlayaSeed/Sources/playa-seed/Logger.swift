import Foundation

/// Minimal console output. Progress rewrites a single line when attached to a TTY and
/// stays quiet otherwise, so CI logs don't fill with carriage returns.
final class Logger {
    private let isTerminal = isatty(fileno(stdout)) == 1
    private var lastPercent = -1

    func step(_ message: String) {
        print("==> \(message)")
    }

    func info(_ message: String) {
        print("    \(message)")
    }

    func warn(_ message: String) {
        FileHandle.standardError.write("warning: \(message)\n".data(using: .utf8)!)
    }

    func progress(_ done: Int, of total: Int) {
        guard isTerminal, total > 0 else { return }
        let percent = done * 100 / total
        guard percent != lastPercent else { return }
        lastPercent = percent
        print("\r    \(done)/\(total) (\(percent)%)", terminator: "")
        fflush(stdout)
    }

    func endProgress() {
        guard isTerminal, lastPercent >= 0 else { return }
        lastPercent = -1
        print("")
    }
}
