import AppKit

/// One owner for the merged feature. Disabled features leave no overlay or polling timers.
@MainActor
final class ScreenEdgeFeatureController {
    let model: ScreenEdgeModel
    let overlays = OverlayController()
    private var lockMonitor: ScreenLockMonitor?

    init(ephemeral: Bool = false) {
        model = ScreenEdgeModel(ephemeral: ephemeral)
        model.onChange = { [weak self] in self?.rebuild() }
        model.onPreview = { [weak self] in
            guard let self else { return }
            self.overlays.preview(model: self.model)
        }
        rebuild()
    }

    private func rebuild() {
        if model.preferences.enabled {
            if lockMonitor == nil {
                lockMonitor = ScreenLockMonitor { [weak self] locked in
                    Task { @MainActor in self?.model.setScreenLocked(locked) }
                }
            }
        } else {
            lockMonitor?.stop(); lockMonitor = nil
        }
        overlays.rebuild(model: model)
    }

    func stop() {
        lockMonitor?.stop(); lockMonitor = nil
        overlays.stop()
        model.stop()
    }
}
