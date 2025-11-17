import Foundation

enum LayoutPersistence {
    private static let layoutsKey = "SavedLayouts"

    static func loadSavedLayouts() -> [LayoutData] {
        if let data = UserDefaults.standard.data(forKey: layoutsKey) {
            do {
                return try JSONDecoder().decode([LayoutData].self, from: data)
            } catch {
                print("Failed to load layouts: \(error)")
                UserDefaults.standard.removeObject(forKey: layoutsKey)
                return []
            }
        }
        return []
    }

    static func saveLayouts(_ layouts: [LayoutData]) {
        do {
            let data = try JSONEncoder().encode(layouts)
            UserDefaults.standard.set(data, forKey: layoutsKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to save layouts: \(error)")
        }
    }
}








