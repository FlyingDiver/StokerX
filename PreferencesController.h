//
//  PreferencesController.h
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//
// Manages the preferences panel

#import <Cocoa/Cocoa.h>

extern NSString * const kStokeripAddressKey;
extern NSString * const kStokerhttpPortKey;
extern NSString * const kMinGraphTempKey;
extern NSString * const kMaxGraphTempKey;
extern NSString * const kTelnetKey;
extern NSString * const kEmailAddressKey;
extern NSString * const kLidOffEnabledKey;
extern NSString * const kLidOffDropKey;
extern NSString * const kLidOffWaitKey;
extern NSString * const kSendTweets;

@interface PreferencesController : NSWindowController
{
	IBOutlet NSTextField *ipAddress;
	IBOutlet NSTextField *httpPort;
	IBOutlet NSButton    *telnetCheckBox;
	IBOutlet NSTextField *minGraphTemp;
	IBOutlet NSTextField *maxGraphTemp;
	IBOutlet NSTextField *emailAddress;
	IBOutlet NSButton    *lidOffCheckBox;
	IBOutlet NSTextField *lidOffDrop;
	IBOutlet NSTextField *lidOffWait;
}

- (IBAction)changeStokeripAddressField:(id)sender;
- (IBAction)changeStokerhttpPortField:(id)sender;
- (IBAction)changeTelnetMode:(id)sender;
- (IBAction)changeMinGraphTempField:(id)sender;
- (IBAction)changeMaxGraphTempField:(id)sender;
- (IBAction)changeEmailAddressField:(id)sender;
- (IBAction)changeLidOffEnabled:(id)sender;
- (IBAction)changeLidOffDrop:(id)sender;
- (IBAction)changeLidOffWait:(id)sender;

@end
