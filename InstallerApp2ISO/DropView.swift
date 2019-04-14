//
//  DropView.swift
//  MachPortLeak
//
//  Created by Bryan Christianson on 9/12/18.
//  Copyright © 2018 Bryan Christianson. All rights reserved.
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
        self.layer?.backgroundColor = NSColor.systemGray.cgColor

        registerForDraggedTypes([
								 NSPasteboard.PasteboardType.URL,
        						 NSPasteboard.PasteboardType.fileURL
								])
    }

    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        // Drawing code here.
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
    {
        if checkFileType(sender) == true {
            self.layer?.backgroundColor = NSColor.systemBlue.cgColor
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

    override func draggingExited(_ sender: NSDraggingInfo?)
    {
        self.layer?.backgroundColor = NSColor.systemGray.cgColor
    }

    override func draggingEnded(_ sender: NSDraggingInfo)
    {
        self.layer?.backgroundColor = NSColor.systemGray.cgColor
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
