//  Tweet.swift
//  Samshtag
//
//  Created by CS193p Instructor.
//  Copyright (c) 2015 Stanford University. All rights reserved.

//
//  Updated to Swift 2.2 by Abdullah Abanmi

import Foundation

// a simple container class which just holds the data in a Tweet
// IndexedKeywords are substrings of the Tweet's text
// for example, a hashtag or other user or url that is mentioned in the Tweet
// note carefully the comments on the two range properties in an IndexedKeyword
// Tweet instances re created by fetching from Twitter using a TwitterRequest

public class Tweet: CustomStringConvertible
{
    public var text: String
    public var user: User
    public var created: NSDate
    public var id: String?
    public var media = [MediaItem]()
    public var mediaMentions = [IndexedKeyword]()
    public var hashtags = [IndexedKeyword]()
    public var urls = [IndexedKeyword]()
    public var userMentions = [IndexedKeyword]()
    
    public struct IndexedKeyword: CustomStringConvertible
    {
        // will include # or @ or http:// prefix
        public var keyword: String
        
        // index into the Tweet's text property only
        public var range: Range<String.Index>
        
        // index into an NS[Attributed]String made from the Tweet's text
        public var nsrange = NSMakeRange(0, 0)
        
        public init?(data: NSDictionary?, inText: String, prefix: String?) {
            
            guard let
                indices = data?.valueForKeyPath(TwitterKey.Entities.Indices) as? NSArray,
                startIndex = (indices.firstObject as? NSNumber)?.integerValue,
                endIndex = (indices.lastObject as? NSNumber)?.integerValue
                else { return nil }
            
            let length = inText.characters.count
            
            if length > 0 {
                let start = max(min(startIndex, length - 1), 0)
                let end = max(min(endIndex, length), 0)
                
                
                if end > start
                {
                    let inTextStart = inText.startIndex
                    let inTextEnd   = inText.startIndex
                    range           = inTextStart.advancedBy(start)...inTextEnd.advancedBy(end - 1)
                    keyword         = inText.substringWithRange(range)
                    
                    if prefix != nil && !keyword.hasPrefix(prefix!) && start > 0
                    {
                        range = inTextStart.advancedBy(start - 1)...inTextEnd.advancedBy(end - 2)
                        keyword = inText.substringWithRange(range)
                    }
                    if prefix == nil || keyword.hasPrefix(prefix!)
                    {
                        nsrange = inText.rangeOfString(keyword, nearRange: NSMakeRange(startIndex, endIndex-startIndex))
                        
                        if nsrange.location != NSNotFound { return }
                        
                    }
                }
                else { return nil }
            }
                
            else { return nil }
            
        }
        
        public var description: String {
            get {
                return "\(keyword) (\(nsrange.location), \(nsrange.location + nsrange.length - 1))"
            }
        }
        
        
        
    }
    
    public var description: String {
        return "\(user) - \(created)\n\(text)\nhashtags: \(hashtags)\nurls: \(urls)\nuser_mentions: \(userMentions)" + (id == nil ? "" : "\nid: \(id!)")
    }
    
    init?(data: NSDictionary?)
    {
        guard let
            user                 = User(data: data?.valueForKeyPath(TwitterKey.User) as? NSDictionary),
            text                 = data?.valueForKeyPath(TwitterKey.Text) as? String,
            created              = (data?.valueForKeyPath(TwitterKey.Created) as? String)?.asTwitterDate,
            hashtagMentionsArray = data?.valueForKeyPath(TwitterKey.Entities.Hashtags) as? NSArray,
            urlMentionsArray     = data?.valueForKeyPath(TwitterKey.Entities.URLs) as? NSArray,
            userMentionsArray    = data?.valueForKeyPath(TwitterKey.Entities.UserMentions) as? NSArray
        else {
            self.text = ""
            self.user = User()
            self.created = NSDate()
            return nil
        }
        
        (self.user, self.text, self.created, self.id) = (user, text, created, data?.valueForKeyPath(TwitterKey.ID) as? String)
        
        if let mediaEntities = data?.valueForKeyPath(TwitterKey.Media) as? NSArray {
            for eachMediaData in mediaEntities {
                
                if let mediaItem = MediaItem(data: eachMediaData as? NSDictionary) {
                    media.append(mediaItem)
                }
                
            }
        }
        
        hashtags     = getIndexedKeywords(hashtagMentionsArray, inText: text, prefix: "#")
        urls         = getIndexedKeywords(urlMentionsArray, inText: text, prefix: "h")
        userMentions = getIndexedKeywords(userMentionsArray, inText: text, prefix: "@")
        
    }
    
    private func getIndexedKeywords(dictionary: NSArray?, inText: String, prefix: String? = nil) -> [IndexedKeyword] {
        var results = [IndexedKeyword]()
        guard let IndexedKeywords = dictionary else { return results }
        
        for IndexedKeywordData in IndexedKeywords
        {
            if let indexedKeyword = IndexedKeyword(data: IndexedKeywordData as? NSDictionary, inText: inText, prefix: prefix)
            {
                results.append(indexedKeyword)
            }
        }
        
        return results
    }
    
    
    struct TwitterKey {
        static let User         = "user"
        static let Text         = "text"
        static let Created      = "created_at"
        static let ID           = "id_str"
        static let Media        = "entities.media"
        struct Entities {
            static let Hashtags     = "entities.hashtags"
            static let URLs         = "entities.urls"
            static let UserMentions = "entities.user_mentions"
            static let Indices      = "indices"
        }
    }
}

private extension NSString {
    func rangeOfString(substring: NSString, nearRange: NSRange) -> NSRange {
        
        var start = max(min(nearRange.location, length - 1), 0)
        var end = max(min(nearRange.location + nearRange.length, length), 0)
        var done = false
        
        while !done {
            let range = rangeOfString(
                substring as String,
                options: .NumericSearch,
                range: NSMakeRange(start, end-start)
            )
            
            if range.location != NSNotFound {
                return range
            }
            
            done = true
            if start > 0 { start -= 1; done = false }
            if end < length { end += 1; done = false }
        }
        return NSMakeRange(NSNotFound, 0)
    }
    
}
private extension String {
    var asTwitterDate: NSDate? {
        get {
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US")
            dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
            return dateFormatter.dateFromString(self)
        }
    }
}
