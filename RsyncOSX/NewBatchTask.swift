//
//  newBatchTask.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 21.06.2017.
//  Copyright © 2017 Thomas Evensen. All rights reserved.
//
//  SwiftLint: OK 31 July 2017
//  swiftlint:disable syntactic_sugar

import Foundation
import Cocoa

protocol BatchTask: class {
    func presentViewBatch()
    func progressIndicatorViewBatch(operation: BatchViewProgressIndicator)
    func setOutputBatch(outputbatch: OutputBatch?)
}

enum BatchViewProgressIndicator {
    case start
    case stop
    case complete
    case refresh
}

final class NewBatchTask {

    // Protocol function used in Process().
    weak var processupdateDelegate: UpdateProgress?
    // Delegate function for doing a refresh of NSTableView in ViewControllerBatch
    weak var refreshDelegate: RefreshtableView?
    // Delegate for presenting batchView
    weak var batchViewDelegate: BatchTask?
    // Delegate function for start/stop progress Indicator in BatchWindow
    weak var indicatorDelegate: StartStopProgressIndicatorSingleTask?
    // Delegate function for show process step and present View
    weak var taskDelegate: SingleTask?
    // Reference to Process task
    var process: Process?
    // Getting output from rsync
    var output: OutputProcess?
    // Getting output from batchrun
    private var outputbatch: OutputBatch?
    // HiddenID task, set when row is selected
    private var hiddenID: Int?
    // Schedules in progress
    private var scheduledJobInProgress: Bool = false
    // Some max numbers
    private var transfernum: String?
    private var transferbytes: String?

    // Present BATCH TASKS only
    // Start of BATCH tasks.
    // After start the function ProcessTermination()
    // which is triggered when a Process termination is
    // discovered, takes care of next task according to
    // status and next work in batchOperations which
    // also includes a queu of work.
    func presentBatchView() {
        self.outputbatch = nil
        // NB: self.setInfo(info: "Batchrun", color: .blue)
        // Get all Configs marked for batch
        let configs = Configurations.shared.getConfigurationsBatch()
        let batchObject = BatchTaskWorkQueu(batchtasks: configs)
        // Set the reference to batchData object in SharingManagerConfiguration
        Configurations.shared.setbatchDataQueue(batchdata: batchObject)
        // Present batchView
        self.batchViewDelegate?.presentViewBatch()
    }

    // Functions are called from batchView.
    func executeBatch() {
        if let batchobject = Configurations.shared.getBatchdataObject() {
            // Just copy the work object.
            // The work object will be removed in Process termination
            let work = batchobject.nextBatchCopy()
            // Get the index if given hiddenID (in work.0)
            let index: Int = Configurations.shared.getIndex(work.0)

            // Create the output object for rsync
            self.output = nil
            self.output = OutputProcess()

            switch work.1 {
            case 0:
                self.batchViewDelegate?.progressIndicatorViewBatch(operation: .start)
                let arguments: Array<String> = Configurations.shared.arguments4rsync(index: index, argtype: .argdryRun)
                let process = Rsync(arguments: arguments)
                // Setting reference to process for Abort if requiered
                process.executeProcess(output: self.output!)
                self.process = process.getProcess()
            case 1:
                let arguments: Array<String> = Configurations.shared.arguments4rsync(index: index, argtype: .arg)
                let process = Rsync(arguments: arguments)
                // Setting reference to process for Abort if requiered
                process.executeProcess(output: self.output!)
                self.process = process.getProcess()
            case -1:
                self.batchViewDelegate?.setOutputBatch(outputbatch: self.outputbatch)
                self.batchViewDelegate?.progressIndicatorViewBatch(operation: .complete)
            default : break
            }
        }
    }

    func closeOperation() {
        self.process = nil
        self.taskDelegate?.setInfo(info: "", color: .black)
    }

    // Error and stop execution
    func error() {
        // Just pop off remaining work
        if let batchobject = Configurations.shared.getBatchdataObject() {
            batchobject.abortOperations()
            self.executeBatch()
        }
    }

    // Called when ProcessTermination is called in main View.
    // Either dryn-run or realrun completed.
    func processTermination() {
        if let batchobject = Configurations.shared.getBatchdataObject() {
            if self.outputbatch == nil {
                self.outputbatch = OutputBatch()
            }
            // Remove the first worker object
            let work = batchobject.nextBatchRemove()
            // (work.0) is estimationrun, (work.1) is real run
            switch work.1 {
            case 0:
                // dry-run
                // Setting maxcount of files in object
                batchobject.setEstimated(numberOfFiles: self.output!.getMaxcount())
                // Do a refresh of NSTableView in ViewControllerBatch
                // Stack of ViewControllers
                self.batchViewDelegate?.progressIndicatorViewBatch(operation: .stop)
                self.executeBatch()
            case 1:
                // Real run
                let number = Numbers(output: self.output!.getOutput())
                number.setNumbers()
                // Update files in work
                batchobject.updateInProcess(numberOfFiles: self.output!.getMaxcount())
                batchobject.setCompleted()
                self.batchViewDelegate?.progressIndicatorViewBatch(operation: .refresh)
                // Set date on Configuration
                let index = Configurations.shared.getIndex(work.0)
                let config = Configurations.shared.getConfigurations()[index]
                // Get transferred numbers from view
                self.transfernum = String(number.getTransferredNumbers(numbers: .transferredNumber))
                self.transferbytes = String(number.getTransferredNumbers(numbers: .transferredNumberSizebytes))
                if config.offsiteServer.isEmpty {
                    let numbers = number.stats(numberOfFiles: self.transfernum, sizeOfFiles: self.transferbytes)[0]
                    let result = config.localCatalog + " , " + "localhost" + " , " + numbers
                    self.outputbatch!.addLine(str: result)
                } else {
                    let numbers = number.stats(numberOfFiles: self.transfernum, sizeOfFiles: self.transferbytes)[0]
                    let result = config.localCatalog + " , " + config.offsiteServer + " , " + numbers
                    self.outputbatch!.addLine(str: result)
                }
                let hiddenID = Configurations.shared.gethiddenID(index: index)
                Configurations.shared.setCurrentDateonConfiguration(index)
                let numberOffFiles = self.transfernum
                let sizeOfFiles = self.transferbytes
                Schedules.shared.addresultmanuel(hiddenID,
                                     result: number.stats(numberOfFiles: numberOffFiles, sizeOfFiles: sizeOfFiles)[0])
                self.executeBatch()
            default :
                break
            }
        }
    }

    init() {
        if let pvc = Configurations.shared.viewControllertabMain as? ViewControllertabMain {
            self.indicatorDelegate = pvc
            self.taskDelegate = pvc
            self.batchViewDelegate = pvc
        }
    }

}
