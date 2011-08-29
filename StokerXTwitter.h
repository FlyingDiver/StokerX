//
//  StokerTwitter.h
//  StokerX
//
//  Created by Joe Keenan on 8/13/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PreferencesController.h"
#import "GTMOAuthWindowController.h"
#import "JSON.h"

// These are the keys for the OOB version (beta 0.5)

// #define	kOAuthConsumerKey		@"UjMLz291haVFTs1cRdVA"
// #define	kOAuthConsumerSecret	@"H9dgyFaEZhbFK45lZs7CdCACKnBAM1Jnj7rLmw5SJk"

// These are the keys for the callback version

#define kOAuthConsumerKey		@"yF1oP08RQhPGrFvUbEkNQ"
#define kOAuthConsumerSecret	@"tT2eVOidKDhwuP5RJoj5Rf9CQPHfyd2c9wAcAKOOE"

#define MAX_MESSAGE_LENGTH		140		// twitter max

@interface StokerXTwitter : NSObject
{	
	IBOutlet NSMenuItem	*authorizeTwitterMenuItem;
	IBOutlet NSMenuItem	*enableTwitterMenuItem;
}

- (IBAction) signInOutClicked: (id) sender;
- (IBAction) enableTwitter: (id) sender;

- (void) sendTweet: (NSString *) tweet;
- (void) signInToTwitter;
- (void) signOut;
- (BOOL) isSignedIn;
- (void) getTwitterInfo;

- (GTMOAuthAuthentication *) authForTwitter;

- (void) windowController:(GTMOAuthWindowController *)windowController
         finishedWithAuth:(GTMOAuthAuthentication *)auth
                    error:(NSError *)error;

- (void) updateUI;
- (void) signInNetworkLost:(NSNotification *)note;

@property (nonatomic, retain) GTMOAuthAuthentication *myAuth;
@property (nonatomic, retain) NSString *twitterHandle;
@property (nonatomic, retain) NSString *twitterUserName;

@end
