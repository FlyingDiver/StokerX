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
#import "GTMOAuthWindowController.h"
#import "JSON.h"

// These two strings identify the application (StokerX) sending the tweet

//#define	kOAuthConsumerKey		@"UjMLz291haVFTs1cRdVA"
//#define	kOAuthConsumerSecret	@"H9dgyFaEZhbFK45lZs7CdCACKnBAM1Jnj7rLmw5SJk"

// These are for the test application

#define kOAuthConsumerKey		@"E4PzQuxgs0qbNvthaW61rg"
#define kOAuthConsumerSecret	@"3h2wjBs9fMPGg4Vbfx4fNROxyX2amQf6CBo5rdg"

#define MAX_MESSAGE_LENGTH		140		// twitter max

@interface StokerXTwitter : NSObject
{
	GTMOAuthAuthentication *mAuth;
	
	IBOutlet NSMenuItem	*authorizeTwitterMenuItem;
	IBOutlet NSMenuItem	*enableTwitterMenuItem;
}

- (IBAction) signInOutClicked: (id) sender;
- (IBAction) enableTwitter: (id) sender;

- (void) sendTweet: (NSString *) tweet;


@end
