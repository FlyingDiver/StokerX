//
//  PreferencesController.h
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//
// Manages the preferences panel

#import <Cocoa/Cocoa.h>
#import "EmailSender.h"
#import "SSKeychain.h"

extern NSString * const kStokeripAddressKey;
extern NSString * const kMinGraphTempKey;
extern NSString * const kMaxGraphTempKey;
extern NSString * const kHTTPOnlyModeKey;
extern NSString * const kReportTemplateKey;
extern NSString * const kSendTweetsKey;
extern NSString * const kSendPushMessagesKey;

extern NSString * const kEmailAddressKey;
extern NSString * const kSMTPServerKey;
extern NSString * const kSMTPPortKey;
extern NSString * const kConnectionTypeKey;
extern NSString * const kAuthTypeKey;
extern NSString * const kStokerSMTPLogin;

@interface PreferencesController : NSWindowController
{
	IBOutlet NSTextField		*ipAddress;
	IBOutlet NSButton			*httpOnlyModeCheckBox;
	IBOutlet NSTextField		*minGraphTemp;
	IBOutlet NSTextField		*maxGraphTemp;
	IBOutlet NSPopUpButton		*templatePopup;
	IBOutlet NSTextField		*emailAddress;
}

- (IBAction)changeStokeripAddressField:(id)sender;
- (IBAction)changeHTTPOnlyMode:(id)sender;
- (IBAction)changeMinGraphTempField:(id)sender;
- (IBAction)changeMaxGraphTempField:(id)sender;
- (IBAction)changeTemplatePopup:(id)sender;
- (IBAction)changeEmailAddressField:(id)sender;
- (IBAction)validateSMTP:(id)sender;
- (IBAction)stokerCommHelp:(id)sender;
- (IBAction)smtpHelp:(id)sender;

@property (assign) IBOutlet NSTextField			*smtpServer;
@property (assign) IBOutlet NSTextField			*smtpPort;
@property (assign) IBOutlet NSTextField			*smtpUsername;
@property (assign) IBOutlet NSSecureTextField	*smtpPassword;
@property (assign) IBOutlet NSPopUpButton		*connectionType;
@property (assign) IBOutlet NSPopUpButton		*authType;
@property (assign) IBOutlet NSButton			*validateButton;
@property (assign) IBOutlet NSProgressIndicator *busyIndicator;
@property (assign) IBOutlet NSTextField			*messageField;

@end
