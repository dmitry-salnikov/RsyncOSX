//
//  ScheduleWriteLoggData.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 19.04.2017.
//  Copyright © 2017 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable syntactic_sugar line_length

import Foundation
import Cocoa

class ScheduleWriteLoggData {

    // Storage API
    var storageapi: PersistentStorageAPI?
    // Array to store all scheduled jobs and history of executions
    // Will be kept in memory until destroyed
    var schedule = Array<ConfigurationSchedule>()
    // Delegate function for doing a refresh of NSTableView in ViewControllerScheduleDetailsAboutRuns
    weak var refreshlogviewDelegate: RefreshtableView?
    // Delegate function for deselect row in table main view after loggdata is saved
    weak var deselectrowDelegate: deselectRowTable?

    /// Function for deleting log row
    /// - parameter hiddenID : hiddenID
    /// - parameter parent : key to log row
    /// - parameter resultExecuted : resultExecuted
    /// - parameter dateExecuted : dateExecuted
    func deletelogrow (hiddenID: Int, parent: String, resultExecuted: String, dateExecuted: String) {
        var result = self.schedule.filter({return ($0.hiddenID == hiddenID)})
        if result.count > 0 {
            loop: for i in 0 ..< result.count {
                let delete = result[i].logrecords.filter({return (($0.value(forKey: "parent") as? String) == parent &&
                    ($0.value(forKey: "resultExecuted") as? String) == resultExecuted &&
                    ($0.value(forKey: "dateExecuted") as? String) == dateExecuted)})
                if delete.count == 1 {
                    // Get index of record storing the logrecord
                    let indexA = self.schedule.index(where: { $0.dateStart == result[i].dateStart &&
                        $0.schedule == result[i].schedule &&
                        $0.hiddenID == result[i].hiddenID})
                    // Get the index of the logrecord itself and remove the the record
                    let indexB = result[i].logrecords.index(of: delete[0])
                    // Guard index not nil
                    guard indexA != nil && indexB != nil else {
                        return
                    }
                    result[i].logrecords.remove(at: indexB!)
                    self.schedule[indexA!].logrecords = result[i].logrecords
                    // Do a refresh of table
                    if let pvc = Configurations.shared.viewControllerLoggData as? ViewControllerLoggData {
                        self.refreshlogviewDelegate = pvc
                        self.refreshlogviewDelegate?.refresh()
                    }
                    // Save schedule including logs
                    self.storageapi!.saveScheduleFromMemory()
                    break loop
                }
            }
        }
    }

