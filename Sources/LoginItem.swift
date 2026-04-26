import Foundation
import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var status: SMAppService.Status

    init() {
        status = SMAppService.mainApp.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[LoginItem] toggle failed: \(error)")
        }
        refresh()
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }
}
