//
//  InstallToISOWindow.swift
//  InstallerApp2ISO
//
//  Created by Bryan Christianson on 13/04/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import Cocoa

extension InstallToISOWindow : NSWindowDelegate {
	func windowWillClose(_ notification: Notification)
	{
		if let app = NSApp.delegate as? AppDelegate {
			app.windowClosed(self)
		}
	}
}

class InstallToISOWindow : NSWindowController {
	enum Action: Int {
		case CREATE_ISO
		case CREATE_VDI
	}


	@IBOutlet weak var m_drop_target: DropView!
	@IBOutlet weak var m_path: NSTextField!
	@IBOutlet weak var m_busy: NSProgressIndicator!
	@IBOutlet weak var m_verbose: NSPopUpButton!
	@IBOutlet weak var m_dry_run: NSButton!
	@IBOutlet weak var m_choose_action: NSPopUpButton!
	@IBOutlet weak var m_perform_action: NSButton!
	@IBOutlet weak var m_cancel: NSButton!
	@IBOutlet weak var m_scrollview: NSScrollView!
	@IBOutlet weak var m_output: NSComboBox!
	@IBOutlet weak var m_output_choose: NSButton!
	@IBOutlet weak var m_show_in_finder: NSButton!

	var m_text: NSTextView! { return m_scrollview?.textView }

	var m_proc: Process!
	var m_installer_path = ""
	var m_tmpdir = ""
	var m_output_file = ""
	var m_log_file: URL!

	var isEmpty: Bool {
		return m_proc == nil &&
			   m_installer_path.isEmpty
	}

	var selectedAction: Action
	{
		let index = m_choose_action.indexOfSelectedItem
		guard let action = Action(rawValue: index) else {
			return Action.CREATE_ISO
		}
		return action
	}

	var apfsInstaller: Bool {
		if m_installer_path.isEmpty { return false }
		
		let url = URL(fileURLWithPath: m_installer_path + "/Contents/Info.plist")
		if let plist = NSDictionary(contentsOf: url) as? [String:Any],
		   let cfbundleversion = plist["CFBundleVersion"] as? String,
		   let version = Int(cfbundleversion),
		   version > 14000 {
			return true
		}
		return false
	}

	override func windowDidLoad()
	{
		m_drop_target.fileCheck = isValidInstaller
		m_drop_target.m_notify = setPath
		setupTextView(m_text)
		m_verbose.selectItem(at: 1)
		m_output.removeAllItems()

		let paths = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
		if let desktop = paths.first {
			updateOutputCombo(desktop.path)
		}

		if let app = NSApp.delegate as? AppDelegate {
			app.windowOpened(self)
		}
		enableControls()

		// no dry-run - script is broken
		m_dry_run.isHidden = true
		m_dry_run.integerValue = 0
	}

	func enableControls()
	{
		let enabled = (m_proc == nil)

		if !enabled && m_busy.isHidden {
			m_busy.startAnimation(self)
		}

		if enabled && !m_busy.isHidden {
			m_busy.stopAnimation(self)
		}

		m_path.isHidden = m_installer_path.isEmpty
		m_busy.isHidden = enabled

		m_choose_action.isEnabled = enabled
		m_perform_action.isEnabled = enabled && !m_installer_path.isEmpty

		if m_perform_action.isEnabled && selectedAction == .CREATE_VDI {
		 	m_perform_action.isEnabled = apfsInstaller
		}

		m_cancel.isEnabled = !enabled

		m_verbose.isEnabled = enabled
		m_output.isEnabled = enabled
		m_output_choose.isEnabled = enabled

		m_show_in_finder.isHidden = m_output_file.isEmpty
	}

	func saveLog()
	{
		guard let url = m_log_file else { return }
		let text = m_text.string
		try? text.write(to: url, atomically: true, encoding: .utf8)
	}

	@IBAction func saveDocumentAs(_ sender: Any)
	{
		guard let win = window else { return }
		m_log_file = nil

		let dialog = NSSavePanel()
		dialog.nameFieldStringValue = win.title + ".log"

		if (dialog.runModal() == NSApplication.ModalResponse.OK),
		   let url = dialog.url {
			m_log_file = url
			saveLog()
		}
	}

	@IBAction func saveDocument(_ sender: Any)
	{
		if m_log_file == nil {
			saveDocumentAs(sender)
			return
		}
		saveLog()
	}

	@IBAction func export(_ sender: Any)
	{
		var name = ""
		switch selectedAction {
		case .CREATE_ISO:
			name = "InstallerApp2ISO"
			break

		case .CREATE_VDI:
			name = "apfsvdi"
			break
		}

		guard let scriptURL = Bundle.main.url(forResource: name, withExtension: "sh") else { return }

		let dialog = NSSavePanel()
		dialog.nameFieldStringValue = name + ".sh"

		if (dialog.runModal() == NSApplication.ModalResponse.OK),
		   let url = dialog.url {
			try? FileManager.default.copyItem(at: scriptURL, to: url)
		}
	}

