import ApplicationServices
import Cocoa

extension ViewController {
    @objc func saveLayout() {
        showSaveLayoutPopup { [weak self] name, includeDesktopIcons in
            guard let self = self, !name.isEmpty else { return }

            var windows = WindowCapture.captureCurrentLayout()

            var capturedDesktopIcons: [DesktopIconInfo] = []
            if includeDesktopIcons {
                let extraction = DesktopIconManager.extractDesktopIconsAndFilter(from: windows)
                capturedDesktopIcons = extraction.icons
                windows = extraction.filteredWindows
            }

            let layout = LayoutData(
                name: name,
                windows: windows,
                desktopIcons: capturedDesktopIcons.isEmpty ? nil : capturedDesktopIcons,
                includeDesktopIcons: includeDesktopIcons,
                dateCreated: Date()
            )

            self.savedLayouts.append(layout)
            self.saveLayouts()
            self.layoutsTableView?.reloadData()
        }
    }

    @objc private func applyLayout() {
        var row = layoutsTableView?.selectedRow ?? -1
        if row < 0, !savedLayouts.isEmpty {
            row = 0
            layoutsTableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        guard row >= 0, row < savedLayouts.count else { return }

        let layout = savedLayouts[row]
        WindowRestore.restoreLayout(layout)
    }

    @objc private func deleteLayout() {
        var row = layoutsTableView?.selectedRow ?? -1
        if row < 0, !savedLayouts.isEmpty { row = 0 }
        guard row >= 0, row < savedLayouts.count else { return }

        savedLayouts.remove(at: row)
        saveLayouts()
        layoutsTableView?.reloadData()
    }

    func captureDesktopIcons(from windows: [WindowInfo]) -> [DesktopIconInfo] {
        return DesktopIconManager.captureDesktopIcons(from: windows)
    }

    func restoreDesktopIcons(_ icons: [DesktopIconInfo]) {
        DesktopIconManager.restoreDesktopIcons(icons)
    }
}

