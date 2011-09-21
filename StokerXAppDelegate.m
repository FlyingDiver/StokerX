//
//  StokerXAppDelegate.m
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "StokerXAppDelegate.h"

@implementation StokerXAppDelegate

@synthesize mainWindow, updateTimer, startTime, graph, tweetController, preferencesController, loggingActive;

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
	[defaultValues setObject:[NSNumber numberWithInt: 0]   forKey:kHTTPOnlyKey];
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
	
	// Use saved position of main window, and show it.
	
	[mainWindow setFrameAutosaveName:@"Main Window"];
    [mainWindow makeKeyAndOrderFront:nil];
			
	// get a Stoker object
	
	theStoker = [[Stoker alloc] init];
	theStoker.delegate = self;
	theStoker.stokerAvailable = FALSE;
	
	stokerData = [[NSMutableDictionary alloc] initWithCapacity:4];
	
	plotController.stoker = theStoker;
	plotController.stokerData = stokerData;
	plotController.plotMinTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey] doubleValue];
	plotController.plotMaxTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey] doubleValue];
    
	// attempt to connect to Stoker if IP address is set, if not show the preference panel

	if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey])
	{
		[theStoker connectToIPAddress: [[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey]];
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

	self.updateTimer = [NSTimer scheduledTimerWithTimeInterval: GRAPH_UPDATE_INTERVAL target: self selector:@selector(updateUI:) userInfo: nil repeats:YES];
	[self updateUI: updateTimer];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{				
	BOOL shutdownNow = [theStoker shutdownWithCompletionHandler:^(void) 
	{
//		[NSApp replyToApplicationShouldTerminate:YES];
		[[NSRunningApplication currentApplication] terminate];
	}];

	if (!shutdownNow)
	{
		[self setStatusText: @"Waiting for Stoker Reset"];
//		return NSTerminateLater;   
		return NSTerminateCancel;   
	}

	[self setStatusText: @"StokerX Terminating"];
	return NSTerminateNow;			
}
- (void) updateUI: (NSTimer *) theTimer
{
//	NSLog(@"StokerXAppDelegate: updateUI:");

	NSTimeInterval elapsedTime;

	if ([sensorTable currentEditor] != nil)		// don't update - table is being edited
		return;
	
	// update elapsed time
	
	if (theStoker.isLogging) 
	{
		elapsedTime = [[NSDate date] timeIntervalSinceReferenceDate] - startTime;
	}
	else
	{
		elapsedTime = 0.0;
		startTime  = [[NSDate date] timeIntervalSinceReferenceDate];
	}
	
	NSInteger seconds = fmod(elapsedTime , 60);	
	NSInteger minutes = fmod(elapsedTime / 60, 60);
	NSInteger hours =   elapsedTime /60 / 60;
	NSString* elapsedTimeString = [NSString stringWithFormat: @"%02d:%02d:%02d", hours, minutes, seconds];
	[elapsedTimeField setStringValue: elapsedTimeString];

	[sensorTable reloadData];	

	[plotController updateGraphWithStartTime: startTime andElapsedTime: elapsedTime];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualTo: kStokeripAddressKey])
	{
		[theStoker connectToIPAddress: [[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey]];
	}
	else if ([keyPath isEqualTo: kMaxGraphTempKey])
	{
		plotController.plotMaxTemp = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
	}
	else if ([keyPath isEqualTo: kMinGraphTempKey])
	{
		plotController.plotMinTemp = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
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
				
		if ([[[NSUserDefaults standardUserDefaults] stringForKey: kHTTPOnlyKey] boolValue])
			theStoker.useTelnet = FALSE;	
		else
			theStoker.useTelnet = TRUE;
		
		if ([[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffEnabledKey] boolValue])
		{
			[theStoker enableLidDetection: TRUE 
								 withDrop: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffDropKey] doubleValue]
								  andWait: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffWaitKey] doubleValue]];
		} else
			[theStoker enableLidDetection: FALSE withDrop:0 andWait:0.0];

		
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

- (IBAction) savePlotData:(id)sender
{
	NSSavePanel * savePanel = [NSSavePanel savePanel];
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"StokerX"]];
	
    [savePanel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSInteger result)
	{
        if (result == NSFileHandlingPanelOKButton) 
		{
            [savePanel orderOut:self];
			[stokerData writeToFile: [[savePanel URL] path] atomically: NO];
		}
    }];
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
//	NSLog(@"StokerXAppDelegate: tableView: setObjectValue: forTableColumn: %@ row: %d", [tableColumn identifier], rowIndex);

	if ([[tableColumn identifier] isEqual: @"SensorName"])
	{
		[theStoker setName: newValue forSensor: rowIndex];
		[[stokerData objectForKey: [theStoker idForSensor: rowIndex]] setObject: newValue forKey: @"name"];		
	}
	else if ([[tableColumn identifier] isEqual: @"TargetTemp"])
	{
		[theStoker setTarget: newValue forSensor: rowIndex];
		[[stokerData objectForKey: [NSString stringWithFormat: @"%@ Target", [theStoker idForSensor: rowIndex]]] setObject: newValue forKey: @"target"];
	}
}

