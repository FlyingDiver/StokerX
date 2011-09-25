//
//  StokerXAppDelegate.m
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "StokerXAppDelegate.h"

@implementation StokerXAppDelegate

@synthesize mainWindow, startTime, graph, tweetController, preferencesController, loggingActive;

#define MINUTES	60.0
#define TIME_RANGE_START		20 * MINUTES    
#define PLOT_INTERVAL_START		5 * MINUTES    
#define GRAPH_UPDATE_INTERVAL	5.0

#pragma mark -
#pragma mark Application startup and Delegate Methods

+(void) initialize
{
	NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
	
	[defaultValues setObject:[NSNumber numberWithInt: 50]  forKey:kMinGraphTempKey];
	[defaultValues setObject:[NSNumber numberWithInt: 300] forKey:kMaxGraphTempKey];
	[defaultValues setObject:[NSNumber numberWithInt: 50]  forKey:kLidOffDropKey];
	[defaultValues setObject:[NSNumber numberWithInt: 300] forKey:kLidOffWaitKey];
	[defaultValues setObject:[NSNumber numberWithInt: 0]   forKey:kHTTPOnlyModeKey];
	[defaultValues setObject:[NSNumber numberWithInt: 0]   forKey:kLidOffEnabledKey];

	[defaultValues setObject:[NSNumber numberWithInt: 86400] forKey:@"SUScheduledCheckInterval"];
	[defaultValues setObject:[NSNumber numberWithInt: 1]     forKey:@"SUEnableAutomaticChecks"];
	[defaultValues setObject:[NSNumber numberWithInt: 1]     forKey:@"SUSendProfileInfo"];

	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
}

-(void)awakeFromNib
{	    	
	// Set up support for the color well in the sensor table
	
	LVColorWellCell * colorCell = [[LVColorWellCell alloc] init];  
	[colorCell setDelegate: self];
	[colorCell setColorKey:@"color"];  

	NSTableColumn *colorColumn = [[sensorTable tableColumns] objectAtIndex: [sensorTable columnWithIdentifier:@"color"]];  
	[colorColumn setDataCell:colorCell]; 
}

