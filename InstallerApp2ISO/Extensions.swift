//
//  Extensions.swift
//  InstallToISO
//
//  Created by Bryan Christianson on 13/04/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//

import Foundation
import Cocoa

public extension String {
    func trim() -> String
	{
		let whitespacechars = " \n\r\t"
		let whitespacecharset = CharacterSet(charactersIn: whitespacechars)
        return self.trimmingCharacters(in: whitespacecharset)
    }

	var asLines: [String]
	{
		var lines = [String]()
		self.enumerateLines {
			line, stop in
			lines.append(line)
		}
		return lines
	}
}

public extension NSTextView {
	func scrollToStart()
	{
		let range = NSRange(location: 0, length: 0)
		self.setSelectedRange(range)
		self.scrollRangeToVisible(range)
	}

	func scrollToEnd()
	{
		let range = NSRange(location: self.string.count, length: 0)
		self.setSelectedRange(range)
		self.scrollRangeToVisible(range)
	}
}

public extension NSScrollView {
	var textView: NSTextView {
		return self.contentView.documentView as! NSTextView
	}
}

public extension Process {
	func cleanup()
	{
		if self.isRunning {
			self.terminate()
		}
		self.waitUntilExit()
	}
}

public extension Bundle {
	static func appVersionName() -> String
	{
		func plistinfo(_ key: String) -> String
		{
			if let bundle = CFBundleGetMainBundle(),
			   let val = CFBundleGetValueForInfoDictionaryKey(bundle, key as CFString?) as? String {
				return val
			}
			return ""
		}

		let name			= plistinfo("CFBundleName")
		let shortversion	= plistinfo("CFBundleShortVersionString")
		let version			= plistinfo("CFBundleVersion")

		return name + "-" + shortversion + "(" + version + ")"
	}

	static func icon(_ bundlepath: String) -> NSImage?
	{
		if bundlepath.isEmpty {
			return nil
		}

		let image = NSWorkspace.shared.icon(forFile: bundlepath)
		if image.isValid {
			return image
		}
		return nil
	}

	static func path(_ bundleID: String) -> String
	{
		if let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) {
			return path
		}

		return ""
	}

	static func launch(_ bundleID: String) -> Bool
	{
		return NSWorkspace.shared.launchApplication(
								withBundleIdentifier: bundleID,
					  additionalEventParamDescriptor: nil,
									launchIdentifier: nil)
	}
}

// http://blog.benjamin-encz.de/post/main-queue-vs-main-thread/

private let mainQueueKey = DispatchSpecificKey<Void>()
private let mainQueueValue = DispatchSpecificKey<Void>()

private struct _mainqueue {
	var m_main: Dispatch.DispatchQueue!

	init()
	{
		m_main = DispatchQueue.main
		m_main.setSpecific(key: mainQueueKey, value: ())
	}

	func isMain() -> Bool
	{
		return DispatchQueue.getSpecific(key: mainQueueKey) != nil
	}

	func async(_ closure: @escaping () -> Void)
	{
		if isMain() {
			closure()
			return
		}
		m_main.async(execute: closure)
	}

	func sync(_ closure: () -> Void)
	{
		if isMain() {
			closure()
			return
		}
		m_main.sync(execute: closure)
	}
}
private let mainqueue = _mainqueue()

public func IsMainQueue() -> Bool
{
	return mainqueue.isMain()
}

public func main_sync(_ closure: () -> Void)
{
	mainqueue.sync(closure)
}

public func main_async(_ closure: @escaping () -> Void)
{
	mainqueue.async(closure)
}
