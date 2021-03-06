//
//  ViewControllerProgressProcess.swift
//  RsyncOSXver30
//
//  Created by Thomas Evensen on 24/08/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//

import Cocoa

// Protocol for progress indicator
protocol Count: class {
    func maxCount() -> Int
    func inprogressCount() -> Int
}

// Protocol for aborting task
protocol AbortOperations: class {
    func abortOperations()
}

class ViewControllerProgressProcess: NSViewController {

    var count: Double = 0
    var maxcount: Double = 0
    var calculatedNumberOfFiles: Int?
    // Delegate to count max number and updates during progress
    weak var countDelegate: Count?
    // Delegate to dismisser
    weak var dismissDelegate: DismissViewController?
    // Delegate to Abort operations
    weak var abortDelegate: AbortOperations?

    @IBOutlet weak var progress: NSProgressIndicator!

    @IBAction func abort(_ sender: NSButton) {
        self.abortDelegate?.abortOperations()
        self.processTermination()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let pvc = self.presenting as? ViewControllertabMain {
            self.dismissDelegate = pvc
            self.abortDelegate = pvc
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let pvc2 = Configurations.shared.singleTask {
            self.countDelegate = pvc2
        }
        self.calculatedNumberOfFiles = self.countDelegate?.maxCount()
        self.initiateProgressbar()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        self.stopProgressbar()
    }

    fileprivate func stopProgressbar() {
        self.progress.stopAnimation(self)
    }

    // Progress bars
    private func initiateProgressbar() {
        if let calculatedNumberOfFiles = self.calculatedNumberOfFiles {
            self.progress.maxValue = Double(calculatedNumberOfFiles)
        }
        self.progress.minValue = 0
        self.progress.doubleValue = 0
        self.progress.startAnimation(self)
    }

    fileprivate func updateProgressbar(_ value: Double) {
        self.progress.doubleValue = value
    }

}

extension ViewControllerProgressProcess: UpdateProgress {

    // When processtermination is discovered in real task progressbar is stopped
    // and progressview is dismissed. Real run is completed.
    func processTermination() {
        self.stopProgressbar()
        self.dismissDelegate?.dismiss_view(viewcontroller: self)
    }

    // Update progressview during task
    func fileHandler() {
        guard self.countDelegate != nil else {
            return
        }
        self.updateProgressbar(Double(self.countDelegate!.inprogressCount()))
    }

}
