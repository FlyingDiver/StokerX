//
//  StokerXAppDelegate.h
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "CorePlot/CorePlot.h"
#import "Sparkle/Sparkle.h"
#import "FeedbackReporter/FRFeedbackReporter.h"
#import "GTMOAuth/GTMHTTPFetcherLogging.h"
#import "Stoker.h"
#import "PreferencesController.h"
#import "NotificationController.h"
#import "LVColorWellCell.h"
#import "StokerPlotController.h"
#import "GRMustache/GRMustache.h"
#import "MiniTwitter.h"
#import "EmailSender.h"

@interface StokerXAppDelegate : NSObject <NSApplicationDelegate, FRFeedbackReporterDelegate, NSTableViewDataSource,
											StokerDelegate, StokerPlotControllerDelegate, LVColorWellCellDelegate>
{
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSView					*mainView;
	
	IBOutlet NSWindow				*notesWindow;
	IBOutlet NSTextView				*notesView;

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
	IBOutlet StokerPlotController	*plotController;
	IBOutlet MiniTwitter			*tweetController;
    IBOutlet Prowl					*pushController;

	Stoker							*theStoker;
	NSInvocation					*updateInvocation;
	
	Boolean						loggingActive;
	NSTimeInterval				startTime;
	NSTimeInterval				endTime;
	CPTXYGraph					*graph;
	PreferencesController		*preferencesController;
}

- (IBAction) showNotes:(id)sender;
- (IBAction) showReadMe:(id)sender;
- (IBAction) showHelpWindow:(id)sender;
- (IBAction) showFeedbackForm:(id)sender;
- (IBAction) showPreferencePanel:(id)sender;
- (IBAction) showNotificationsWindow:(id)sender;
- (IBAction) startLogging: (id) sender;
- (IBAction) print:(id)sender;

- (void) receiveTwitterDirectMessage: (NSNotification *) message;
- (NSMutableArray *) parseDirectMessage: (NSString *) message;

- (void) updateUI;

@property (nonatomic, retain) IBOutlet NSWindow			*mainWindow;
@property (nonatomic, retain) IBOutlet NSWindow			*notesWindow;
@property (nonatomic, retain) IBOutlet NSView			*mainView;
@property (nonatomic, retain) IBOutlet NSTextView		*notesView;
@property (assign)			  Boolean					loggingActive;
@property (nonatomic, assign) NSTimeInterval			startTime;
@property (nonatomic, assign) NSTimeInterval			endTime;
@property (nonatomic, retain) CPTXYGraph				*graph;
@property (nonatomic, retain) MiniTwitter				*tweetController;
@property (nonatomic, retain) Prowl						*pushController;
@property (nonatomic, retain) PreferencesController		*preferencesController;
@end
