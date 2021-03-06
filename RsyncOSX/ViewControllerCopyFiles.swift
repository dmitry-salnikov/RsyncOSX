//
//  ViewControllerCopyFiles.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 12/09/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable syntactic_sugar line_length

import Foundation
import Cocoa

protocol setIndex: class {
    func setIndex(index: Int)
}

protocol getSource: class {
    func getSource(index: Int)
}

class ViewControllerCopyFiles: NSViewController {

    // Object to hold search data
    var copyFiles: CopyFiles?
    var index: Int?
    var rsync: Bool = false
    var estimated: Bool = false
    weak var indexDelegate: GetSelecetedIndex?

    @IBOutlet weak var numberofrows: NSTextField!
    @IBOutlet weak var server: NSTextField!
    @IBOutlet weak var rcatalog: NSTextField!

    // Information about rsync output
    // self.presentViewControllerAsSheet(self.ViewControllerInformation)
    lazy var viewControllerInformation: NSViewController = {
        return (self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "StoryboardInformationCopyFilesID")) as? NSViewController)!
    }()

    // Source for CopyFiles
    // self.presentViewControllerAsSheet(self.ViewControllerAbout)
    lazy var viewControllerSource: NSViewController = {
        return (self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue:
            "CopyFilesID")) as? NSViewController)!
    }()

     // Set localcatalog to filePath
    @IBAction func copyToIcon(_ sender: NSButton) {
        _ = FileDialog(requester: .copyFilesTo)
    }

    // Abort button
    @IBAction func abort(_ sender: NSButton) {
        self.working.stopAnimation(nil)
        guard self.copyFiles != nil else {
            return
        }
        self.copyFiles!.abort()
    }

    @IBOutlet weak var tableViewSelect: NSTableView!
    // Array to display in tableview
    fileprivate var filesArray: [String]?
    // Present the commandstring
    @IBOutlet weak var commandString: NSTextField!
    @IBOutlet weak var remoteCatalog: NSTextField!
    @IBOutlet weak var localCatalog: NSTextField!
    // Progress indicator
    @IBOutlet weak var working: NSProgressIndicator!
    @IBOutlet weak var workingRsync: NSProgressIndicator!
    // Search field
    @IBOutlet weak var search: NSSearchField!
    @IBOutlet weak var copyButton: NSButton!
    // Select source button
    @IBOutlet weak var selectButton: NSButton!

    // Do the work
    @IBAction func copy(_ sender: NSButton) {
        if self.remoteCatalog.stringValue.isEmpty || self.localCatalog.stringValue.isEmpty {
            Alerts.showInfo("From: or To: cannot be empty!")
        } else {
            if self.copyFiles != nil {
                self.rsync = true
                self.workingRsync.startAnimation(nil)
                if self.estimated == false {
                    self.copyFiles!.executeRsync(remotefile: remoteCatalog!.stringValue, localCatalog: localCatalog!.stringValue, dryrun: true)
                    self.copyButton.title = "Execute"
                    self.estimated = true
                } else {
                    self.workingRsync.startAnimation(nil)
                    self.copyFiles!.executeRsync(remotefile: remoteCatalog!.stringValue, localCatalog: localCatalog!.stringValue, dryrun: false)
                    self.estimated = false
                }
            } else {
                Alerts.showInfo("Please select a ROW in Execute window!")
            }
        }
    }

    // Getting index from Execute View
    @IBAction func getIndex(_ sender: NSButton) {
        self.copyFiles = nil
        if let index = self.index {
            self.copyFiles = CopyFiles(index: index)
            self.working.startAnimation(nil)
            self.displayRemoteserver(index: index)
        } else {
            // Reset search data
            self.resetCopySource()
            // Get Copy Source
            self.presentViewControllerAsSheet(self.viewControllerSource)
        }
    }

    @IBAction func reset(_ sender: NSButton) {
        self.resetCopySource()
    }

    // Reset copy source
    fileprivate func resetCopySource() {
        // Empty tabledata
        self.index = nil
        self.filesArray = nil
        globalMainQueue.async(execute: { () -> Void in
            self.tableViewSelect.reloadData()
        })
        self.displayRemoteserver(index: nil)
        self.remoteCatalog.stringValue = ""
        self.selectButton.title = "Get source"
        self.rsync = false
    }

    fileprivate func displayRemoteserver(index: Int?) {
        guard index != nil else {
            self.server.stringValue = ""
            self.rcatalog.stringValue = ""
            self.selectButton.title = "Get source"
            return
        }
        let hiddenID = Configurations.shared.gethiddenID(index: index!)
        globalMainQueue.async(execute: { () -> Void in
            self.server.stringValue = Configurations.shared.getResourceConfiguration(hiddenID, resource: .offsiteServer)
            self.rcatalog.stringValue = Configurations.shared.getResourceConfiguration(hiddenID, resource: .remoteCatalog)
        })
        self.selectButton.title = "Get files"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Setting reference to ViewObject
        Configurations.shared.viewControllerCopyFiles = self
        self.tableViewSelect.delegate = self
        self.tableViewSelect.dataSource = self
        // Progress indicator
        self.working.usesThreadedAnimation = true
        self.workingRsync.usesThreadedAnimation = true
        self.search.delegate = self
        self.localCatalog.delegate = self
        // Double click on row to select
        self.tableViewSelect.doubleAction = #selector(self.tableViewDoubleClick(sender:))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let pvc = Configurations.shared.viewControllertabMain as? ViewControllertabMain {
            self.indexDelegate = pvc
            self.index = self.indexDelegate?.getindex()
            if let index = self.index {
                self.displayRemoteserver(index: index)
            }
        }
        self.copyButton.title = "Estimate"
        if let restorePath = Configurations.shared.restorePath {
            self.localCatalog.stringValue = restorePath
        } else {
            self.localCatalog.stringValue = ""
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.resetCopySource()
    }

    @objc(tableViewDoubleClick:) func tableViewDoubleClick(sender: AnyObject) {
        guard self.index != nil else {
            return
        }
        guard self.remoteCatalog!.stringValue.isEmpty == false else {
            return
        }
        guard self.localCatalog!.stringValue.isEmpty == false else {
            return
        }
        let answer = Alerts.dialogOKCancel("Copy single files or directory", text: "Start copy?")
        if answer {
            self.copyButton.title = "Execute"
            self.rsync = true
            self.workingRsync.startAnimation(nil)
            self.copyFiles!.executeRsync(remotefile: remoteCatalog!.stringValue, localCatalog: localCatalog!.stringValue, dryrun: false)
        }
    }
}