	@IBAction func showInFinder(_ sender: Any)
	{
		if m_output_file.isEmpty { return }
		NSWorkspace.shared.selectFile(m_output_file, inFileViewerRootedAtPath: m_output.stringValue)
	}

	@IBAction func outputChoose(_ sender: Any)
	{
		let dialog = NSOpenPanel()

		dialog.message = NSLocalizedString("Choose Output Folder", comment: "")
		dialog.showsResizeIndicator    = true
		dialog.showsHiddenFiles        = false
		dialog.canChooseDirectories    = true
		dialog.canCreateDirectories    = true
		dialog.allowsMultipleSelection = false
		dialog.allowedFileTypes        = nil
		dialog.treatsFilePackagesAsDirectories = false

		if (dialog.runModal() == NSApplication.ModalResponse.OK),
		   let url = dialog.url {
			updateOutputCombo(url.path)
		}
	}

	@IBAction func chooseAction(_ sender: Any)
	{
		var image: NSImage!

		switch selectedAction {
		case .CREATE_ISO:
			image = NSImage(named: "ISO")
			break

		case .CREATE_VDI:
			image = NSImage(named: "VDI")
			break
		}
		m_perform_action.image = image
		enableControls()
	}

	@IBAction func performAction(_ sender: Any)
	{
		switch selectedAction {
		case .CREATE_ISO:
			installerToISO()
			break

		case .CREATE_VDI:
			installerToVDI()
			break
		}
		enableControls()
	}

	@IBAction func cancel(_ sender: Any)
	{
		if m_proc != nil {
			m_proc.terminate()
			Execute.closePipe(process: m_proc)
			m_proc = nil
		}
		enableControls()
		addText("\n\n" + NSLocalizedString("CANCELLED by user", comment: "") + "\n\n")
	}

	func updateOutputCombo(_ path: String)
	{
		if path.isEmpty {
			return
		}

		m_output.stringValue = path
		let index = m_output.indexOfItem(withObjectValue: path)
		if index != NSNotFound {
			m_output.removeItem(at: index)
		}

		m_output.insertItem(withObjectValue: path, at: 0)
	}

	func setupTextView(_ view: NSTextView)
	{
		view.autoresizingMask =	[.width, .height]

		view.minSize = CGSize(width: 0, height: 0)
		view.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

		view.enclosingScrollView!.hasHorizontalScroller = true
		view.enclosingScrollView!.hasVerticalScroller = true

		view.isVerticallyResizable = true
		view.isHorizontallyResizable = true

		view.textContainer!.widthTracksTextView = false
		view.textContainer!.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

		view.font = NSFont.userFixedPitchFont(ofSize: NSFont.smallSystemFontSize)
		view.textColor = NSColor.textColor
		view.backgroundColor = NSColor.textBackgroundColor

		view.isEditable = false
	}

	func setTitle(_ title: String)
	{
		if title.isEmpty { return }
		window?.title = title
		m_log_file = nil
	}

	func setPath(_ path: String)
	{
		let url = URL(fileURLWithPath: path)
		m_path.stringValue = url.lastPathComponent
		setTitle(url.lastPathComponent)

		m_proc = nil
		m_installer_path = path
		m_output_file = ""
		m_drop_target.image = Bundle.icon(path)

		// add to recent documents menu
		NSDocumentController.shared.noteNewRecentDocumentURL(url)
		enableControls()
	}

	func tmpDirectory() -> String
	{
		var tmp = "/tmp"

		let paths = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
		guard let desktop = paths.first  else { return tmp }

		do {
			let temporaryDirectory = try FileManager.default.url(
						   for: .itemReplacementDirectory,
							in: .userDomainMask,
				appropriateFor: desktop,
						create: true
			)

			tmp = temporaryDirectory.path
			m_tmpdir = tmp
		} catch {
			// Handle the error.
		}
		return tmp
	}

	func removeTmpDirectory()
	{
		if m_tmpdir.isEmpty { return }
		let dir = m_tmpdir
		m_tmpdir = ""

		do {
			try FileManager.default.removeItem(atPath: dir)
		} catch {
			Swift.print("Error deleting temporary folder:", dir)
		}
	}

	func installerToVDI()
	{
		let params = VDIParamsWindow(windowNibName: "VDIParamsWindow")
		params.setup()
		params.runModal(parent: self)
	}

