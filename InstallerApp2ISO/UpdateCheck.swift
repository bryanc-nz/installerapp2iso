//
//  UpdateCheck.swift
//  InstallerApp2ISO
//
//  Created by Bryan Christianson on 6/06/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//

import Foundation
import Cocoa

extension UpdateCheckWindow : NSWindowDelegate {
	func windowWillClose(_ notification: Notification)
	{
		UpdateCheckWindow.instance = nil
	}
}

class UpdateCheckWindow: NSWindowController {
	static var instance: UpdateCheckWindow!

	@IBOutlet weak var m_heading: NSTextField!
	@IBOutlet weak var m_installed: NSTextField!
	@IBOutlet weak var m_available: NSTextField!
	@IBOutlet weak var m_lastchecked: NSTextField!
	@IBOutlet weak var m_autocheck: NSButton!
	@IBOutlet weak var m_frequency: NSPopUpButton!

	override func windowDidLoad()
	{
		UpdateCheckWindow.instance = self

		m_heading.stringValue = Bundle.appName()
		m_installed.stringValue = Bundle.appVersion()
		m_available.stringValue = ""

		showChecker()
	}

	func showChecker()
	{
		let checker = UpdateCheck.shared

		let lastcheck = checker.lastCheck
		if lastcheck < 1.0 {
			m_lastchecked.stringValue = NSLocalizedString("Never", comment: "")
		} else {
			let date = Date(timeIntervalSinceReferenceDate: lastcheck)
			let dateFormatter = DateFormatter()
			dateFormatter.dateStyle = .medium
			dateFormatter.timeStyle = .medium
			m_lastchecked.stringValue = dateFormatter.string(from: date)
		}

		m_autocheck.integerValue = checker.autoCheck ? 1 : 0
		if checker.frequency != .NEVER {
			m_frequency.selectItem(at: checker.frequency.rawValue - 1)
		}

		m_frequency.isEnabled = m_autocheck.integerValue != 0
		m_available.stringValue = checker.available
	}

	@IBAction func checkNow(_ sender: Any)
	{
		let checker = UpdateCheck.shared
		checker.checkNow()
	}

	@IBAction func autoCheck(_ sender: Any)
	{
		let checker = UpdateCheck.shared
		checker.autoCheck = m_autocheck.integerValue != 0
		showChecker()
	}

	@IBAction func changeFrequency(_ sender: Any)
	{
		let checker = UpdateCheck.shared
		guard let freq: UpdateCheck.checkFrequency = UpdateCheck.checkFrequency(rawValue: m_frequency.indexOfSelectedItem + 1)
		else { return }

		checker.frequency = freq
		showChecker()
	}
}

class UpdateCheck {
	static var shared = UpdateCheck()

	enum checkFrequency: Int {
		case NEVER		= 0
		case HOURLY		= 1
		case DAILY		= 2
		case WEEKLY		= 3
		case MONTHLY	= 4
	}

	var m_version_plist = ""
	var m_site = ""

	var m_available = ""

	var m_frequency = checkFrequency.WEEKLY
	var m_lastcheck = 0.0

	var m_timer: Timer!

	var lastCheck: Double { return m_lastcheck }
	var available: String { return m_available }

	var frequency: checkFrequency {
		get {return m_frequency }
		set {
			m_frequency = newValue
			stopChecker()
			startChecker()
			saveDefaults()
		}
	}

	var autoCheck: Bool {
		get { return m_frequency != .NEVER }
		set {
			m_frequency = newValue ? .DAILY : .NEVER
			stopChecker()
			startChecker()
			saveDefaults()
		}
	}

	init()
	{
		loadDefaults()
	}

	func setup(version: String, site: String)
	{
		m_version_plist = version
		m_site = site
	}

	func loadDefaults()
	{
		let defaults = UserDefaults.standard

		if defaults.object(forKey: "updateFrequency") == nil {
			m_frequency = .WEEKLY
		} else {
			let freq = defaults.integer(forKey: "updateFrequency")
			if freq >= 0 && freq <= checkFrequency.MONTHLY.rawValue {
				m_frequency = checkFrequency(rawValue: freq)!
			}
		}

		m_lastcheck = defaults.double(forKey: "lastcheck")

		if let s = defaults.string(forKey: "available") {
			m_available = s
		}
	}

	func saveDefaults()
	{
		let defaults = UserDefaults.standard
		defaults.set(m_lastcheck, forKey: "lastcheck")
		defaults.set(m_frequency.rawValue, forKey: "updateFrequency")
		defaults.set(m_available, forKey: "available")
	}

