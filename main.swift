import Cocoa
import Vision
import Carbon.HIToolbox

// QuickOCR — ⌘1 框选 → 识别文字 → 复制到剪贴板
// 本地 Vision 优先；无识别结果时回落扫描全能王云端（cs-ocr.py，按 device_id 计 100 次/日）

let cloudScript = NSString(string: "~/skills/ocr-vision/cs-ocr.py").expandingTildeInPath
var hotKeyRef: EventHotKeyRef?

func hud(_ text: String) {
    let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 64),
                     styleMask: .borderless, backing: .buffered, defer: false)
    w.isOpaque = false
    w.backgroundColor = .clear
    w.level = .floating
    let label = NSTextField(labelWithString: text)
    label.alignment = .center
    label.font = .systemFont(ofSize: 15, weight: .medium)
    label.textColor = .white
    label.frame = NSRect(x: 0, y: 0, width: 320, height: 64)
    let box = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 64))
    box.wantsLayer = true
    box.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
    box.layer?.cornerRadius = 12
    box.addSubview(label)
    w.contentView = box
    if let screen = NSScreen.main {
        let f = screen.visibleFrame
        w.setFrameOrigin(NSPoint(x: f.midX - 160, y: f.midY - 32))
    }
    w.orderFrontRegardless()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { w.orderOut(nil) }
}

func visionOCR(_ path: String) -> String {
    guard let img = NSImage(contentsOfFile: path),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return "" }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = true
    req.recognitionLanguages = ["zh-Hans", "en-US"]
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    do { try handler.perform([req]) } catch { return "" }
    guard let obs = req.results else { return "" }
    let lines = obs.compactMap { $0.topCandidates(1).first?.string }
    return lines.joined(separator: "\n")
}

func cloudOCR(_ path: String) -> String {
    guard FileManager.default.fileExists(atPath: cloudScript) else { return "" }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    p.arguments = [cloudScript, path]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    do { try p.run() } catch { return "" }
    p.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func runOCR() {
    let tmp = NSTemporaryDirectory() + "quickocr-\(UUID().uuidString).png"
    let sc = Process()
    sc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    sc.arguments = ["-i", "-x", "-t", "png", tmp]
    try? sc.run()
    sc.waitUntilExit()

    let size = ((try? FileManager.default.attributesOfItem(atPath: tmp))?[.size] as? Int) ?? 0
    guard FileManager.default.fileExists(atPath: tmp), size > 0 else {
        hud("已取消")
        return
    }
    defer { try? FileManager.default.removeItem(atPath: tmp) }

    var text = visionOCR(tmp)
    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        text = cloudOCR(tmp)
    }
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty {
        hud("没识别出文字")
        return
    }
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(clean, forType: .string)
    hud("✓ 已复制 \(clean.count) 字")
}

func installHotKey() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
        DispatchQueue.main.async { runOCR() }
        return noErr
    }, 1, &spec, nil, nil)

    let id = EventHotKeyID(signature: OSType(0x514F4352), id: 1) // 'QOCR'
    let status = RegisterEventHotKey(UInt32(kVK_ANSI_1), UInt32(cmdKey), id,
                                     GetApplicationEventTarget(), 0, &hotKeyRef)
    if status != noErr {
        NSLog("QuickOCR: 注册 ⌘1 失败 status=\(status)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// CLI 自检：QuickOCR --file <图片> 直接输出识别结果，不驻留
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--file"), i + 1 < args.count {
    print(visionOCR(args[i + 1]))
    exit(0)
}

installHotKey()
app.run()
