//
//  DropView.swift
//  InstallerApp2ISO
//
//  Created by Bryan Christianson on 9/12/18.
//  Copyright © 2018 Bryan Christianson. All rights reserved.
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

/*
	Based on:
	https://stackoverflow.com/questions/31657523/os-x-swift-get-file-path-using-drag-and-drop
*/

class DropView: NSImageView {
    var m_file_path: String?
    var m_notify: ((String)->Void)!
    var m_check_type: ((String)->Bool)!

    var fileCheck: ((String)->Bool)? {
    	get { return m_check_type }
    	set { m_check_type = newValue }
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)

        self.wantsLayer = true
        self.layer?.backgroundColor = background(false)

		if #available(OSX 10.13, *) {
        	registerForDraggedTypes([NSPasteboard.PasteboardType.URL,
        							 NSPasteboard.PasteboardType.fileURL])
        } else {
        	registerForDraggedTypes([NSPasteboard.PasteboardType(kUTTypeURL as String),
        							 NSPasteboard.PasteboardType(kUTTypeFileURL as String)])
		}
    }

    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        // Drawing code here.
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
    {
        if checkFileType(sender) == true {
            self.layer?.backgroundColor = background(true)
            return .copy
        } else {
            return NSDragOperation()
        }
    }

    fileprivate func checkFileType(_ drag: NSDraggingInfo) -> Bool
    {
    	guard let path = drag.filePath else { return false }
        guard let checker = m_check_type else { return false }

		return checker(path)
    }

    fileprivate func background(_ hilite: Bool) -> CGColor
    {
    	var cgColor: CGColor!

    	if hilite {
    		if #available(OSX 10.10, *) {
    			cgColor = NSColor.systemBlue.cgColor
			} else {
    			cgColor = NSColor.blue.cgColor
			}
    	} else {
    		if #available(OSX 10.10, *) {
    			cgColor = NSColor.systemGray.cgColor
    		} else {
    			cgColor = NSColor.gray.cgColor
			}
    	}
    	return cgColor
    }

    override func draggingExited(_ sender: NSDraggingInfo?)
    {
        self.layer?.backgroundColor = background(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo)
    {
        self.layer?.backgroundColor = background(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool
    {
    	guard let path = sender.filePath else { return false }
       	self.m_file_path = path
		self.image = Bundle.icon(path)

		if let notify = m_notify {
			main_async {
				notify(path)
			}
		}
        return true
    }
}

extension NSDraggingInfo {
	var filePath: String! {
		let pbType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
        if let board = self.draggingPasteboard.propertyList(forType: pbType) as? NSArray,
		   let path = board[0] as? String {
			return path
		}
        return nil
	}
}
