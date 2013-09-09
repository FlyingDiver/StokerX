//
//  Prowl.h
//
//  Created by Joe Keenan on 8/26/2013.
//  Copyright 2013 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GTMHTTPFetcher.h"
#import "XMLReader.h"
#import "PreferencesController.h"
#import "StokerXAppDelegate.h"
#import "SSKeychain.h"

#define kProwlProviderKey		@"3a39c167ce5245449e94ae43a6fb97ae49c25e09"

@interface Prowl : NSObject
{
	IBOutlet NSMenuItem	*authorizeProwlMenuItem;
	IBOutlet NSMenuItem	*enableProwlMenuItem;

	NSString *prowlAPIKey;
}

- (void) signInToProwl;
- (void) sendPushMessage: (NSString *) message;

- (IBAction) signInOutClicked: (id) sender;
- (IBAction) enableProwl: (id) sender;
- (void) updateUI;

@property (nonatomic, copy) NSString *prowlAPIKey;
@end
