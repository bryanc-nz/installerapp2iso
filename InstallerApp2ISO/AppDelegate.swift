//
//  AppDelegate.swift
//  InstallToISO
//
//  Created by Bryan Christianson on 13/04/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//

import Cocoa

func isValidInstaller(_ path: String) -> Bool
{
	func fileExists(_ path: String) -> Bool
	{
		return FileManager.default.fileExists(atPath: path)
	}

	return fileExists(path + "/Contents/version.plist") &&
		   fileExists(path + "/Contents/SharedSupport/InstallESD.dmg")
}

extension AppDelegate : NSOpenSavePanelDelegate
{
	func panel(_ sender: Any, shouldEnable url: URL) -> Bool
	{
		// need to allow directories
		var isDir: ObjCBool = false
		if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
			return isDir.boolValue || isValidInstaller(url.path)
		}
		return false
	}
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	var m_windows = Set<InstallToISOWindow>()

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		newWindow("")
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ theApplication: NSApplication) -> Bool
	{
		return true
	}

	func application(_ sender: NSApplication, openFile filename: String) -> Bool
	{
		if !isValidInstaller(filename) {
			return false
		}
		
		let url = URL(fileURLWithPath: filename)
		openWindow(forURL: url)
		return true
	}

	@IBAction func newDocument(_ sender: Any)
	{
		newWindow("")
	}

	@IBAction func openDocument(_ sender: Any)
	{
		let dialog = NSOpenPanel()

		// delegate to filter out non-executable files
		dialog.delegate = self

		dialog.message = NSLocalizedString("Choose a macOS Installer", comment: "")
		dialog.showsResizeIndicator    = true
		dialog.showsHiddenFiles        = false
		dialog.canChooseDirectories    = false
		dialog.canCreateDirectories    = false
		dialog.allowsMultipleSelection = false
		dialog.allowedFileTypes        = nil
		dialog.treatsFilePackagesAsDirectories = false

		if (dialog.runModal() == NSApplication.ModalResponse.OK),
		   let url = dialog.url {
		   	openWindow(forURL: url)
			NSDocumentController.shared.noteNewRecentDocumentURL(url)
		}
	}

	func openWindow(forURL url: URL)
	{
	   	let name = url.lastPathComponent
	   	for window in m_windows {
	   		if name == window.window?.title {
				window.showWindow(self)
				return
	   		}
	   	}

		if m_windows.count == 1,
		   let window = m_windows.first,
		   window.isEmpty {
			window.setTitle(name)
			window.setPath(url.path)
		} else {
			let window = newWindow(name)
			window.setPath(url.path)
		}
	}

	@discardableResult
	func newWindow(_ title: String) -> InstallToISOWindow
	{
		let window = InstallToISOWindow(windowNibName: "InstallToISOWindow")
		window.showWindow(self)
		window.setTitle(title)
		return window
	}

	func windowClosed(_ window: InstallToISOWindow)
	{
		if m_windows.contains(window) {
			m_windows.remove(window)
		}
	}

	func windowOpened(_ window: InstallToISOWindow)
	{
		if !m_windows.contains(window) {
			m_windows.insert(window)
		}
	}
}
