//
//  InstallToISOWindow.swift
//  InstallToISO
//
//  Created by Bryan Christianson on 13/04/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
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

	@IBOutlet weak var m_drop_target: DropView!
	@IBOutlet weak var m_path: NSTextField!
	@IBOutlet weak var m_busy: NSProgressIndicator!
	@IBOutlet weak var m_verbose: NSPopUpButton!
	@IBOutlet weak var m_dry_run: NSButton!
	@IBOutlet weak var m_create_iso: NSButton!
	@IBOutlet weak var m_cancel: NSButton!
	@IBOutlet weak var m_scrollview: NSScrollView!
	@IBOutlet weak var m_output: NSComboBox!
	@IBOutlet weak var m_output_choose: NSButton!

	var m_text: NSTextView! { return m_scrollview?.textView }

	var m_proc: Process!
	var m_installer_path = ""
	var m_tmpdir = ""

	var isEmpty: Bool {
		return m_proc == nil &&
			   m_installer_path.isEmpty
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

		m_create_iso.isEnabled = enabled && !m_installer_path.isEmpty
		m_cancel.isEnabled = !enabled

		m_verbose.isEnabled = enabled
		m_output.isEnabled = enabled
		m_output_choose.isEnabled = enabled
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

	@IBAction func createISO(_ sender: Any)
	{
		installerToISO()
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
	}

	func setPath(_ path: String)
	{
		let url = URL(fileURLWithPath: path)
		m_path.stringValue = url.lastPathComponent
		setTitle(url.lastPathComponent)

		m_proc = nil
		m_installer_path = path
		m_drop_target.image = Bundle.icon(path)

		// add to recent documents menu
		NSDocumentController.shared.noteNewRecentDocumentURL(url)
		//installerToISO()
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
		Swift.print(cmd)
		let args = ["-c", cmd]

		m_proc = Execute.readPipe("/bin/bash", args: args, env: env) {
			[weak self] text in
			if text == "__EOF__" {
				main_async {
					[weak self] in
					if let this = self {
						this.m_proc = nil
						this.enableControls()
						NSApp.activate(ignoringOtherApps: true)
						this.removeTmpDirectory()
					}
				}
				return
			}
			//Swift.print(text)
			self?.addText(text)
		}
	}

	func addText(_ text: String, append: Bool = true)
	{
		main_async {
			[weak self] in
			if let this = self {
				if append {
					this.m_text.string += text
				} else {
					this.m_text.string = text
				}
				this.m_text.scrollToEnd()
			}
		}
	}
}
