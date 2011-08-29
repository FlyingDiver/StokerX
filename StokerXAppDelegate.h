//
//  StokerXAppDelegate.h
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JSON.h"
#import "Stoker.h"
#import "PreferencesController.h"
#import "NotificationController.h"
#import "LVColorWellCell.h"
#import "nsColorSupport.h"
#import "StokerXTwitter.h"
#import "CorePlot/CorePlot.h"
#import "Sparkle/Sparkle.h"

@interface StokerXAppDelegate : NSObject <NSApplicationDelegate, CPTPlotDataSource, NSTableViewDataSource, StokerDelegate, LVColorWellCellDelegate> {

    IBOutlet NSButton				*startStopButton;
	IBOutlet NSTextField			*statusField;
	IBOutlet NSTextField			*totalBlowerActivityField;
	IBOutlet NSTextField			*recentBlowerActivityField;
	IBOutlet NSPopUpButton			*blowerActivityDurationPopup;
	IBOutlet NSMenuItem				*notificationListMenuItem;
	
    IBOutlet NSWindow				*mainWindow;
    IBOutlet NSWindow				*notificationsWindow;
	IBOutlet NSTableView			*sensorTable;
    IBOutlet CPTLayerHostingView	*graphView;
	
	IBOutlet PreferencesController	*preferencesController;
	IBOutlet StokerXTwitter			*doAnAuthenticatedAPIFetch;
	IBOutlet NotificationController	*notificationController;

	Stoker							*theStoker;

	NSTimeInterval					startTime;
	
	CPTXYGraph						*graph;
	
	NSTimeInterval					plotRange;
	NSTimeInterval					plotMaxTime;
	double							plotMinTemp;
    double							plotMaxTemp;
	
	NSMutableDictionary				*stokerData;
    
	Boolean							exitWaiting;
	
	IBOutlet SUUpdater				*SparkleUpdater;
}

- (IBAction)showPreferencePanel:(id)sender;
- (IBAction)showNotificationsWindow:(id)sender;
- (IBAction) startLogging: (id) sender;

- (void) setStatusText: (NSString *) status;
- (void) plotSetup;

@property (nonatomic, assign) NSTimeInterval			startTime;
@property (nonatomic, retain) CPTXYGraph				*graph;
@property (nonatomic, retain) StokerXTwitter			*tweetController;
@property (nonatomic, retain) PreferencesController		*preferencesController;
@end
