//
//  TwitterRequest.swift
//  Samshtag
//
//  Created by CS193p Instructor.
//  Copyright (c) 2015 Stanford University. All rights reserved.
//
//  Updated to Swift 2.2 by Abdullah Abanmi

import Foundation
import Accounts
import Social
import CoreLocation

// Simple Twitter query class
// Create an instance of it using one of the initializers
// Set the requestType and parameters (if not using a convenience init that sets those)
// Call fetch (or fetchTweets if fetching Tweets)
// The handler passed in will be called when the information comes back from Twitter
// Once a successful fetch has happened,
//   a follow-on TwitterRequest to get more Tweets (newer or older) can be created
//   using the requestFor{Newer,Older} methods

private var twitterAccount: ACAccount?


enum TwitterError: ErrorType {
    case InvalidJSONData
    case NoResponse
}

public class TwitterRequest {
    
    public typealias PropertyList = AnyObject
    public var requestType: String
    public var parameters = [String : String]()
    
    let JSONExtenstion = ".json"
    let TwitterURLPrefix = "https://api.twitter.com/1.1/"
    
    private var min_id: String? = nil
    private var max_id: String? = nil
    
    
    // generates a request for older Tweets than were returned by self
    // only makes sense if self has done a fetch already
    // only makes sense for requests for Tweets
    
    public var requestForOlder: TwitterRequest? {
        return min_id != nil ? modifiedRequest(parametersToChange: [TwitterKey.MaxID : min_id!]) : nil
    }
    
    // generates a request for newer Tweets than were returned by self
    // only makes sense if self has done a fetch already
    // only makes sense for requests for Tweets
    
    public var requestForNewer: TwitterRequest? {
        return (max_id != nil) ? modifiedRequest(parametersToChange: [TwitterKey.SinceID : max_id!], clearCount: true) : nil
    }
    
    
    public enum SearchResultType {
        case Mixed, Recent, Popular
    }
    

    // designated init
    public init(_ requestType: String, _ parameters: [String : String] = [:]) {
        self.requestType = requestType
        self.parameters = parameters
    }
    
    // convenience init for creating Twt req that is a search for tweets
    convenience init(search: String, count: Int = 0, _ resultType: SearchResultType = .Mixed , _ region: CLCircularRegion? = nil) {
        
        var parameters = [TwitterKey.Query : search]
        if count > 0 { parameters[TwitterKey.Count] = "\(count)" }
        
        switch resultType {
        case .Recent: parameters[TwitterKey.ResultType] = TwitterKey.ResultTypeRecent
        case .Popular: parameters[TwitterKey.ResultType] = TwitterKey.ResultTypePopular
        default: break
            
        }
        self.init(TwitterKey.SearchForTweets, parameters)
    }
    

    // convenience "fetch" for when self is a request that returns Tweet(s)
    // handler is not necessarily invoked on the main queue
    public func fetchTweets(handler: ([Tweet]) -> Void) {
        fetch { results in
            
            var tweets = [Tweet]()
            var tweetArray: NSArray?
            
            if let dictionary = results as? NSDictionary {
                if let tweets = dictionary[TwitterKey.Tweets] as? NSArray {
                    tweetArray = tweets
                } else if let tweet = Tweet(data: dictionary) {
                    tweets = [tweet]
                }
            } else if let array = results as? NSArray {
                tweetArray = array
            }
            if tweetArray != nil {
                for tweetData in tweetArray! {

                    if let tweet = Tweet(data: tweetData as? NSDictionary) {
                        tweets.append(tweet)
                    }
                    
                }
            }
            handler(tweets)
        }
    }
    // send an arbitrary request off to Twitter
    // calls the handler (not necessarily on the main queue)
    //   with the JSON results converted to a Property List
    
    public func fetch(handler: (results: PropertyList?) -> Void) {
        performTwitterRequest(SLRequestMethod.GET, handler: handler)
    }

    // MARK: - Private Implementaion
    
    // creates an appropriate SLRequest using the specified SLRequestMethod
    // then calls the other version of this method that takes an SLRequest
    // handler is not necessarily called on the main queue
    
