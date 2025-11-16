import ApplicationServices
import Cocoa
import ObjectiveC

extension ViewController {
    func loadSavedLayouts() {
        savedLayouts = LayoutPersistence.loadSavedLayouts()
        DispatchQueue.main.async { [weak self] in
            self?.layoutsTableView?.reloadData()
        }
    }

    func saveLayouts() {
        LayoutPersistence.saveLayouts(savedLayouts)
    }
}