- (void) applicationDidFinishLaunching:(NSNotification *) notes
{	
	[self setStatusText: @"Starting StokerX"];

//	Enabling this causes Fetcher logs to be written to the desktop!
//	[GTMHTTPFetcher setLoggingEnabled:YES];

    [[FRFeedbackReporter sharedReporter] setDelegate:self];
	[[FRFeedbackReporter sharedReporter] reportIfCrash];
	
	// Watch for some preference changes
	
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: kStokeripAddressKey
											   options: NSKeyValueObservingOptionNew
											   context: NULL];
	
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: kMaxGraphTempKey
											   options: NSKeyValueObservingOptionNew
											   context: NULL];
	
	
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: kMinGraphTempKey
											   options: NSKeyValueObservingOptionNew
											   context: NULL];
	
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: kEmailAddressKey
											   options: NSKeyValueObservingOptionNew
											   context: NULL];
	
	// get a Stoker object
	
	theStoker = [[Stoker alloc] init];
	theStoker.delegate = self;
		
	plotController.stoker = theStoker;
	plotController.plotMinTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey] doubleValue];
	plotController.plotMaxTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey] doubleValue];
	[plotController setupGraph];
	
	notificationController.tweetController = tweetController;
	
	// Use saved position of main window, and show it.
	
	[mainWindow setFrameAutosaveName:@"Main Window"];
    [mainWindow makeKeyAndOrderFront:nil];
	
	// attempt to connect to Stoker if IP address is set, if not show the preference panel

	if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey])
	{
		theStoker.ipAddress = [[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey];
		[theStoker connectWithCompletionHandler:^(void) 
		{
			NSLog(@"connectWithCompletionHandler called");
		}];
		[self updateUI];
	}
	else
	{
		[self showPreferencePanel: self];

		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"No IP address for Stoker"];
		[alert setInformativeText:@"Please enter the Stoker IP address in the Preferences Panel"];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		[alert runModal];
		[alert release];
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{				
	BOOL shutdownNow = [theStoker shutdownWithCompletionHandler:^(void) 
	{
		[NSApp replyToApplicationShouldTerminate:YES];
	}];

	if (!shutdownNow)
	{
		[self setStatusText: @"Waiting for Stoker Reset"];
		return NSTerminateLater;   
	}

	[self setStatusText: @"StokerX Terminating"];
	return NSTerminateNow;			
}
- (void) updateUI
{
//	NSLog(@"StokerXAppDelegate: updateUI:");

	NSTimeInterval elapsedTime;

	if ([sensorTable currentEditor] != nil)		// don't update - table is being edited
		return;
	
	// update elapsed time
	
	if (theStoker.isLogging) 
	{
		elapsedTime = [[NSDate date] timeIntervalSinceReferenceDate] - startTime;

		NSInteger seconds = fmod(elapsedTime , 60);	
		NSInteger minutes = fmod(elapsedTime / 60, 60);
		NSInteger hours =   elapsedTime /60 / 60;
		NSString* elapsedTimeString = [NSString stringWithFormat: @"%02d:%02d:%02d", hours, minutes, seconds];
		[elapsedTimeField setStringValue: elapsedTimeString];
		
		[totalBlowerActivityField  setStringValue: [NSString stringWithFormat:@"%3.0f%%", [theStoker totalBlowerRatio] * 100.0]];
		[recentBlowerActivityField setStringValue: [NSString stringWithFormat:@"%3.0f%%", [theStoker recentBlowerRatio: [[blowerActivityDurationPopup selectedItem] tag]] * 100.0]];
	}
	else
	{
		elapsedTime = 0.0;
		startTime  = [[NSDate date] timeIntervalSinceReferenceDate];

		[totalBlowerActivityField  setStringValue: @"0%"];
		[recentBlowerActivityField setStringValue: @"0%"];
	}
	
	[sensorTable reloadData];	
	[plotController updateGraphWithStartTime: startTime andElapsedTime: elapsedTime];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualTo: kStokeripAddressKey])
	{
		theStoker.ipAddress = [change objectForKey:NSKeyValueChangeNewKey];
	}
	else if ([keyPath isEqualTo: kMaxGraphTempKey])
	{
		plotController.plotMaxTemp = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		[self updateUI];
	}
	else if ([keyPath isEqualTo: kMinGraphTempKey])
	{
		plotController.plotMinTemp = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		[self updateUI];
	}
	else if ([keyPath isEqualTo: kEmailAddressKey])
	{
	}
}


#pragma mark -
#pragma mark UI Action Methods

- (IBAction) startLogging: (id) sender
{		
	if ([[sender title] isEqualToString: @"Start"])
	{				
		if (!theStoker.stokerAvailable)	// still don't have one, so must be a problem connecting to it
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert addButtonWithTitle:@"OK"];
			[alert setMessageText:@"Unable to communicate with Stoker."];
			[alert setInformativeText:@"Please check the IP address in the Preferences Panel, and ensure the Stoker is accessible via your network."];
			[alert setAlertStyle:NSWarningAlertStyle];
			
			[alert runModal];
			[alert release];
			
			return;
		}
				
		theStoker.httpOnlyMode = [[[NSUserDefaults standardUserDefaults] stringForKey: kHTTPOnlyModeKey] boolValue];
		
		[theStoker enableLidDetection: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffEnabledKey] boolValue] 
							 withDrop: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffDropKey] doubleValue]
							  andWait: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffWaitKey] doubleValue]];

		
		startTime  = [[NSDate date] timeIntervalSinceReferenceDate];					// reset on actual start of logging
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		dateFormatter.dateStyle = NSDateFormatterShortStyle;
		dateFormatter.timeStyle = NSDateFormatterShortStyle;
		dateFormatter.locale = [NSLocale currentLocale];
		[startTimeField setStringValue: [dateFormatter stringFromDate: [NSDate dateWithTimeIntervalSinceReferenceDate: startTime]]];

		[theStoker startLogging];
		
		[sender setTitle: @"Stop"];
	}
	else if ([[sender title] isEqualToString: @"Stop"])
	{			
		[theStoker stopLogging];
		[sender setTitle: @"Start"];
	}
	else
		NSLog(@"StokerX unknown button command state");
}

- (void) setStatusText: (NSString *) status
{
	NSLog(@"StokerXAppDelegate: statusText: %@", status);
	[statusField setStringValue: status];
}