	func startChecker()
	{
		guard let interval = freqToInterval() else {
			stopChecker()
			return
		}

		let now = Date().timeIntervalSinceReferenceDate
		if now - m_lastcheck > interval {
			checkNow()
		}

		m_timer = Timer.scheduledTimer(timeInterval: interval,
											 target: self,
										   selector: #selector(self.runTimer),
										   userInfo: nil,
										    repeats: true)
	}

	@objc
	func runTimer(timer: Timer)
	{
		guard let interval = freqToInterval() else {
			stopChecker()
			return
		}

		let now = Date().timeIntervalSinceReferenceDate
		if now - m_lastcheck > interval {
			checkNow()
		}
	}

	func stopChecker()
	{
		if let timer = m_timer {
			timer.invalidate()
			m_timer = nil
		}
	}

	func freqToInterval() -> Double?
	{
		var interval = 0.0
		switch m_frequency {
		case .NEVER:
			return nil

		case .HOURLY:
			interval = 60 * 60
			break

		case .DAILY:
			interval = 60 * 60 * 24
			break

		case .WEEKLY:
			interval = 60 * 60 * 24 * 7
			break

		case .MONTHLY:
			interval = 60 * 60 * 24 * 7 * 4
			break
		}
		return interval
	}

	func checkNow()
	{
		m_lastcheck = Date().timeIntervalSinceReferenceDate

		main_async {
			[weak self] in
			guard let this = self else { return }

			this.saveDefaults()
			if let win = UpdateCheckWindow.instance {
				win.showChecker()
			}
		}

		let plistVersionKey = "CFBundleShortVersionString"

		func versionValue(_ version: String) -> Int?
		{
			var val = 0
			if let a = version.split(".") {
				for comp in a {
					guard let i = Int(comp) else { return nil }
					val = val * 1000 + i
				}
			}
			return val
		}

		let myVersion = Bundle.appVersion()
		if myVersion.isEmpty { return }

		guard let myValue = versionValue(myVersion) else { return }

		// load version from web site
		guard let url = URL(string: m_version_plist) else { return }
		var request = URLRequest(url: url,
						 cachePolicy: .reloadIgnoringLocalCacheData,
					 timeoutInterval: 30.0)

		request.httpMethod = "GET"
		request.addValue(Bundle.appVersionName(), forHTTPHeaderField: "User-Agent");

		let task = URLSession.shared.dataTask(with: request) {
			data, response, error in
			if let error = error {
			#if DEBUG
				Swift.print("error:", error.localizedDescription)
			#endif
				return
			}
			
			guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
				return
			}

			if let mimeType = httpResponse.mimeType,
			   ((mimeType == "text/xml") || (mimeType == "text/plain")),
			   let theData = data {
			   	do {
			   		guard let versionplist = try PropertyListSerialization.propertyList(from: theData,
			   																		 options: [],
			   																		  format: nil) as? NSDictionary
			   		else { return }

			   		guard let version = versionplist[plistVersionKey] as? String else { return }
			   		main_async {
						[weak self] in
						guard let this = self else { return }
			   			this.m_available = version
			   			this.saveDefaults()

						if let win = UpdateCheckWindow.instance {
							win.showChecker()
						}
					}

			   		guard let val = versionValue(version) else { return }
					if val <= myValue { return }

					main_async {
						[weak self] in
						guard let this = self else { return }
						this.promptNewVersion(myVersion, version)
					}

			   	} catch {
			   		return
			   	}
			}
		}
		task.resume()
	}

	func promptNewVersion(_ current: String, _ latest: String)
	{
		let name = Bundle.appName()

		let alert = NSAlert()

		alert.addButton(withTitle: NSLocalizedString("Download", comment: ""))
		alert.addButton(withTitle: NSLocalizedString("Ignore", comment: ""))

		alert.messageText = NSLocalizedString("A newer version of", comment: "")
							+ " "
							+ name
							+ " "
							+ NSLocalizedString("is available.", comment: "")

		var msg = ""
		msg += NSLocalizedString("You have version", comment: "") + ": " + current
		msg += "\n"
		msg += NSLocalizedString("Newer version", comment: "") + ": " + latest
		alert.informativeText = msg

		let response = alert.runModal()
		switch response {
		case .alertFirstButtonReturn:
			if let url = URL(string: m_site) {
				NSWorkspace.shared.open(url)
			}
			break

		case .alertSecondButtonReturn:
			return

		default:
			return
		}
	}
}
