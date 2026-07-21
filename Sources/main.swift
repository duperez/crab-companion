import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // sem ícone no Dock, nunca rouba foco
let delegate = AppDelegate()
app.delegate = delegate
app.run()