- (IBAction)showPreferencePanel:(id)sender
{
	if (!preferencesController) 
		preferencesController = [[PreferencesController alloc] init];
	
	[preferencesController showWindow:self];
}


- (IBAction)showHelpWindow:(id)sender 
{
	if (!helpController) 
		helpController = [[HelpController alloc] init];
	
	[helpController showWindow:self];
}

- (IBAction)showReadMe:(id)sender 
{
	NSString *version =  [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleShortVersionString"];
	NSURL *readMeURL = [NSURL URLWithString: [NSString stringWithFormat: @"http://www.flyingdiver.com/StokerX/StokerX-ReadMe-%@.html", version]];
	
	[[NSWorkspace sharedWorkspace] openURL: readMeURL];
}



- (IBAction)showNotificationsWindow:(id)sender
{	
	[notificationController showWindow: self];
}


- (IBAction)showFeedbackForm:(id)sender
{
	[[FRFeedbackReporter sharedReporter] reportFeedback];
}

- (IBAction)lidDetectOnOff:(NSButtonCell *)sender 
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender state] forKey: kLidOffEnabledKey];
	[theStoker enableLidDetection: [sender state] 
						 withDrop: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffDropKey] doubleValue]
						  andWait: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffWaitKey] doubleValue]];

}

#pragma mark -
#pragma mark Table View Methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{	
    return [theStoker numberOfSensors];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{		    
	if ([[tableColumn identifier] isEqual: @"SensorType"])
	{
		return [theStoker typeForSensor: row];
	}
	else if ([[tableColumn identifier] isEqual: @"SensorName"])
	{
		return [theStoker nameForSensor: row];
	}
	else if ([[tableColumn identifier] isEqual: @"SensorID"])
	{
		return [theStoker idForSensor: row];
	}
	else if ([[tableColumn identifier] isEqual: @"CurrTemp"])
	{
		return [theStoker tempForSensor: row];
	}
	else if ([[tableColumn identifier] isEqual: @"TargetTemp"])
	{
		return [theStoker targetForSensor: row];
	}
	else if ([[tableColumn identifier] isEqual: @"Blower"])
	{
		return [theStoker blowerForSensor: row];
	}
	else if ([[tableColumn identifier] isEqual: @"Notifications"])
	{
		return [notificationController notificationsTextForSensor: [theStoker idForSensor: row]];
	}
	else if ([[tableColumn identifier] isEqual: @"color"])
	{
		// Need to find the base plot associated with this row's ID, and return the color it's using

		NSString *rowID = [theStoker idForSensor: row];
		
		NSArray *thePlots = [[plotController graph] allPlots];				  
		for (CPTScatterPlot *plot in thePlots) 
		{						
			if ([rowID isEqualToString: (NSString *) [plot identifier]])
			{
				CPTColor *color = plot.dataLineStyle.lineColor;
				return [color nsColor];
			}			
		}
		return nil;
	}
	
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)newValue forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{	
	if ([[tableColumn identifier] isEqual: @"SensorName"])
	{
		[theStoker setName: newValue forSensor: rowIndex];
		[notificationController addSensor: [theStoker idForSensor: rowIndex] name:[theStoker nameForSensor: rowIndex]];
	}
	else if ([[tableColumn identifier] isEqual: @"TargetTemp"])
	{
		[theStoker setTarget: newValue forSensor: rowIndex];
	}
}

#pragma mark -
#pragma mark Stoker Delegate Methods

//	Sent when the Stoker has completed it's setup (connected to Stoker and read sensor info)

- (void) stokerHasCompletedSetup: (Stoker *) stk
{
	NSLog(@"Stoker is running version %@", [stk stokerVersion]);
	
	[plotController setupPlots];
	[self updateUI];
	
    for (int i = 0; i < [theStoker numberOfSensors]; i++)
    {		
		[notificationController addSensor: [theStoker idForSensor: i] name: [theStoker nameForSensor: i]];
	}
	[notificationListMenuItem setEnabled: YES];
	
	[self setStatusText: @"Stoker Setup Complete"];
}

// Sent when the stoker has updated Sensor temps

