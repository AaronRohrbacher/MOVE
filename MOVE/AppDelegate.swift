import ApplicationServices
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--clear-user-defaults") {
            UserDefaults.standard.removeObject(forKey: "SavedLayouts")
            UserDefaults.standard.synchronize()
            let emptyArray: [[String: Any]] = []
            if let emptyData = try? JSONSerialization.data(withJSONObject: emptyArray) {
                UserDefaults.standard.set(emptyData, forKey: "SavedLayouts")
            }
            UserDefaults.standard.synchronize()
        }

        requestAccessibilityPermissions()
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func applicationWillTerminate(_: Notification) {}

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return true
    }

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "MOVE")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()

    func save() {
        let context = persistentContainer.viewContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(window _: NSWindow) -> UndoManager? {
        return persistentContainer.viewContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let context = persistentContainer.viewContext

        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }

        if !context.hasChanges {
            return .terminateNow
        }

        do {
            try context.save()
        } catch {
            let nserror = error as NSError

            let result = sender.presentError(nserror)
            if result {
                return .terminateCancel
            }

            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info")
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)

            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        return .terminateNow
    }
}