extension ViewControllerCopyFiles: NSSearchFieldDelegate {

    func searchFieldDidStartSearching(_ sender: NSSearchField) {
        if sender.stringValue.isEmpty {
            globalMainQueue.async(execute: { () -> Void in
                self.filesArray = self.copyFiles?.filter(search: nil)
                self.tableViewSelect.reloadData()
            })
        } else {
            globalMainQueue.async(execute: { () -> Void in
                self.filesArray = self.copyFiles?.filter(search: sender.stringValue)
                self.tableViewSelect.reloadData()
            })
        }
    }

    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        globalMainQueue.async(execute: { () -> Void in
            self.filesArray = self.copyFiles?.filter(search: nil)
            self.tableViewSelect.reloadData()
        })
    }

}

extension ViewControllerCopyFiles: NSTableViewDataSource {

    func numberOfRows(in tableViewMaster: NSTableView) -> Int {
        guard self.filesArray != nil else {
            self.numberofrows.stringValue = "Number of rows:"
            return 0
        }
        self.numberofrows.stringValue = "Number of rows: " + String(self.filesArray!.count)
        return self.filesArray!.count
    }
}

extension ViewControllerCopyFiles: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text: String?
        var cellIdentifier: String = ""
        guard self.filesArray != nil else {
            return nil
        }
        var split = self.filesArray![row].components(separatedBy: "\t")
        if tableColumn == tableView.tableColumns[0] {
                text = split[0]

            cellIdentifier = "sizeID"
        }
        if tableColumn == tableView.tableColumns[1] {
            if split.count > 1 {
                text = split[1]
            } else {
                text = split[0]
            }
            cellIdentifier = "fileID"
        }
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView {
            cell.textField?.stringValue = text!
            return cell
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let myTableViewFromNotification = (notification.object as? NSTableView)!
        let indexes = myTableViewFromNotification.selectedRowIndexes
        if let index = indexes.first {
            guard self.filesArray != nil else {
                return
            }
            let split = self.filesArray![index].components(separatedBy: "\t")

            guard split.count > 1 else {
                return
            }
            self.remoteCatalog.stringValue = split[1]
            if self.remoteCatalog.stringValue.isEmpty == false && self.localCatalog.stringValue.isEmpty == false {
                self.commandString.stringValue = self.copyFiles!.getCommandDisplayinView(remotefile: self.remoteCatalog.stringValue, localCatalog: self.localCatalog.stringValue)
            } else {
                self.commandString.stringValue = "Please select both \"Restore to:\" and \"Restore:\" to show rsync command"
            }
            self.estimated = false
            self.copyButton.title = "Estimate"
        }
    }
}