#pragma mark -
#pragma mark Stoker Delegate Methods

//	Sent when the Stoker has completed it's setup (connected to Stoker and read sensor info)

- (void) stokerHasCompletedSetup: (Stoker *) stk
{
	NSLog(@"Stoker is running version %@", [stk stokerVersion]);
	
	[plotController plotSetup];
	
    for (int i = 0; i < [theStoker numberOfSensors]; i++)
    {		
		[notificationController addSensor: [theStoker idForSensor: i] name: [theStoker nameForSensor: i]];
	}
	[notificationListMenuItem setEnabled: YES];
	
	[self setStatusText: @"Stoker Setup Complete"];
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
		
		if (updateWaiting)
		{
			[updateInvocation invoke];
		}
		
		if (exitWaiting)
		{			
			[[NSRunningApplication currentApplication] terminate];
		}
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


// Sent when the stoker has updated Sensor temp
- (void) stoker: (Stoker *) stk updateSensorTemp: (NSNumber *) sensorTemp forSensor: (NSString *) sensorID
{
//	NSLog(@"stoker:updateSensorTemp: %@ forSensor %@", sensorTemp, sensorID);

	NSNumber *currentTime = [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]];
		
	[[stokerData objectForKey: sensorID] setObject: sensorTemp forKey: @"temp"];

	[[[stokerData objectForKey: sensorID] objectForKey: @"plotData"] addObject: [NSArray arrayWithObjects: currentTime, sensorTemp, nil]];	
	
	// Since we don't get target temperature updates from the Stoker, create them here as needed.
	
	NSString *targetID =       [NSString stringWithFormat: @"%@ Target", sensorID];
	NSNumber *tempTarget =     [[stokerData objectForKey: targetID] objectForKey: @"target"];
	NSMutableArray *plotData = [[stokerData objectForKey: targetID] objectForKey: @"plotData"];
			
	[plotData addObject: [NSArray arrayWithObjects: currentTime, tempTarget, nil]];
		
	// See if this new reading triggers any notifications
	
	[notificationController checkSensor: sensorID andTemp: sensorTemp];
}

// Sent when the stoker has updated Blower data
- (void) stoker: (Stoker *) stk updateBlowerState: (Boolean) active forBlower: (NSString *) blowerID
{
//	NSLog(@"stoker:updateBlowerState: %@ forBlower %@", active ? @"ON" : @"OFF", blowerID);

   	NSNumber *currentTime = [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]];
	NSMutableDictionary *theBlower = [stokerData objectForKey: blowerID]; 
	NSMutableArray	*blowerPlotData = [theBlower objectForKey:@"plotData"];
							   
//	[blowerPlotData addObject: [NSArray arrayWithObjects: currentTime, [NSNumber numberWithDouble: ((double) active * BLOWER_STEP)], nil]];
	[blowerPlotData addObject: [NSArray arrayWithObjects: currentTime, [NSNumber numberWithInt: active], nil]];
		
	NSInteger activeCount = [[theBlower objectForKey: @"count"] intValue];

	if (active)
	{
		activeCount++;
		[theBlower setObject:[NSNumber numberWithInt: activeCount] forKey: @"count"];
	}
	
	// recalculate and display the blower duty cycle info
	
	double totalCycleRatio = (double) activeCount / (double) [blowerPlotData count];
	
	[totalBlowerActivityField  setStringValue: [NSString stringWithFormat:@"%3.0f%%", totalCycleRatio * 100.0]];
	
	int onCount = 0, totalCount = 0;
	NSArray *record;
	
	int index = [blowerPlotData count] - 1;
	
	double interval = (double) [[blowerActivityDurationPopup selectedItem] tag] * 60.0;		// in seconds 
	double current = [[NSDate date] timeIntervalSinceReferenceDate];
	
	double earliest = current - interval;
		
	while (index >= 0) 
	{
		record = [blowerPlotData objectAtIndex: index];
		
		double timestamp = [[record objectAtIndex:0] doubleValue];
		
		if (timestamp < earliest)	// earlier than sample period
			break;
		
		totalCount++;
		
		int blowerOn = [[record objectAtIndex:1] intValue];
		
		if (blowerOn != 0)
			onCount++;
				
		index--;
	}
		
	if (totalCount > 0)
	{
		[recentBlowerActivityField setStringValue: [NSString stringWithFormat:@"%3.0f%%", (((float) onCount / (float) totalCount) * 100.0)]];
	}
	else
	{
		[recentBlowerActivityField setStringValue: @"0%"];
		
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

