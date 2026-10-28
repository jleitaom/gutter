/// What Gutter is doing right now, shown in the panel header and the right-click menu.
public enum GutterStatus: Equatable, Sendable {
    case active, paused, waiting, needsAccess

    /// Missing access comes first, since nothing works without it; then a paused auto-fit;
    /// then waiting for Stage Manager when Gutter only works with it.
    public init(accessGranted: Bool, autoFit: Bool, onlyWithStageManager: Bool, stageManagerOn: Bool) {
        if !accessGranted {
            self = .needsAccess
        } else if !autoFit {
            self = .paused
        } else if onlyWithStageManager && !stageManagerOn {
            self = .waiting
        } else {
            self = .active
        }
    }

    public var title: String {
        switch self {
        case .active: "Active"
        case .paused: "Paused"
        case .waiting: "Waiting for Stage Manager"
        case .needsAccess: "Needs access"
        }
    }
}
