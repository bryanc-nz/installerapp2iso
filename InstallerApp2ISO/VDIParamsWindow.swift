//
//  VDIParamsWindow.swift
//  InstallerApp2ISO
//
//  Created by Bryan Christianson on 5/05/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//

import Foundation
import Cocoa

class VDIParamsWindow : NSWindowController {

	@IBOutlet weak var m_name: NSTextField!
	@IBOutlet weak var m_size: NSTextField!

	var m_parent: InstallToISOWindow!
	
	let MINDISKSIZE = 15.0
	let MAXDISKSIZE = 100000.0

	override func windowDidLoad()
	{
	}

	func setup()
	{
		if self.window == nil { return }
	}

	@IBAction func cancel(_ sender: Any)
	{
		closeDialog()
	}

	@IBAction func acceptParams(_ sender: Any)
	{
		let name = m_name.stringValue
		let size = m_size.doubleValue

		if name.count > 0,
		   size >= MINDISKSIZE,
		   size <= MAXDISKSIZE {

			main_async {
				[weak self] in
				self?.m_parent.runInstallerToVDI(name, size)
			}
			closeDialog()
		}
	}

	func runModal(parent: InstallToISOWindow)
	{
		m_parent = parent
		m_parent.window!.beginSheet(self.window!) {
			response in
		}
		NSApp.runModal(for: self.window!)
	}

	func closeDialog()
	{
		m_parent.window!.endSheet(self.window!)
		m_parent = nil
		NSApp.stopModal()
	}
}
