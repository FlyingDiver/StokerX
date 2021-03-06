//
//  StokerXAppDelegate.m
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "StokerXAppDelegate.h"

@implementation StokerXAppDelegate

@synthesize mainWindow, mainView, notesWindow, notesView, startTime, endTime, graph, pushController, tweetController, preferencesController, loggingActive;

#define MINUTES					60.0
#define TIME_RANGE_START		20 * MINUTES    
#define PLOT_INTERVAL_START		5 * MINUTES    

#pragma mark -
#pragma mark Application startup and Delegate Methods

+(void) initialize
{
	NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
	
	[defaultValues setObject: [NSNumber numberWithInt: 50]  forKey:kMinGraphTempKey];
	[defaultValues setObject: [NSNumber numberWithInt: 300] forKey:kMaxGraphTempKey];
	[defaultValues setObject: [NSNumber numberWithInt: 0]   forKey:kHTTPOnlyModeKey];
	[defaultValues setObject: @"Default"					forKey:kReportTemplateKey];

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
	
	[notesView setFont: [NSFont fontWithName: @"Times New Roman" size: 14.0]];
	[notesView setRichText:NO];
	[notesView setUsesFontPanel:NO];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notes
{	
	[self setStatusText: [NSString stringWithFormat: @"Starting StokerX %@ (%@)",
						  [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleShortVersionString"],
						  [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]
						  ]];

	//	Enabling this causes Fetcher logs to be written to the desktop!
	
	if ([[[NSUserDefaults standardUserDefaults] stringForKey: @"EnableGTMHTTPFetcherLogging"] boolValue])
		[GTMHTTPFetcher setLoggingEnabled:YES];
	

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
	
	// make sure templates are in the Support Directory
		
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *templateDir = [[[paths objectAtIndex:0] stringByAppendingPathComponent: [[NSProcessInfo processInfo] processName]] stringByAppendingPathComponent: @"Templates"];

	// make sure there is a Template directory
	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
	
	if ([fileManager fileExistsAtPath: templateDir] == NO)
	{
		[fileManager createDirectoryAtPath: templateDir withIntermediateDirectories:YES attributes:nil error: nil];
	}
	
	// copy included templates into directory - Deletes old templates first!
	
	NSString *bundleTemplatePath = [NSString stringWithFormat: @"%@/Templates", [[NSBundle mainBundle] resourcePath]];
	NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath: bundleTemplatePath];
	
	NSString *file;
	BOOL isDir;
	NSString *newTemplateDir;
	while ((file = [dirEnum nextObject]))
	{
		NSString *bundleFile = [NSString stringWithFormat: @"%@/%@", bundleTemplatePath, file];
		[fileManager fileExistsAtPath: bundleFile isDirectory: &isDir];
		if (isDir)
		{
			newTemplateDir = [NSString stringWithFormat: @"%@/%@", templateDir, file];
			[fileManager createDirectoryAtPath: newTemplateDir withIntermediateDirectories:YES attributes:nil error: nil];
		}
		else
		{
			NSString *templateFilePath = [NSString stringWithFormat: @"%@/%@", templateDir, file];
			[fileManager removeItemAtPath: templateFilePath error:nil];
			[fileManager copyItemAtPath: bundleFile toPath: templateFilePath error: nil];
		}
	}

	// get a Stoker object
	
	theStoker = [[Stoker alloc] init];
	theStoker.delegate = self;
		
	plotController.stoker = theStoker;
	plotController.plotMinTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey] doubleValue];
	plotController.plotMaxTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey] doubleValue];
	[plotController setupGraph];

	// Set up to get text commands via twitter
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveTwitterDirectMessage:) name: MiniTwitter_DirectMessage object: nil];

	notificationController.tweetController = tweetController;
	notificationController.pushController = pushController;
	
	// Use saved position of main window, and show it.
	
	[mainWindow setFrameAutosaveName:@"Main Window"];
    [mainWindow makeKeyAndOrderFront:nil];
	
	startTime  = [[NSDate date] timeIntervalSinceReferenceDate];
	endTime  = [[NSDate date] timeIntervalSinceReferenceDate];
	
	// attempt to connect to Stoker if IP address is set, if not show the preference panel

	if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey])
	{
		theStoker.ipAddress = [[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey];
		[theStoker connectWithCompletionHandler:^(void) 
		{
			NSLog(@"StokerXAppDelegate: Initial Stoker connection completed");
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
		NSLog(@"StokerXAppDelegate: App terminating after telnet reset");
		[NSApp replyToApplicationShouldTerminate:YES];
	}];

	if (!shutdownNow)
	{
		[self setStatusText: @"Shutdown waiting for Stoker Reset"];
		return NSTerminateLater;   
	}

	NSLog(@"StokerXAppDelegate: App terminating immediately");
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
		endTime = [[NSDate date] timeIntervalSinceReferenceDate];

		elapsedTime = endTime - startTime;
		NSInteger seconds = fmod(elapsedTime , 60);	
		NSInteger minutes = fmod(elapsedTime / 60, 60);
		NSInteger hours =   elapsedTime / 60 / 60;
		NSString* elapsedTimeString = [NSString stringWithFormat: @"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
		[elapsedTimeField setStringValue: elapsedTimeString];
		
		[totalBlowerActivityField  setStringValue: [NSString stringWithFormat:@"%3.0f%%", [theStoker totalBlowerRatio] * 100.0]];
		[recentBlowerActivityField setStringValue: [NSString stringWithFormat:@"%3.0f%%", [theStoker recentBlowerRatio: [[blowerActivityDurationPopup selectedItem] tag]] * 100.0]];
	}
	else
	{
		elapsedTime = 0;
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
}

#pragma mark -
#pragma mark Text Command Methods

- (void) receiveTwitterDirectMessage: (NSNotification *) notification
{
	NSMutableArray *tokenList = [self parseDirectMessage: [notification object]];
	
	if ([[tokenList objectAtIndex: 0] caseInsensitiveCompare: @"status"] == NSOrderedSame)
	{
		NSMutableString *response = [NSMutableString stringWithString: @"StokerX status:"];
		for (int i = 0; i < [theStoker numberOfSensors]; i++)
		{
			[response appendFormat: @"\n%@ = %@", [theStoker nameForSensor: i], [theStoker tempForSensor: i]];
		}
		[tweetController sendTweet: response];
	}
	else if ([[tokenList objectAtIndex: 0] caseInsensitiveCompare: @"set"] == NSOrderedSame)
	{
		NSString *sensor = [NSString stringWithString: [tokenList objectAtIndex: 1]];
		NSString *temp = [NSString stringWithString: [tokenList objectAtIndex: 2]];
		
		[tweetController sendTweet: [NSString stringWithFormat: @"Temperature for sensor \"%@\" set to %@", sensor, temp]];
		for (int i = 0; i < [theStoker numberOfSensors]; i++)
		{
			if ([sensor caseInsensitiveCompare: [theStoker nameForSensor: i]] == NSOrderedSame)
			{
				[theStoker setTarget: [NSNumber numberWithInt: [temp integerValue]] forSensorID: [theStoker idForSensor: i]];
				break;
			}
		}
	}
	else
	{
		[tweetController sendTweet: [NSString stringWithFormat: @"Unknown Direct Message received: %@", [tokenList objectAtIndex: 0]]];
	}
}

- (NSMutableArray *) parseDirectMessage: (NSString *) message
{
	NSString *token = nil;
	NSMutableArray *tokenList = [[[NSMutableArray alloc] initWithCapacity: 10] autorelease];
	
	NSScanner *scanner = [NSScanner scannerWithString: message];
	
	//	NSLog(@"MiniTwitter parseDirectMessage: message = %@", message);
	
	while (scanner.scanLocation < message.length)
	{
		// test if the next character is a quote
		unichar character = [message characterAtIndex:scanner.scanLocation];
		if (character == '"')
		{
			// skip the first quote and scan everything up to the next quote into the token
			[scanner setScanLocation:(scanner.scanLocation + 1)];
			[scanner scanUpToString:@"\"" intoString: &token];
			[scanner setScanLocation:(scanner.scanLocation + 1)];  // skip the second quote too
		}
		else
		{
			// scan everything up to the next space into the token
			[scanner scanUpToString:@" " intoString: &token];
		}
		
		//		NSLog(@"MiniTwitter parseDirectMessage: token = %@", token);
		[tokenList addObject: token];
		
		//if not at the end, skip the space character before continuing the loop
		if (scanner.scanLocation < message.length) [scanner setScanLocation:(scanner.scanLocation + 1)];
	}
	
	return tokenList;
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
		endTime  = [[NSDate date] timeIntervalSinceReferenceDate];
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
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://stokerx.com/user-guide"]];
}

- (IBAction)showReadMe:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://stokerx.com/release-notes"]];
}

- (IBAction)showNotes:(id)sender
{
	[notesWindow makeKeyAndOrderFront: self];
}



- (IBAction)showNotificationsWindow:(id)sender
{	
	[notificationController showWindow: self];
}


- (IBAction)showFeedbackForm:(id)sender
{
	[[FRFeedbackReporter sharedReporter] reportFeedback];
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
		NSString *sensorID = [theStoker idForSensor: rowIndex];
		
		[theStoker setName: newValue forSensor: rowIndex];
		[notificationController addSensor: sensorID name: newValue];
		[[plotController.graph plotWithIdentifier: sensorID] setTitle: newValue];
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
#pragma mark Plot Controller Delegate Methods

- (void) plotController: (StokerPlotController *) plotController addedNoteNumber: (NSInteger) noteNumber
{
	NSString *prefix;
	
	if (noteNumber == 1)
		prefix = [NSString stringWithFormat: @"(%ld) ", (long) noteNumber];
	else
		prefix = [NSString stringWithFormat: @"\n(%ld) ", (long) noteNumber];
	
	
    NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
    [attributes setObject: [NSFont fontWithName: @"Times New Roman" size: 14.0] forKey:NSFontAttributeName];
	NSAttributedString *string = [[[NSAttributedString alloc] initWithString:  prefix attributes: attributes] autorelease];
	
	[[notesView textStorage] beginEditing];
	[[notesView textStorage] appendAttributedString:string];
	[[notesView textStorage] endEditing];
	
	[notesWindow makeKeyAndOrderFront: self];
}

- (void) plotController: (StokerPlotController *) plotController selectedNoteWithString: (NSString *) string
{
	NSRange ptr = [[[notesView textStorage] string] rangeOfString: string];
	[notesView setSelectedRange: NSMakeRange(ptr.location, 0)];
	[notesWindow makeKeyAndOrderFront: self];
}


#pragma mark -
#pragma mark Color Well Delegate Methods

-(void)colorCell:(LVColorWellCell *)colorCell setColor:(NSColor *)nsColor forRow:(int)row
{
	CPTColor *cpColor = [CPTColor colorWithCGColor: CPTCreateCGColorFromNSColor(nsColor)];
	
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

-(NSColor *)colorCell:(LVColorWellCell *)colorCell colorForRow:(int)row
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
#pragma mark Printing methods

- (void)print:(id)sender
{
	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
    NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];
	
	NSMutableDictionary *reportDict = [[[NSMutableDictionary alloc] init] autorelease];
	[reportDict setObject: @"StokerX Session Report" forKey: @"ReportTitle"];
	
    NSSize paperSize = [printInfo paperSize];
    NSRect printableRect = [printInfo imageablePageBounds];
	
    // calculate page margins
    float marginL = printableRect.origin.x;
    float marginR = paperSize.width - (printableRect.origin.x + printableRect.size.width);
    float marginB = printableRect.origin.y;
    float marginT = paperSize.height - (printableRect.origin.y + printableRect.size.height);
	
    // Make sure margins are symetric and positive
    float marginLR = MAX(0,MAX(marginL,marginR));
    float marginTB = MAX(0,MAX(marginT,marginB));
    
    // Tell printInfo what the nice new margins are
    [printInfo setLeftMargin:   marginLR];
    [printInfo setRightMargin:  marginLR];
    [printInfo setTopMargin:    marginTB];
    [printInfo setBottomMargin: marginTB];
	[printInfo setHorizontalPagination: NSAutoPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[[printInfo dictionary] setObject: [NSNumber numberWithBool:YES] forKey: NSPrintHeaderAndFooter];
	
    NSRect printViewFrame = {};
    printViewFrame.size.width = paperSize.width - marginLR*2;
	[reportDict setObject: [NSString stringWithFormat: @"%d", (int) printViewFrame.size.width] forKey: @"FrameWidth"];
    printViewFrame.size.height = paperSize.height - marginTB*2;
	[reportDict setObject: [NSString stringWithFormat: @"%d", (int) printViewFrame.size.height] forKey: @"FrameHeight"];
	
	
	WebView *printView = [[WebView alloc] initWithFrame: printViewFrame frameName: nil groupName: nil];
	[printView setShouldUpdateWhileOffscreen: YES];
	[printView setUIDelegate: self];
	[printView setFrameLoadDelegate: self];
	
	WebPreferences *webPref = [printView preferences];
	[webPref setAutosaves: NO];
	[webPref setShouldPrintBackgrounds:YES];
	[printView setPreferences:webPref];
	
	// Get the graph image and put it in the temp directory
	
	NSString *tempDir = NSTemporaryDirectory();
	NSString *graphPath = [tempDir stringByAppendingPathComponent:@"StokerXPlot.pdf"];
	NSData	*plotImageData = [plotController.graph dataForPDFRepresentationOfLayer];
	[plotImageData writeToURL: [NSURL fileURLWithPath: graphPath] atomically: YES];
	[reportDict setObject: graphPath forKey: @"GraphURL"];
	
	// set up Support Directory paths
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: [[NSProcessInfo processInfo] processName]];
	NSString *templateDir = [NSString stringWithFormat: @"%@/Templates/%@", supportDir, [[NSUserDefaults standardUserDefaults] stringForKey: kReportTemplateKey]];

	// copy template resources into temp dir, if there are any, creating dictionary keys while doing so
	
	NSArray *resourceList = [fileManager contentsOfDirectoryAtPath: templateDir error: nil];
	for (NSString *resource in resourceList)
	{		
		NSString *resourcePath = [NSString stringWithFormat: @"%@/%@", templateDir, resource];
		NSString *destPath = [NSString stringWithFormat: @"%@%@", tempDir, resource];
		[fileManager removeItemAtPath: destPath error:nil];
		[fileManager copyItemAtPath: resourcePath toPath: destPath error: nil];
		[reportDict setObject: destPath forKey: [resource stringByDeletingPathExtension]];
	}
	
	// Convert the text from the Notes panel to HTML for the printed output
	
	NSAttributedString *notes = [notesView textStorage];
	NSData *textData = [notes dataFromRange:NSMakeRange(0, notes.length) documentAttributes:
							 [NSDictionary dictionaryWithObjectsAndKeys:NSPlainTextDocumentType, NSDocumentTypeDocumentAttribute, nil] error:NULL];	
	NSString *textString = [[NSString alloc] initWithData: textData encoding:NSUTF8StringEncoding];
	NSString *htmlString = [textString stringByReplacingOccurrencesOfString:@"\n" withString:@"<br />"];
	[reportDict setObject: htmlString forKey: @"NotesText"];
	[textString release];
	[htmlString release];

	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	dateFormatter.dateStyle = NSDateFormatterShortStyle;
	dateFormatter.timeStyle = NSDateFormatterShortStyle;
	dateFormatter.locale = [NSLocale currentLocale];
	[reportDict setObject: [dateFormatter stringFromDate: [NSDate dateWithTimeIntervalSinceReferenceDate: startTime]]
				   forKey: @"StartTime"];

	NSTimeInterval reportEndTime;
	if ([theStoker isLogging])
	{
		reportEndTime = [[NSDate date] timeIntervalSinceReferenceDate];
	}
	else
	{
		reportEndTime = endTime;
	}
	[reportDict setObject: [dateFormatter stringFromDate: [NSDate dateWithTimeIntervalSinceReferenceDate: reportEndTime]]
				   forKey: @"EndTime"];
	
	NSTimeInterval elapsedTime = reportEndTime - startTime;
	[reportDict setObject: [NSString stringWithFormat: @"%02ld:%02ld:%02ld", (long)elapsedTime / 60 / 60, (long)fmod(elapsedTime / 60, 60), (long)fmod(elapsedTime , 60)]
				   forKey: @"ElapsedTime"];


	// build an array of dicts for the sensor table
	
	NSMutableArray *sensors = [[[NSMutableArray alloc] initWithCapacity: 10] autorelease];
	for (int i = 0; i < [theStoker numberOfSensors]; i++)
	{
		[sensors addObject: [[[NSDictionary alloc] initWithObjectsAndKeys:
							 [theStoker typeForSensor: i], @"type",
							 [theStoker nameForSensor: i], @"name",
							 [theStoker targetForSensor: i], @"target",
							 [theStoker blowerForSensor: i], @"blower",
							 nil] autorelease]];
	}
	[reportDict setObject: sensors forKey: @"Sensors"];
		
	// use the template engine to generate the document HTML
	
	NSString *selectedTemplate = [[NSUserDefaults standardUserDefaults] stringForKey: kReportTemplateKey];
	NSString *templateFilePath = [NSString stringWithFormat: @"%@/Templates/%@/%@.html", supportDir, selectedTemplate, selectedTemplate];
	
    GRMustacheTemplate *template = [GRMustacheTemplate templateFromContentsOfFile: templateFilePath error: NULL];

    NSString *webviewHTMLString = [template renderObject: reportDict error:NULL];

	// Load the frame, print it in the delegate when the load is complete
	
	[[printView mainFrame] loadHTMLString: webviewHTMLString baseURL: [NSURL URLWithString: graphPath]];
	
}

// WebView delegate methods

//	WebView has completed loading, so it can be printed now.

- (void)webView:(WebView *) printView didFinishLoadForFrame:(WebFrame *)frame
{
    NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];
	
	NSPrintOperation *printOp = [NSPrintOperation printOperationWithView: [[[printView mainFrame] frameView] documentView] printInfo: printInfo];
	[printOp setShowsPrintPanel: YES];
    [printOp runOperation];
	[printView release];
}

#pragma mark -
#pragma mark Feedback Reporter Delegate Methods


- (NSString *) targetUrlForFeedbackReport
{
	return @"http://www.stokerx.com/submitfeedback.php";
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

