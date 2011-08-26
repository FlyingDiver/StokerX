//
//  StokerTwitter.h
//  StokerX
//
//  Created by Joe Keenan on 8/13/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "PreferencesController.h"
#import "MGTwitterFramework/MGTwitterEngine.h"
#import "OAuthConsumer/OAuthConsumer.h"

// These two strings identify the application (StokerX) sending the tweet

//#define	kOAuthConsumerKey		@"UjMLz291haVFTs1cRdVA"
//#define	kOAuthConsumerSecret	@"H9dgyFaEZhbFK45lZs7CdCACKnBAM1Jnj7rLmw5SJk"

// These are for the test application

#define kOAuthConsumerKey				@"E4PzQuxgs0qbNvthaW61rg"
#define kOAuthConsumerSecret			@"3h2wjBs9fMPGg4Vbfx4fNROxyX2amQf6CBo5rdg"


// URLs for obtaining an authorization token from Twitter

#define kOAuthTwitterRequestTokenURL	@"http://api.twitter.com/oauth/request_token"
#define kOAuthTwitterAuthorizeURL		@"http://api.twitter.com/oauth/authorize"
#define kOAuthTwitterAccessTokenURL		@"http://api.twitter.com/oauth/access_token"

#define kOAuthTwitterDefaultsDomain		@"api.twitter.com"
#define kOAuthTwitterDefaultsPrefix		@"StokerX"



@interface StokerXTwitter : NSObject <MGTwitterEngineDelegate> 
{
	MGTwitterEngine		*twitterEngine;	
	OAToken				*requestToken;
	OAToken				*accessToken;
	OAConsumer			*consumer;
	
	Boolean				twitterIsAvailable;
	
	IBOutlet NSMenuItem	*authorizeTwitterMenuItem;
	IBOutlet NSMenuItem	*enableTwitterMenuItem;

	IBOutlet NSWindow		*webSheet;
	IBOutlet WebView		*webview;
}

- (IBAction) authorizeTwitter: (id) sender;
- (IBAction) enableTwitter: (id) sender;

- (IBAction)cancelWebSheet:(id)sender;

- (void) sendTweet: (NSString *) tweet;

- (void) getRequestToken;
- (void) setRequestToken:(OAServiceTicket *)ticket withData:(NSData *)data;
- (void) failRequestToken:(OAServiceTicket *)ticket data:(NSData *)data;

- (void) getAccessToken;
- (void) setAccessToken:(OAServiceTicket *)ticket withData:(NSData *)data;
- (void) failAccessToken:(OAServiceTicket *)ticket data:(NSData *)data;

- (NSString *) usernameFromHTTPResponseBody:(NSString *)body;

@property (nonatomic, retain) OAConsumer	*consumer;
@property (nonatomic, retain) OAToken		*requestToken;
@property (nonatomic, retain) OAToken		*accessToken;

@end
