//
//  MediaItem.swift
//  Samshtag
//
//  Created by CS193p Instructor.
//  Copyright (c) 2015 Stanford University. All rights reserved.
//
//  Updated to Swift 2.2 by Abdullah Abanmi

import Foundation

public struct MediaItem: CustomStringConvertible {
    
    public var url: NSURL!
    public var aspectRatio: Double = 0
    
    public var description: String {
        
        return (url.absoluteString ?? "no url") + "aspect ratio = \(aspectRatio)"
    }
    
    
    // MARK: - Private Implementation
    init?(data: NSDictionary?) {

        guard let
            urlString = data?.valueForKeyPath(TwitterKey.MediaURL) as? String,
            url       = NSURL(string: urlString),
            h         = data?.valueForKeyPath(TwitterKey.Hight) as? NSNumber,
            w         = data?.valueForKeyPath(TwitterKey.Width) as? NSNumber
        else { return nil }
        
        self.url = url
        guard h.doubleValue != 0 else { print("not vaild, divBy0"); return nil }
        
        aspectRatio = w.doubleValue / h.doubleValue

        
    }
    
    struct TwitterKey {
        static let MediaURL = "media_url_https"
        static let Width    = "size.small.w"
        static let Hight    = "size.small.h"
    }
    
    
}
