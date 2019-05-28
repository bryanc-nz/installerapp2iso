//
//  Files.swift
//  InstallerApp2ISO
//
//  Created by Bryan Christianson on 28/05/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//

import Foundation

class Files {
	static func appSupportPath() -> String?
	{
		var path: String!
		let manager = FileManager.default

		do {
				let appsupport = try manager.url(
											for: FileManager.SearchPathDirectory.applicationSupportDirectory,
											in: FileManager.SearchPathDomainMask.userDomainMask,
											appropriateFor: nil,
											create: false)

				let appsupport_path = appsupport.path

				try manager.createDirectory(atPath: appsupport_path, withIntermediateDirectories: true, attributes: nil)

				path = appsupport_path
		} catch let error as NSError {
			let msg = "appSupportPath: " + error.localizedDescription
			NSLog(msg)
		}

		return path
	}

	static func copyResourceFile(_ file: String, type: String, dstdir: String, overwrite: Bool) -> Int
	{
		let manager = FileManager.default
		let dst_path = dstdir + "/" + file + "." + type

		do {
			if !fileExists(dst_path) || overwrite {
				guard let src = Bundle.main.path(forResource: file, ofType: type) else {
					let msg = "copyResourceFile: Cannot find " + file + "." + type
					NSLog(msg)
					return -1
				}
				try manager.copyItem(atPath: src, toPath: dst_path)
				return 0
			}

		} catch let error as NSError {
			let msg = "copyResourceFile: " + error.localizedDescription
			NSLog(msg)
		}
		return -1
	}

	static func fileExists(_ path: String) -> Bool
	{
		return FileManager.default.fileExists(atPath: path)
	}
}
