//
//  MiniTwitter
//
//  Created by Joe Keenan on 8/13/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GTMOAuthWindowController.h"
#import "PreferencesController.h"
#import "JSON.h"

// These are the keys for the callback version, they are specific to each application using MiniTwitter

#define kOAuthConsumerKey		@"kyL5j7Ba5cxhgW89xueCGg"
#define kOAuthConsumerSecret	@"IMoG4ycflD9OhFFBrmi8UtjBcOdIRFmxsNdrYVao"

#define MiniTwitter_DirectMessage	@"MiniTwitter_DirectMessage"

#define MAX_MESSAGE_LENGTH		140		// twitter max

@interface MiniTwitter : NSObject
{	
	IBOutlet NSMenuItem	*authorizeTwitterMenuItem;
	IBOutlet NSMenuItem	*enableTwitterMenuItem;

	GTMOAuthAuthentication *myAuth;
	NSString *twitterHandle;
	NSString *twitterUserName;
	NSString *directMessageSinceId;
	NSError *lastError;
	int lastErrorCount;
}

- (IBAction) signInOutClicked: (id) sender;
- (IBAction) enableTwitter: (id) sender;

- (void) sendTweet: (NSString *) tweet;
- (void) signInToTwitter;
- (void) signOut;
- (BOOL) isSignedIn;
- (void) getTwitterInfo;
- (void) getDirectMessages: (NSTimer *) theTimer;

- (GTMOAuthAuthentication *) authForTwitter;

- (void) windowController:(GTMOAuthWindowController *)windowController
         finishedWithAuth:(GTMOAuthAuthentication *)auth
                    error:(NSError *)error;

- (void) updateUI;
- (void) signInNetworkLost:(NSNotification *)note;
- (void) reportError: (NSError *) error fromQuery: (NSString *) query;

@property (nonatomic, retain) GTMOAuthAuthentication *myAuth;
@property (nonatomic, copy) NSString *twitterHandle;
@property (nonatomic, copy) NSString *twitterUserName;
@property (nonatomic, copy) NSString *directMessageSinceId;
@property (nonatomic, copy) NSError *lastError;
@property (nonatomic) int lastErrorCount;
@end