    /// Function adds results of task to file (via memory). Memory are
    /// saved after changed. Used in either single tasks or batch.
    /// - parameter hiddenID : hiddenID for task
    /// - parameter result : String representation of result
    /// - parameter date : String representation of date and time stamp
    func addresultmanuel(_ hiddenID: Int, result: String) {
        // Set the current date
        let currendate = Date()
        let dateformatter = Tools().setDateformat()
        let date = dateformatter.string(from: currendate)

        if Configurations.shared.detailedlogging {
            var inserted: Bool = false
            for i in 0 ..< self.schedule.count {
                // Add record only to record with no enddate
                if Configurations.shared.getResourceConfiguration(hiddenID, resource: .task) == "backup" {
                    if self.schedule[i].hiddenID == hiddenID  && self.schedule[i].schedule == "manuel" && self.schedule[i].dateStop == nil {
                        let dict = NSMutableDictionary()
                        dict.setObject(date, forKey: "dateExecuted" as NSCopying)
                        dict.setObject(result, forKey: "resultExecuted" as NSCopying)
                        let dictKey: NSDictionary = [
                            // "dateStart":self.Schedule[i].dateStart,
                            "dateStart": "01 Jan 1900 00:00",
                            "schedule": self.schedule[i].schedule,
                            "hiddenID": self.schedule[i].hiddenID]
                        let parent: String = self.computeKey(dictKey)
                        dict.setValue(parent, forKey: "parent")
                        self.schedule[i].logrecords.append(dict)
                        inserted = true
                    }
                }
            }
            // Record does not exist, create new Schedule (not inserted)
            if inserted == false {
                if (Configurations.shared.getResourceConfiguration(hiddenID, resource: .task) == "backup") {
                    let masterdict = NSMutableDictionary()
                    masterdict.setObject(hiddenID, forKey: "hiddenID" as NSCopying)
                    // masterdict.setObject(date, forKey: "dateStart" as NSCopying)
                    masterdict.setObject("01 Jan 1900 00:00", forKey: "dateStart" as NSCopying)
                    masterdict.setObject("manuel", forKey: "schedule" as NSCopying)

                    let dict = NSMutableDictionary()
                    dict.setObject(date, forKey: "dateExecuted" as NSCopying)
                    dict.setObject(result, forKey: "resultExecuted" as NSCopying)

                    // Compute key to parent
                    // Just to pass schedule in dictionary, no saved but used for computing key to parent
                    let parent: String = self.computeKey(masterdict)
                    dict.setValue(parent, forKey: "parent")

                    let executed = NSMutableArray()
                    executed.add(dict)
                    let newSchedule = ConfigurationSchedule(dictionary: masterdict, log: executed)
                    self.schedule.append(newSchedule)
                    // Set inseted true to force write of record
                    inserted = true
                }
            }
            if inserted {
                self.storageapi!.saveScheduleFromMemory()
                if let pvc = Configurations.shared.viewControllertabMain as? ViewControllertabMain {
                    self.deselectrowDelegate = pvc
                    self.deselectrowDelegate?.deselectRow()
                }
            }
        }
    }

    /// Function adds results of task to file (via memory). Memory are
    /// saved after changed. Used in either single tasks or batch.
    /// - parameter hiddenID : hiddenID for task
    /// - parameter dateStart : String representation of date and time stamp start schedule
    /// - parameter result : String representation of result
    /// - parameter date : String representation of date and time stamp for task executed
    /// - parameter schedule : schedule of task
    func addresultschedule(_ hiddenID: Int, dateStart: String, result: String, date: String, schedule: String) {
        if Configurations.shared.detailedlogging {
            loop : for i in 0 ..< self.schedule.count {
                if self.schedule[i].hiddenID == hiddenID  &&
                    self.schedule[i].schedule == schedule &&
                    self.schedule[i].dateStart == dateStart {
                    if (Configurations.shared.getResourceConfiguration(hiddenID, resource: .task) == "backup") {
                        let dict = NSMutableDictionary()
                        dict.setObject(date, forKey: "dateExecuted" as NSCopying)
                        dict.setObject(result, forKey: "resultExecuted" as NSCopying)
                        // Compute key to parent
                        // Just to pass schedule in dictionary, no saved but used for computing key to parent
                        let dictKey: NSDictionary = [
                            "dateStart": self.schedule[i].dateStart,
                            "schedule": self.schedule[i].schedule,
                            "hiddenID": self.schedule[i].hiddenID
                        ]
                        let parent: String = self.computeKey(dictKey)
                        dict.setValue(parent, forKey: "parent")
                        self.schedule[i].logrecords.append(dict)
                        self.storageapi!.saveScheduleFromMemory()
                        break loop
                    }
                }
            }
        }
    }

    // Computing key for checking of parent.
    // Parent key is stored in executed dictionary
    func computeKey (_ dict: NSDictionary) -> String {
        var key: String?
        let hiddenID: Int = (dict.value(forKey: "hiddenID") as? Int)!
        let schedule: String = (dict.value(forKey: "schedule") as? String)!
        let dateStart: String = (dict.value(forKey: "dateStart") as? String)!
        key = String(hiddenID) + schedule + dateStart
        return key!
    }

    init() {
        self.storageapi = PersistentStorageAPI()
    }
}
