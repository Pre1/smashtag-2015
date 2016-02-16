//
//  User.swift
//  Samshtag
//
//  Created by CS193p Instructor.
//  Copyright (c) 2015 Stanford University. All rights reserved.
//
//  Updated to Swift 2.2 by Abdullah Abanmi

import Foundation


// Container to hold data about a twitter user

public struct User: CustomStringConvertible {
    
    public var screenName: String
    public var name: String
    public var profileImageURL: NSURL?
    public var verified: Bool = false
    public var id: String!
    
    public var description: String {
        let v = verified ? "✅" : ""
        return "@\(screenName) \(name)\(v)"
    }
    
    // MARL: - Private Implementation
    init?(data: NSDictionary?) {
        
        let name = data?.valueForKeyPath(TwitterKey.Name) as? String
        let screenName = data?.valueForKeyPath(TwitterKey.ScreenName) as? String
        if name != nil && screenName != nil {
            self.name = name!
            self.screenName = screenName!
            self.id = data?.valueForKeyPath(TwitterKey.ID) as? String
            if let verified = data?.valueForKeyPath(TwitterKey.Verified)?.boolValue {
                self.verified = verified
            }
            if let urlString = data?.valueForKeyPath(TwitterKey.ProfileImageURL) as? String {
                self.profileImageURL = NSURL(string: urlString)
            }
        }
        else {
            return nil
        }
    }
    
    var asPropertyList: AnyObject {
        var dictionary = [String : String]()
        dictionary[TwitterKey.Name]            = self.name
        dictionary[TwitterKey.ScreenName]      = self.screenName
        dictionary[TwitterKey.ID]              = self.id
        dictionary[TwitterKey.Verified]        = self.verified ? "Yes" : "No"
        dictionary[TwitterKey.ProfileImageURL] = self.profileImageURL?.absoluteString
        return dictionary
    }
    
    init() {
        screenName = "Unknown"
        name = "Unknown"
    }
    
    struct TwitterKey {
        static let Name            = "name"
        static let ScreenName      = "screen_name"
        static let ID              = "id_str"
        static let Verified        = "verfified"
        static let ProfileImageURL = "profile_image_url"
    }
    
}
