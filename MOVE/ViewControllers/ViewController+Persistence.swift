import ApplicationServices
import Cocoa
import ObjectiveC

extension ViewController {
    func loadSavedLayouts() {
        savedLayouts = LayoutPersistence.loadSavedLayouts()
        print("ViewController: Loaded \(savedLayouts.count) layouts")
        DispatchQueue.main.async { [weak self] in
            print("ViewController: Reloading table view")
            self?.layoutsTableView?.reloadData()
            self?.registerAllHotkeys()
        }
    }

    func saveLayouts() {
        LayoutPersistence.saveLayouts(savedLayouts)
    }
}








