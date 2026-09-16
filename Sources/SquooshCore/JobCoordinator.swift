import Foundation

public actor JobCoordinator {
    private var machine = JobStateMachine(state: .ready)
    private var paused = false
    private var cancelled = false

    public init() {}

    public func start() throws {
        if machine.state == .paused {
            try machine.transition(to: .running)
        } else if machine.state == .ready {
            try machine.transition(to: .running)
        } else {
            machine = JobStateMachine(state: .ready)
            try machine.transition(to: .running)
        }
        paused = false
        cancelled = false
    }

    public func pause() throws {
        guard machine.state == .running else { return }
        try machine.transition(to: .pausing)
        try machine.transition(to: .paused)
        paused = true
    }

    public func resume() throws {
        guard machine.state == .paused else { return }
        try machine.transition(to: .running)
        paused = false
    }

    public func cancel() throws {
        guard ![.completed, .completedWithErrors, .cancelled, .failed].contains(machine.state) else { return }
        if machine.state == .ready {
            try machine.transition(to: .cancelled)
        } else {
            try machine.transition(to: .cancelling)
            try machine.transition(to: .cancelled)
        }
        cancelled = true
        paused = false
    }

    public func waitForPermission() async throws {
        while paused && !cancelled {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if cancelled || Task.isCancelled { throw SquooshProError.cancelled }
    }

    public func finish(hadErrors: Bool) throws {
        guard machine.state == .running else { return }
        try machine.transition(to: hadErrors ? .completedWithErrors : .completed)
    }

    public func currentState() -> JobState { machine.state }
}
