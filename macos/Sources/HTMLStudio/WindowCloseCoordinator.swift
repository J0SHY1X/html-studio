import AppKit
import SwiftUI

@MainActor
final class ApplicationCloseCoordinator {
    static let shared = ApplicationCloseCoordinator()

    var requestHandler: ((@escaping (Bool) -> Void) -> Void)?
    private(set) var approvedForTermination = false
    private var isRequesting = false
    private var pendingCompletions: [(Bool) -> Void] = []

    func requestClose(completion: @escaping (Bool) -> Void) {
        if approvedForTermination {
            completion(true)
            return
        }
        pendingCompletions.append(completion)
        guard !isRequesting else { return }
        guard let requestHandler else {
            finish(allowed: true)
            return
        }
        isRequesting = true
        requestHandler { [weak self] allowed in
            self?.finish(allowed: allowed)
        }
    }

    func reset() {
        approvedForTermination = false
        isRequesting = false
        pendingCompletions.removeAll()
    }

    private func finish(allowed: Bool) {
        approvedForTermination = allowed
        isRequesting = false
        let completions = pendingCompletions
        pendingCompletions.removeAll()
        completions.forEach { $0(allowed) }
    }
}

struct WindowCloseGuard: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: AttachmentView, context: Context) {
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(_ nsView: AttachmentView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class AttachmentView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }

    @MainActor
    final class Coordinator {
        private weak var window: NSWindow?
        private var proxy: WindowDelegateProxy?

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            detach()
            let proxy = WindowDelegateProxy(previous: window.delegate)
            self.window = window
            self.proxy = proxy
            window.delegate = proxy
        }

        func detach() {
            if let window, window.delegate === proxy {
                window.delegate = proxy?.previous
            }
            window = nil
            proxy = nil
        }
    }
}

@MainActor
private final class WindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var previous: NSWindowDelegate?
    private var allowNextClose = false

    init(previous: NSWindowDelegate?) {
        self.previous = previous
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowNextClose { return true }
        ApplicationCloseCoordinator.shared.requestClose { [weak self, weak sender] allowed in
            guard allowed, let self, let sender else { return }
            self.allowNextClose = true
            sender.performClose(nil)
        }
        return false
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (previous?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if previous?.responds(to: aSelector) == true { return previous }
        return super.forwardingTarget(for: aSelector)
    }
}
