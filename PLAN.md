# PLAN

你的任务是做技术方案调研，我想实现一个raycast插件，用于修改macos上的默认浏览器。
当前没有现有功能的插件（你可以确认这点），只找到这个插件 https://www.raycast.com/fernando_barrios/defbro ，以及对应的代码库是 https://github.com/jwbargsten/defbro/blob/main/Sources/defbro/main.swift ；基本原理应该是使用 swift 调用 ApplicationServices 来修改系统设定；关于raycast调用swift作为脚本的说明是 https://www.raycast.com/blog/automate-your-mac-with-swift 。请你给出清晰的最小实现技术方案。

最小实现方案 （零外部依赖，Swift 直调 Launch Services）
思路：一个 Swift 脚本同时负责“列出候选浏览器 + 设置默认”，Raycast 作为 Script Command 或 TypeScript 扩展去调用。

A. 直接做 Script Command（最短路径，参数手填）
将下述脚本保存为 `set-default-browser.swift`，放入 Raycast 的 Script Commands 目录（Raycast → Extensions → “+” → Add Script Directory）。脚本头部注释为 Raycast 元数据；Raycast 官方博客示例采用同样方式。([raycast.com][2])

```swift
#!/usr/bin/swift
// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Set Default Browser
// @raycast.mode fullOutput
// Optional parameters:
// @raycast.packageName System
// @raycast.argument1 { "type": "text", "placeholder": "Bundle ID (e.g. com.google.Chrome or --list-json)" }

import Foundation
import AppKit
import CoreServices // Launch Services symbols

func setDefault(_ bid: String) throws {
  let schemes: [CFString] = ["http" as CFString, "https" as CFString]
  for s in schemes {
    let status = LSSetDefaultHandlerForURLScheme(s, bid as CFString)
    if status != noErr {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "LSSetDefaultHandlerForURLScheme(\(s)) failed: \(status)"])
    }
  }
}

func listJSON() {
  let handlers = (LSCopyAllHandlersForURLScheme("http" as CFString)?.takeRetainedValue() as? [String]) ?? []
  let current = (LSCopyDefaultHandlerForURLScheme("http" as CFString)?.takeRetainedValue() as String?) ?? ""
  let items: [[String: Any]] = handlers.map { bid in
    var name = bid
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid),
       let b = Bundle(url: url),
       let n = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") ?? b.object(forInfoDictionaryKey: "CFBundleName")) as? String {
      name = n
    }
    return ["id": bid, "name": name, "isDefault": bid == current]
  }
  let data = try! JSONSerialization.data(withJSONObject: items, options: [])
  print(String(data: data, encoding: .utf8)!)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
  fputs("Usage: set-default-browser.swift <bundle-id> | --list-json\n", stderr)
  exit(64)
}
if args[1] == "--list-json" { listJSON(); exit(0) }
do { try setDefault(args[1]); print("OK") } catch { fputs("\(error)\n", stderr); exit(1) }
```

说明：`--list-json` 可供后续做 UI；真正设置默认时对 `http` & `https` 同步设置，做法与现有工具一致。([Apple Developer][4])

B. 做成 TS 扩展 + Swift 脚本（更好的交互，无需 Homebrew）
把上面的 Swift 文件放在扩展 `assets/defbrowser.swift`，TS 用 `child_process.execFile("swift", ["assets/defbrowser.swift","--list-json"])` 拉列表，用 `child_process.execFile("swift", ["assets/defbrowser.swift", bundleId])` 设置，UI 代码与“方案 A”基本相同，仅把 `defbro` 调用替换为 `swift assets/defbrowser.swift`。注意：用户机器需装 Xcode Command Line Tools（提供 Swift 解释器）。Raycast 执行 Swift 脚本属于官方支持路径。([raycast.com][2])

——

实现要点与边界

1. 列表枚举：更“现代”的做法是以 `NSWorkspace.urlsForApplications(toOpen:)` 交叉校验 HTML 与 HTTPS 的 handler，以剔除非浏览器型 App；如需更准，可按该文方案扩展（可选）。([ericmaciel.me][5])
2. API 兼容性：`LS*` 属于旧 Launch Services，文档标 deprecated，但目前 macOS 上仍有效，`defbro/defaultbrowser` 等仍依赖它；若未来移除，可退化为跳系统设置或引导用户手动操作。([enochchau.com][6])
3. 权限与签名：脚本/CLI 调用 Launch Services 不需要额外 TCC 权限；不走私有 API。
4. 常见 Bundle ID 参考：`com.apple.Safari`, `com.google.Chrome`, `org.mozilla.firefox`, `com.brave.Browser`, `com.microsoft.edgemac`, `company.thebrowser.Browser`（Arc）。

[1]: https://www.raycast.com/fernando_barrios/defbro "Raycast Store: Defbro"
[2]: https://www.raycast.com/blog/automate-your-mac-with-swift "Automate your Mac with Swift - Raycast Blog"
[3]: https://developer.apple.com/documentation/coreservices/1447760-lssetdefaulthandlerforurlscheme?utm_source=chatgpt.com "LSSetDefaultHandlerForURLSch..."
[4]: https://developer.apple.com/documentation/coreservices/1443240-lscopyallhandlersforurlscheme?utm_source=chatgpt.com "LSCopyAllHandlersForURLSche..."
[5]: https://ericmaciel.me/posts/how-to-get-the-list-of-installed-browsers-on-macos/?utm_source=chatgpt.com "How to get the list of installed browsers on macOS - Eric Maciel"
[6]: https://enochchau.com/blog/2025/hey-gemini-write-me-a-menu-bar-app/?utm_source=chatgpt.com "Hey Gemini, Write Me a Menu Bar App"