- (void) stokerSensorUpdate: (Stoker *) stk
{	
    for (int i = 0; i < [theStoker numberOfSensors]; i++)
    {		
		[notificationController checkSensor: [theStoker idForSensor: i] andTemp: [theStoker tempForSensor: i]];
	}
	
	[self updateUI];
}

// Sent when the HTTP/JSON connection has an error

- (void) stoker: (Stoker *) stk httpError: (NSString *) theError
{
	NSLog(@"stoker:httpError: %@", theError);
}

// Sent when there is some status change worthy of display :)

- (void) stoker: (Stoker *) stk statusUpdate: (NSString *) theStatus
{    
	[self setStatusText: theStatus];
}

// Sent when the telnet connection changes status

- (void) stoker: (Stoker *) stk telnetActive: (Boolean) active
{
	if (active)
	{
		[self setStatusText: @"Telnet connection active"];
	}
	else
	{
		[self setStatusText: @"Telnet connection inactive"];
	}
}


// Sent when the telnet connection changes status

- (void) stoker: (Stoker *) stk isLogging: (Boolean) active
{
	self.loggingActive = active;
	
	if (active)
	{
		[self setStatusText: @"Logging Stoker data"];
	}
	else
	{
		[self setStatusText: @"Logging stopped"];
	}
}


#pragma mark -
#pragma mark Color Well Delegate Methods

-(void)colorCell:(LVColorWellCell *)colorCell setColor:(NSColor *)nsColor forRow:(int)row
{
	CPTColor *cpColor = [CPTColor colorWithCGColor: CPTNewCGColorFromNSColor(nsColor)];
	
	NSString *rowID = [theStoker idForSensor: row];
		
	NSArray *thePlots = [[plotController graph] allPlots];				  
	for (CPTScatterPlot *plot in thePlots) 
	{			
		NSString *plotID = (NSString *) [plot identifier];
		
		if (([plotID isEqualToString: rowID]) || ([plotID isEqualToString: [NSString stringWithFormat:@"%@ Target", rowID]]))
		{
			CPTMutableLineStyle *lineStyle = [[plot.dataLineStyle mutableCopy] autorelease];
			lineStyle.lineColor = cpColor;			
			plot.dataLineStyle = lineStyle;
		}			
	 }
	
	[self tableView: sensorTable setObjectValue: [cpColor nsColor] forTableColumn: [[sensorTable tableColumns] objectAtIndex: [sensorTable columnWithIdentifier:@"color"]] row: row];
	[[NSUserDefaults standardUserDefaults] setColor: nsColor forKey: [NSString stringWithFormat: @"PlotColor %@", rowID]];

	return;
}

-(NSColor *)colorCell:(LVColorWellCell *)colorCell 	colorForRow:(int)row
{
	NSColor *nsColor;
	CPTColor *cpColor;
	
	NSString *rowID = [theStoker idForSensor: row];
	
	NSArray *thePlots = [[plotController graph] allPlots];				  
	for (CPTScatterPlot *plot in thePlots) 
	{			
		if ([rowID isEqualToString: (NSString *) [plot identifier]])
		{
			cpColor = plot.dataLineStyle.lineColor;
			nsColor = [[cpColor nsColor] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
			
			return nsColor;
		}			
	}
	return nil;
}


#pragma mark -
#pragma mark Feedback Reporter Delegate Methods


- (NSString *) targetUrlForFeedbackReport
{
	return @"http://www.flyingdiver.com/submitfeedback.php";
}

#pragma mark -
#pragma mark Sparkle Updater Delegate Methods

// Return YES to delay the relaunch until you do some processing; invoke the given NSInvocation to continue.
- (BOOL)updater:(SUUpdater *)updater shouldPostponeRelaunchForUpdate:(SUAppcastItem *)update untilInvoking:(NSInvocation *)invocation
{
	NSLog(@"updater:shouldPostponeRelaunchForUpdate:untilInvoking:");

	BOOL shutdownNow = [theStoker shutdownWithCompletionHandler:^(void) 
	{
		[self setStatusText: @"Restarting for Application Update"];
		[updateInvocation invoke];
	}];
	
	if (!shutdownNow)
	{
		[self setStatusText: @"Waiting for Stoker to restart"];
		updateInvocation = [invocation retain];
		return YES;	
	}
	
	[self setStatusText: @"Restarting for Application Update"];
	return NO;

}

@end

