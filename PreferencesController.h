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
extern NSString * const kMinGraphTempKey;
extern NSString * const kMaxGraphTempKey;
extern NSString * const kHTTPOnlyModeKey;
extern NSString * const kEmailAddressKey;
extern NSString * const kSendTweetsKey;
extern NSString * const kReportTemplateKey;
extern NSString * const kSendPushMessagesKey;
extern NSString * const kProwlAuthCodeKey;

@interface PreferencesController : NSWindowController
{
	IBOutlet NSTextField	*ipAddress;
	IBOutlet NSButton		*httpOnlyModeCheckBox;
	IBOutlet NSTextField	*minGraphTemp;
	IBOutlet NSTextField	*maxGraphTemp;
	IBOutlet NSTextField	*emailAddress;
	IBOutlet NSPopUpButton	*templatePopup;
}

- (IBAction)changeStokeripAddressField:(id)sender;
- (IBAction)changeHTTPOnlyMode:(id)sender;
- (IBAction)changeMinGraphTempField:(id)sender;
- (IBAction)changeMaxGraphTempField:(id)sender;
- (IBAction)changeEmailAddressField:(id)sender;
- (IBAction)changeTemplatePopup:(id)sender;

@end
