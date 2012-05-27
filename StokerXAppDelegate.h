//
//  StokerXAppDelegate.h
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Sparkle/Sparkle.h"
#import "FeedbackReporter/FRFeedbackReporter.h"
#import "Stoker.h"
#import "HelpController.h"
#import "PreferencesController.h"
#import "NotificationController.h"
#import "LVColorWellCell.h"
#import "MiniTwitter.h"
#import "StokerPlotController.h"

@interface StokerXAppDelegate : NSObject <NSApplicationDelegate, FRFeedbackReporterDelegate, NSTableViewDataSource, StokerDelegate, LVColorWellCellDelegate> 
{
	IBOutlet NSWindow				*mainWindow;

    IBOutlet NSButton				*startStopButton;
	IBOutlet NSTextField			*statusField;
	IBOutlet NSTextField			*totalBlowerActivityField;
	IBOutlet NSTextField			*recentBlowerActivityField;
	IBOutlet NSTextField			*startTimeField;
	IBOutlet NSTextField			*elapsedTimeField;
	IBOutlet NSPopUpButton			*blowerActivityDurationPopup;
	IBOutlet NSTableView			*sensorTable;

	IBOutlet NSMenuItem				*notificationListMenuItem;
	IBOutlet NotificationController	*notificationController;	
	IBOutlet HelpController			*helpController;
	IBOutlet StokerPlotController	*plotController;

	Stoker							*theStoker;
	    
	NSInvocation					*updateInvocation;
	
	Boolean					loggingActive;
	NSTimeInterval			startTime;
	CPTXYGraph				*graph;
	MiniTwitter				*tweetController;
	PreferencesController		*preferencesController;
}

- (IBAction) showReadMe:(id)sender;
- (IBAction) showHelpWindow:(id)sender;
- (IBAction) showFeedbackForm:(id)sender;
- (IBAction) showPreferencePanel:(id)sender;
- (IBAction) showNotificationsWindow:(id)sender;
- (IBAction) startLogging: (id) sender;
- (IBAction) lidDetectOnOff:(id)sender;

- (void) setStatusText: (NSString *) status;
- (void) updateUI;

@property (nonatomic, retain) IBOutlet NSWindow			*mainWindow;
@property (assign)			  Boolean					loggingActive;
@property (nonatomic, assign) NSTimeInterval			startTime;
@property (nonatomic, retain) CPTXYGraph				*graph;
@property (nonatomic, retain) MiniTwitter				*tweetController;
@property (nonatomic, retain) PreferencesController		*preferencesController;
@end
