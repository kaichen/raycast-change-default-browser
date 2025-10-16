#!/usr/bin/swift

import Foundation
import AppKit
import CoreServices

func bundleIdentifier(forApplicationURL url: URL) -> String? {
  return Bundle(url: url)?.bundleIdentifier
}

func applicationBundleIdsSupporting(scheme: String) -> Set<String> {
  guard let testURL = URL(string: "\(scheme)://example.com") else { return [] }
  let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: testURL)
  let bundleIds = appURLs.compactMap { bundleIdentifier(forApplicationURL: $0) }
  return Set(bundleIds)
}

func currentDefaultBundleId(for scheme: String) -> String {
  guard let testURL = URL(string: "\(scheme)://example.com") else { return "" }
  if let appURL = NSWorkspace.shared.urlForApplication(toOpen: testURL),
     let bid = Bundle(url: appURL)?.bundleIdentifier {
    return bid
  }
  return ""
}

func setDefault(_ bid: String) throws {
  let schemes: [String] = ["http", "https"]
  let contentTypes: [String] = ["public.html", "public.url"]
  var didSetAny = false
  var lastError: OSStatus = noErr

  // Try URL schemes first
  for scheme in schemes {
    let status = LSSetDefaultHandlerForURLScheme(scheme as CFString, bid as CFString)
    if status == noErr {
      didSetAny = true
    } else {
      lastError = status
    }
  }

  // Also set common content types as a fallback on newer macOS versions
  for ct in contentTypes {
    let status = LSSetDefaultRoleHandlerForContentType(ct as CFString, LSRolesMask.all, bid as CFString)
    if status == noErr {
      didSetAny = true
    } else {
      lastError = status
    }
  }

  if !didSetAny {
    let message = "Failed to set default browser for http/https or content types. Last OSStatus: \(lastError)"
    throw NSError(domain: NSOSStatusErrorDomain, code: Int(lastError), userInfo: [NSLocalizedDescriptionKey: message])
  }
}

func listJSON() {
  let httpURL = URL(string: "http://example.com")!
  let httpsURL = URL(string: "https://example.com")!
  let httpApps = NSWorkspace.shared.urlsForApplications(toOpen: httpURL)
  let httpsApps = NSWorkspace.shared.urlsForApplications(toOpen: httpsURL)
  let allAppURLs = Array(Set(httpApps + httpsApps))

  let current = currentDefaultBundleId(for: "http")

  var seenBundleIds = Set<String>()
  var items: [[String: Any]] = []
  for appURL in allAppURLs {
    guard let b = Bundle(url: appURL),
          let bid = b.bundleIdentifier else { continue }
    if seenBundleIds.contains(bid) { continue }
    seenBundleIds.insert(bid)
    let name = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") ?? b.object(forInfoDictionaryKey: "CFBundleName")) as? String ?? bid
    items.append(["id": bid, "name": name, "isDefault": bid == current])
  }

  let data = try! JSONSerialization.data(withJSONObject: items, options: [])
  print(String(data: data, encoding: .utf8)!)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
  fputs("Usage: defbrowser.swift <bundle-id> | --list-json\n", stderr)
  exit(64)
}
if args[1] == "--list-json" { listJSON(); exit(0) }
do { try setDefault(args[1]); print("OK") } catch { fputs("\(error)\n", stderr); exit(1) }
