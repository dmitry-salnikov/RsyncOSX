//
//  processCmd.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 10.03.2017.
//  Copyright © 2017 Thomas Evensen. All rights reserved.
//
//  SwiftLint: OK 31 July 2017
//  swiftlint:disable syntactic_sugar line_length

import Foundation

class ProcessCmd {

    // Number of calculated files to be copied
    var calculatedNumberOfFiles: Int = 0
    // Variable for reference to Process
    var processReference: Process?
    // Message to calling class
    weak var updateDelegate: UpdateProgress?
    // If process is created in Operation
    var aScheduledOperation: Bool?
    // Observer
    weak var notifications: NSObjectProtocol?
    // Command to be executed, normally rsync
    var command: String?
    // Arguments to command
    var arguments: Array<String>?
    // Output from CopyFiles or not
    var copyfiles: Bool = false

    func executeProcess (output: OutputProcess) {
        // Process
        let task = Process()
        // Setting the correct path for rsync
        // If self.command != nil other command than rsync to be executed
        // Other commands are either ssh or scp (from CopyFiles)
        if let command = self.command {
            task.launchPath = command
        } else {
            task.launchPath = Tools().rsyncpath()
        }
        task.arguments = self.arguments
        // Pipe for reading output from Process
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        let outHandle = pipe.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        // Observator for reading data from pipe
        // Observer is removed when Process terminates
        self.notifications = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable,
                                                            object: nil, queue: nil) { _ -> Void in
            let data = outHandle.availableData
            if data.count > 0 {
                if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    // Add files to be copied, the output.addString takes care of
                    // splitting the output
                    if self.copyfiles {
                        output.addLine2(str as String)
                    } else {
                        output.addLine(str as String)
                    }
                    self.calculatedNumberOfFiles = output.getOutputCount()
                    // Check if in a scheduled operation, if not use delegate to inform about progress
                    if self.aScheduledOperation! == false {
                        // Send message about files
                        self.updateDelegate?.fileHandler()
                    }
                }
                outHandle.waitForDataInBackgroundAndNotify()
            }
        }
        // Observator Process termination
        // Observer is removed when Process terminates
        self.notifications = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification,
                                                            object: task, queue: nil) { _ -> Void in
            // Check if in a scheduled operation, if not use delegate to inform about termination of Process()
            if self.aScheduledOperation! == false {
                // Send message about process termination
                self.updateDelegate?.processTermination()
            } else {
                // We are in Scheduled operation and must finalize the job
                // e.g logging date and stuff like that
                if Configurations.shared.operation != nil {
                    Configurations.shared.operation!.finalizeScheduledJob(output: output)
                }
                // After logging is done set reference to object = nil
                Configurations.shared.operation = nil
            }
            NotificationCenter.default.removeObserver(self.notifications as Any)
        }
        self.processReference = task
        task.launch()
    }

    // Get the reference to the Process object.
    func getProcess() -> Process? {
        return self.processReference
    }

    // Terminate Process, used when user Aborts task.
    func abortProcess() {
        guard self.processReference != nil else {
            return
        }
        self.processReference!.terminate()
    }

    init(command: String?, arguments: Array<String>?, aScheduledOperation: Bool) {
        self.command = command
        self.arguments = arguments
        self.aScheduledOperation = aScheduledOperation
    }

}