    func performTwitterRequest(method: SLRequestMethod, handler: (PropertyList?) -> Void) {
        let jsonExtension = (self.requestType.rangeOfString(JSONExtenstion) == nil) ? JSONExtenstion : ""
        let request = SLRequest(
            forServiceType: SLServiceTypeTwitter,
            requestMethod: method,
            URL: NSURL( string: "\(TwitterURLPrefix)\(self.requestType)\(jsonExtension)" ),
            parameters: self.parameters)
        
        performTwitterRequest(request, handler: handler)
    }
    
    // sends the request to Twitter
    // unpackages the JSON response into a Property List
    // and calls handler (not necessarily on the main queue)

    func performTwitterRequest(request: SLRequest, handler: (PropertyList?) -> Void) {
        
        if let account = twitterAccount {
            request.account = account
            request.performRequestWithHandler { (jsonResponse, httpResponse, _) in
                

                if jsonResponse != nil
                {
                    guard let propertyListResponse: PropertyList = try! NSJSONSerialization.JSONObjectWithData(jsonResponse, options: NSJSONReadingOptions.MutableLeaves)
                        else {
                            let error = "Couldn't parse JSON response"
                            self.log(error)
                            return
                        }
                    
                    self.synchronize { self.captureFollowonRequestInfo(propertyListResponse) }
                    
                    handler(propertyListResponse)
                }
            }
        
        }
            
        else {
            let accountStore = ACAccountStore()
            let twitterAccountType = accountStore.accountTypeWithAccountTypeIdentifier(ACAccountTypeIdentifierTwitter)
            accountStore.requestAccessToAccountsWithType(twitterAccountType, options: nil) { (granted, _) in
                if granted {
                    if let account = accountStore.accountsWithAccountType(twitterAccountType)?.last as? ACAccount {
                        twitterAccount = account
                        self.performTwitterRequest(request, handler: handler)
                    } else {
                        let error = "Couldn't discover Twitter account type."
                        self.log(error)
                        handler(error)
                    }
                } else {
                    let error = "Access to Twitter was not granted."
                    self.log(error)
                    handler(error)
                }
            }
        }
   
    }
    
    // modifies parameters in an existing request to create a new one
    
    private func modifiedRequest(parametersToChange parametersToChange: Dictionary<String,String>, clearCount: Bool = false) -> TwitterRequest {
        var newParameters = parameters
        for (key, value) in parametersToChange {
            newParameters[key] = value
        }
        if clearCount { newParameters[TwitterKey.Count] = nil }
        return TwitterRequest(requestType, newParameters)
    }
    
    // captures the min_id and max_id information
    // to support requestForNewer and requestForOlder
    private func captureFollowonRequestInfo(propertyListResponse: PropertyList?) {
     
        guard let
            responseDic = propertyListResponse as? NSDictionary,
            maxID = responseDic.valueForKeyPath(TwitterKey.SearchMetadata.MaxID) as? String,
            nextResult = responseDic.valueForKeyPath(TwitterKey.SearchMetadata.NextResults) as? String
        else { return }
        
        self.max_id = maxID
        
        for eachQueryTerm in
            nextResult.componentsSeparatedByString(TwitterKey.SearchMetadata.Separator) {
                
            let nextID = eachQueryTerm.componentsSeparatedByString("=")
            if nextID.count == 2 { self.min_id = nextID[1] }
        }
        
    }
    
    // debug print with idetifying prefix
    private func log(whatToLog: AnyObject) {
        debugPrint("TwitterRequest: \(whatToLog)")
    }
    
    // synchronizes access to self across multiple threads
    private func synchronize(clouser: () -> Void) {
        objc_sync_enter(self)
        clouser()
        objc_sync_exit(self)
    }
  
    
    
    
    
    struct TwitterKey {
        
        static let Count             = "count"
        static let Query             = "q"
        static let Tweets            = "statuses"
        static let ResultType        = "result_type"
        static let ResultTypeRecent  = "recent"
        static let ResultTypePopular = "popular"
        static let Geocode           = "geocode"
        static let SearchForTweets   = "search/tweets"
        static let MaxID             = "max_id"
        static let SinceID           = "since_id"

        struct SearchMetadata {
            static let MaxID             = "search_metadata.max_id_str"
            static let NextResults       = "search_metadata.next_results"
            static let Separator         = "&"
        }
    }

}
