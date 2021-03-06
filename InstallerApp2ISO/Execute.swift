//
//  Exececute.swift
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

class Execute {
	static func shell(_ cmd: String) -> String?
	{
		let sh = "/bin/sh"
		let args = ["-c", cmd]

		let proc = Process()
		proc.launchPath = sh
		proc.arguments = args

		let outpipe = Pipe()
		proc.standardOutput = outpipe
		let errpipe = Pipe()
		proc.standardError = errpipe
		proc.launch()

		let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
		guard let s = String(data: outdata, encoding: .utf8) else { return nil }

		proc.waitUntilExit()

		return s
	}
	static func checkCodeValidity()
	{
		/*
			https://eclecticlight.co/2019/05/11/checking-your-apps-own-signature/
		*/

		let url = Bundle.main.bundleURL

		var staticCode: SecStaticCode? = nil
		let err = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
		if err == OSStatus(noErr),
		   let code = staticCode {
			//let checkFlags = SecCSFlags(rawValue: kSecCSCheckNestedCode)
			let checkFlags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckNestedCode)
			let secReq: SecRequirement? = nil
			var secErr: Unmanaged<CFError>?

			let csErr = SecStaticCodeCheckValidityWithErrors(code, checkFlags, secReq, &secErr)
			if csErr != errSecSuccess {
				exit(1)
			}
			if secErr != nil {
				secErr?.release()
			}
		}
	}

	static func closePipe(process: Process?)
	{
		guard let proc = process else { return }

		if let channel = proc.standardOutput,
		   let pipe = channel as? Pipe {
			pipe.fileHandleForReading.readabilityHandler = nil
		}

		if let channel = proc.standardError,
		   let pipe = channel as? Pipe {
			pipe.fileHandleForReading.readabilityHandler = nil
		}

		if let channel = proc.standardInput,
		   let pipe = channel as? Pipe {
			pipe.fileHandleForWriting.closeFile()
		}

		proc.cleanup()
	}

	static func readPipe(_ prog: String, args: [String], env: [String : String]? = nil, reader: @escaping ((String?)->Void)) -> Process?
	{
		func endProcess(process: Process)
		{
			reader(nil)
			closePipe(process: process)
		}

		var failed = false
		let proc = Process()
		proc.arguments = args
		if env != nil {
			proc.environment = env
		}

		let pipe = Pipe()
		proc.standardOutput = pipe
		proc.standardError = pipe

		let wPipe = Pipe()
		proc.standardInput = wPipe
		
		pipe.fileHandleForReading.readabilityHandler = {
			handle in
			let data = handle.availableData
			if data.count == 0 {
				endProcess(process: proc)
			} else if let text = String(data: data, encoding: String.Encoding.utf8) {
				if text.count == 0 {
					endProcess(process: proc)
				} else {
					reader(text)
				}
			} else {
				endProcess(process: proc)
			}
		}

		if #available(OSX 10.13, *) {
			let url = URL(fileURLWithPath: prog)
			proc.executableURL = url
			do {
				try proc.run()
			} catch {
				failed = true
				reader("Exception caught running " + prog + ": " + error.localizedDescription)
			}
		} else {  // pre 10.13
			proc.terminationHandler = {
				proc in
				endProcess(process: proc)
			}

			proc.launchPath = prog
			proc.launch()
		}

		if failed { return nil }
		return proc
	}
}