	func runInstallerToVDI(_ name: String, _ size: Double)
	{
		addText("", append: false)

		var env = ProcessInfo.processInfo.environment
		env["TERM"] = "vt220" // conversion script requires a valid TERM

		guard let script = Bundle.main.path(forResource: "apfsvdi", ofType: "sh") else { return }

		var cmd = "\"" + script + "\""
		cmd += " -i \"" + m_installer_path + "\""
		cmd += " -o \"" + m_output.stringValue + "\""
		cmd += " -t \"" + tmpDirectory() + "\""
		cmd += " -y"
		cmd += " --name \"" + name + "\""
		cmd += " --size \"" + String(format: "%.0f", size + 0.5) + "\""

		addText(NSLocalizedString("Command: ", comment: "") + cmd + "\n")
		let args = ["-c", cmd]

		executeBashScript(args: args, env: env)
	}

	func installerToISO()
	{
		addText("", append: false)

		var env = ProcessInfo.processInfo.environment
		env["TERM"] = "vt220" // conversion script requires a valid TERM
		env["AUTH_PROMPT"] = "InstallerApp2ISO.sh " + NSLocalizedString("wants to make changes.", comment: "")

		let verbosity = m_verbose.indexOfSelectedItem
		let privhelper = Bundle.main.bundlePath + "/Contents/MacOS/privileged"

		guard let script = Bundle.main.path(forResource: "InstallerApp2ISO", ofType: "sh") else { return }
		
		var cmd = "\"" + script + "\""					// absolute path to script
		cmd += " -i \"" + m_installer_path + "\"" +		// MY_INSTAPP
			   " -o \"" + m_output.stringValue + "\"" +	// MY_DESTDIR
			   " -t \"" + tmpDirectory() + "\"" +		// MY_TEMPDIR
			   " -p \"" + privhelper + "\"" +			// MY_PRIVILEGED
			   " -y" +									// MY_IGNOREPROMPT
			   " -v " + String(verbosity)				// MY_VERBOSE

		if m_dry_run.integerValue != 0 {
			cmd += " -d"									// MY_DRYRUN
		}

		addText(NSLocalizedString("Command: ", comment: "") + cmd + "\n")
		let args = ["-c", cmd]

		executeBashScript(args: args, env: env)
	}

	func executeBashScript(args: [String], env: [String : String])
	{
		var hasProgress = false
		m_output_file = ""

		m_proc = Execute.readPipe("/bin/bash", args: args, env: env) {
			[weak self] text_in in
			if let text = text_in {
				guard let this = self else { return }

				let t = this.stripTerminalEscape(text)
				if t.hasPrefix("Completed:") {
					if hasProgress {
						this.deleteLastLine()
					}
					hasProgress = true
				}
				this.addText(t)
				return
			}

			// nil text implies we're finished
			main_async {
				[weak self] in
				guard let this = self else { return }

				this.m_proc = nil
				this.setOutputFileName()
				this.enableControls()
				NSApp.activate(ignoringOtherApps: true)
				this.removeTmpDirectory()
			}
		}
	}

	func deleteLastLine()
	{
		main_async {
			[weak self] in
			guard let this = self else { return }

			var lines = this.m_text.string.asLines
			if lines.count > 0 {
				lines.remove(at: lines.count - 1)
				var text = ""
				for line in lines {
					text += line + "\n"
				}
				this.m_text.string = text
			}
		}
	}

	func setOutputFileName()
	{
		let lines = m_text.string.asLines
		for line in lines.reversed() { // name is at end of text - reverse traversal is faster
			let t = line.trim()
			if t.contains("-->") {
				switch selectedAction {
				case .CREATE_ISO:
					let a = t.split(separator: " ")
					if let name = a.last {
						m_output_file = String(name)
						return
					}
					break

				case .CREATE_VDI:
					let a = t.split(separator: ":")
					if let name = a.last {
						m_output_file = String(name).trim()
						return
					}
					break
				}
			}
		}
	}

	var m_stripnext = 0
	func stripTerminalEscape(_ text: String) -> String
	{
		/*
			terminal escapes are of the format: esc [ x
			get rid of them.

			NB - the escape sequence may cross a text buffer boundary - we need global state
		*/

		let esc = Character("\u{1b}")
		var s = ""

		for c in text {
			if c == esc {
				m_stripnext = 2
			} else if m_stripnext > 0 {
				m_stripnext -= 1
			} else {
				s += String(c)
			}
		}

		return s
	}

	func addText(_ text: String, append: Bool = true)
	{
		if text.count == 0 && append { return }
		
		main_async {
			[weak self] in
			guard let this = self else { return }

			if append {
				this.m_text.string += text
			} else {
				this.m_text.string = text
			}
			this.m_text.scrollToEnd()
		}
	}
}
