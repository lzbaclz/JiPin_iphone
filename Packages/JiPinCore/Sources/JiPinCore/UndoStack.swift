import Foundation

public final class UndoStack: @unchecked Sendable {
    private var undoItems: [CollageProject] = []
    private var redoItems: [CollageProject] = []
    public let limit: Int

    public init(limit: Int = JiPin.maxUndo) {
        self.limit = limit
    }

    public var canUndo: Bool { !undoItems.isEmpty }
    public var canRedo: Bool { !redoItems.isEmpty }
    public var undoCount: Int { undoItems.count }
    public var redoCount: Int { redoItems.count }

    public func checkpoint(_ project: CollageProject) {
        undoItems.append(project)
        if undoItems.count > limit {
            undoItems.removeFirst(undoItems.count - limit)
        }
        redoItems.removeAll()
    }

    public func undo(current: CollageProject) -> CollageProject? {
        guard let previous = undoItems.popLast() else { return nil }
        redoItems.append(current)
        if redoItems.count > limit {
            redoItems.removeFirst(redoItems.count - limit)
        }
        return previous
    }

    public func redo(current: CollageProject) -> CollageProject? {
        guard let next = redoItems.popLast() else { return nil }
        undoItems.append(current)
        return next
    }

    public func clear() {
        undoItems.removeAll()
        redoItems.removeAll()
    }
}
