import AppKit
import Darwin
final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: FloatingController?
    private var lockFD: Int32 = -1
    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = ProcessInfo.processInfo.environment
        let directory = env["LITECAL_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LiteCal", isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        catch { showFatal(error.localizedDescription); return }
        lockFD = Darwin.open(directory.appendingPathComponent(".instance.lock").path, O_CREAT | O_RDWR, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { NSApp.terminate(nil); return }
        let defaults = env["LITECAL_DATA_DIR"] != nil ? UserDefaults(suiteName: "app.litecal.qa")! : .standard
        let store = EventStore(directory: directory); controller = FloatingController(store: store, defaults: defaults)
        if let error = store.loadError { controller?.open(); controller?.showError(error) }
        let menu = NSMenu(); let appMenu = NSMenu(); let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
        appMenu.addItem(withTitle: "退出 LiteCal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editMenu = NSMenu(title: "编辑"); let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: ""); editItem.submenu = editMenu; menu.addItem(editItem)
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] { editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        NSApp.mainMenu = menu
    }
    private func showFatal(_ message: String) { let a = NSAlert(); a.messageText = "LiteCal 无法读取数据目录"; a.informativeText = message; a.runModal(); NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { controller?.open(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        controller?.confirmQuit() == false ? .terminateCancel : .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) { if lockFD >= 0 { flock(lockFD, LOCK_UN); Darwin.close(lockFD) } }
}
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
