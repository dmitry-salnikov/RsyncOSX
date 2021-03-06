//
//  PersistentStoreageUserconfiguration.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 26/10/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//  
//  swiftlint:disable syntactic_sugar

import Foundation

final class PersistentStoreageUserconfiguration: Readwritefiles {

    /// Variable holds all configuration data
    private var userconfiguration: Array<NSDictionary>?

    /// Function reads configurations from permanent store
    /// - returns : array of NSDictonarys, return might be nil
    func readUserconfigurationsFromPermanentStore() -> Array<NSDictionary>? {
        return self.userconfiguration
    }

    // Saving user configuration
    func saveUserconfiguration () {
        var version3Rsync: Int?
        var detailedlogging: Int?
        var rsyncPath: String?
        var allowDoubleclick: Int?
        var rsyncerror: Int?
        var restorePath: String?

        if Configurations.shared.rsyncVer3 {
            version3Rsync = 1
        } else {
            version3Rsync = 0
        }
        if Configurations.shared.detailedlogging {
            detailedlogging = 1
        } else {
            detailedlogging = 0
        }
        if Configurations.shared.rsyncPath != nil {
            rsyncPath = Configurations.shared.rsyncPath!
        }
        if Configurations.shared.restorePath != nil {
            restorePath = Configurations.shared.restorePath!
        }
        if Configurations.shared.allowDoubleclick {
            allowDoubleclick = 1
        } else {
            allowDoubleclick = 0
        }
        if Configurations.shared.rsyncerror {
            rsyncerror = 1
        } else {
            rsyncerror = 0
        }

        var array = Array<NSDictionary>()

        let dict: NSMutableDictionary = [
            "version3Rsync": version3Rsync! as Int,
            "detailedlogging": detailedlogging! as Int,
            "allowDoubleclick": allowDoubleclick! as Int,
            "rsyncerror": rsyncerror! as Int]

        if rsyncPath != nil {
            dict.setObject(rsyncPath!, forKey: "rsyncPath" as NSCopying)
        }
        if restorePath != nil {
            dict.setObject(restorePath!, forKey: "restorePath" as NSCopying)
        }
        array.append(dict)
        self.writeToStore(array)
    }

    // Writing configuration to persistent store
    // Configuration is Array<NSDictionary>
    private func writeToStore (_ array: Array<NSDictionary>) {
        // Getting the object just for the write method, no read from persistent store
        _ = self.writeDictionarytofile(array, task: .userconfig)
    }

    init () {
        // Create the readwritefiles object
        super.init(task: .userconfig)
        // Reading Configurations from memory or disk, if dirty read from disk
        // if not dirty set self.configurationFromStore to nil to tell
        // anyone to read Configurations from memory
        if let userconfigurationFromstore = self.getDatafromfile() {
            self.userconfiguration = userconfigurationFromstore
        } else {
            self.userconfiguration = nil
        }
    }
}