// textDidEndEditing

extension ViewControllerCopyFiles: NSTextFieldDelegate {

    override func controlTextDidEndEditing(_ obj: Notification) {
        if self.remoteCatalog.stringValue.isEmpty == false && self.localCatalog.stringValue.isEmpty == false {
            self.commandString.stringValue = (self.copyFiles!.getCommandDisplayinView(remotefile: self.remoteCatalog.stringValue, localCatalog: self.localCatalog.stringValue))
        } else {
            self.commandString.stringValue = "Please select both \"Restore to:\" and \"Restore:\" to show rsync command"
        }
    }
}

extension ViewControllerCopyFiles: RefreshtableView {

    // Do a refresh of table
    func refresh() {
        guard self.copyFiles != nil else {
            return
        }
        globalMainQueue.async(execute: { () -> Void in
            self.filesArray = self.copyFiles!.filter(search: nil)
            self.tableViewSelect.reloadData()
        })
    }
}

extension ViewControllerCopyFiles: StartStopProgressIndicator {

    // Protocol StartStopProgressIndicatorViewBatch
    func stop() {
        self.working.stopAnimation(nil)
    }
    func start() {
        self.working.startAnimation(nil)
    }
    func complete() {
        // nothing
    }
}

extension ViewControllerCopyFiles: UpdateProgress {

    // When Process terminates
    func processTermination() {
        if self.rsync == false {
            self.copyFiles!.setRemoteFileList()
            self.refresh()
            self.stop()
        } else {
            self.workingRsync.stopAnimation(nil)
            self.presentViewControllerAsSheet(self.viewControllerInformation)
        }
    }

    // When Process outputs anything to filehandler
    func fileHandler() {
        // nothing
    }
}

extension ViewControllerCopyFiles: Information {

    // Protocol Information
    func getInformation() -> [String] {
        return self.copyFiles!.getOutput()
    }
}

extension ViewControllerCopyFiles: DismissViewController {

    // Protocol DismissViewController
    func dismiss_view(viewcontroller: NSViewController) {
        self.dismissViewController(viewcontroller)
    }
}

extension ViewControllerCopyFiles: GetPath {

    func pathSet(path: String?, requester: WhichPath) {
        if let setpath = path {
            self.localCatalog.stringValue = setpath
        }
    }
}

extension ViewControllerCopyFiles: setIndex {
    func setIndex(index: Int) {
        self.index = index
        self.displayRemoteserver(index: index)
    }
}

extension ViewControllerCopyFiles: getSource {
    func getSource(index: Int) {
        self.index = index
        self.displayRemoteserver(index: index)
        if let index = self.index {
            self.copyFiles = CopyFiles(index: index)
            self.working.startAnimation(nil)
            self.displayRemoteserver(index: index)
        }
    }
}
