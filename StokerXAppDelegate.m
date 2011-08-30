//
//  StokerXAppDelegate.m
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "StokerXAppDelegate.h"

@implementation StokerXAppDelegate

@synthesize startTime, graph, tweetController, preferencesController;

#define TIME_RANGE_START		10*60.0         // 10 minutes

#pragma mark -
#pragma mark Application startup and Delegate Methods

-(void)awakeFromNib
{	    
	// Set up support for the color well in the sensor table
	
	NSUInteger index = [sensorTable columnWithIdentifier:@"color"];  
	NSTableColumn *colorColumn = [[sensorTable tableColumns] objectAtIndex:index];  
	LVColorWellCell * colorCell = [[LVColorWellCell alloc] init];  
	[colorCell setDelegate: self];
	[colorCell setColorKey:@"color"];  
	[colorColumn setDataCell:colorCell]; 
		
	// Create graph from theme
    graph = [(CPTXYGraph *)[CPTXYGraph alloc] initWithFrame:CGRectZero];
	CPTTheme *theme = [CPTTheme themeNamed:kCPTSlateTheme];
	[graph applyTheme:theme];
	graphView.hostedLayer = graph;

	// add some padding
	graph.paddingLeft = 10.0;
	graph.paddingTop = 10.0;
	graph.paddingRight = 10.0;
	graph.paddingBottom = 10.0;
	
	graph.plotAreaFrame.paddingTop = 20.0;
	graph.plotAreaFrame.paddingBottom = 50.0;
	graph.plotAreaFrame.paddingLeft = 50.0;
	graph.plotAreaFrame.paddingRight = 20.0;
	graph.plotAreaFrame.cornerRadius = 10.0;
	
	// initial graphing bounds
	
	plotRange = TIME_RANGE_START;
	startTime  = [[NSDate date] timeIntervalSinceReferenceDate];
	
    // Setup scatter plot space

	double minTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey] doubleValue];
	double maxTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey] doubleValue];
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
	plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(startTime) length:CPTDecimalFromDouble(plotRange)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minTemp) length:CPTDecimalFromDouble(maxTemp - minTemp)];
	
    // Axes
	CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
	CPTXYAxis *x = axisSet.xAxis;
    CPTXYAxis *y = axisSet.yAxis;
    
	CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle];
	lineStyle.lineColor = [CPTColor blackColor];
	lineStyle.lineWidth = 2.0f;
	
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    CPTTimeFormatter *timeFormatter = [[[CPTTimeFormatter alloc] initWithDateFormatter:dateFormatter] autorelease];
    
	x.majorIntervalLength = CPTDecimalFromDouble(plotRange/5.0);
    x.minorTicksPerInterval = 0;
    x.labelFormatter = timeFormatter;
	x.majorTickLineStyle = lineStyle;
	x.minorTickLineStyle = lineStyle;
	x.axisLineStyle = lineStyle;
	x.majorTickLength = 7.0f;
	x.labelOffset = 3.0f;
	x.orthogonalCoordinateDecimal = CPTDecimalFromDouble(minTemp);
	
    y.majorIntervalLength = CPTDecimalFromDouble((maxTemp - minTemp)/5);;
	y.minorTicksPerInterval = 0;
	y.majorTickLineStyle = lineStyle;
	y.minorTickLineStyle = lineStyle;
	y.axisLineStyle = lineStyle;
	y.minorTickLength = 5.0f;
	y.majorTickLength = 7.0f;
	y.labelOffset = 3.0f;
	y.orthogonalCoordinateDecimal = CPTDecimalFromDouble(startTime);
}	

- (void) applicationDidFinishLaunching:(NSNotification *) notes
{	
//	Enabling this causes Fetcher logs to be written to the desktop!
//	[GTMHTTPFetcher setLoggingEnabled:YES];

    [[FRFeedbackReporter sharedReporter] setDelegate:self];
	[[FRFeedbackReporter sharedReporter] reportIfCrash];
	
	// Use saved position of main window, and show it.
	
	[mainWindow setFrameAutosaveName:@"Main Window"];
    [mainWindow makeKeyAndOrderFront:nil];
			
	// get a Stoker object
	
	theStoker = [[Stoker alloc] init];
	theStoker.delegate = self;
	theStoker.stokerAvailable = FALSE;
	
	// attempt to connect to Stoker if IP address is set, if not show the preference panel

	if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey])
	{
        if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokerhttpPortKey])
        {
            [theStoker connectToIPAddress: [[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey] 
                                  andPort: [[NSUserDefaults standardUserDefaults] stringForKey: kStokerhttpPortKey]];
        }
        else
        {
            [theStoker connectToIPAddress: [[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey] 
                                  andPort: @"80"];           
            
        }
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
	if (theStoker.telnetActive)		// don't quit with the Stoker in telnet mode
	{
		exitWaiting = TRUE;
		[theStoker stopLogging];
		[self setStatusText: @"Waiting for Stoker to exit telnet mode"];
		return NSTerminateCancel;	
	}

	[self setStatusText: @"StokerX Terminating"];
	return NSTerminateNow;	
}


- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filepath
{
	NSLog(@"NSApp application:openFile: %@", filepath);
	
	return NO;
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
				
		if ([[[NSUserDefaults standardUserDefaults] stringForKey: kTelnetKey] boolValue])
			theStoker.useTelnet = TRUE;	
		else
			theStoker.useTelnet = FALSE;
		
		if ([[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffEnabledKey] boolValue])
		{
			[theStoker enableLidDetection: TRUE 
								 withDrop: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffDropKey] doubleValue]
								  andWait: [[[NSUserDefaults standardUserDefaults] stringForKey: kLidOffWaitKey] doubleValue]];
		} else
			[theStoker enableLidDetection: FALSE withDrop:0 andWait:0.0];

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

- (IBAction)showNotificationsWindow:(id)sender
{	
	[notificationController showWindow: self];
}

- (IBAction)showFeedbackForm:(id)sender
{
	[[FRFeedbackReporter sharedReporter] reportFeedback];
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

// Configure the plots and data structures based on the sensors and blowers found

- (void) plotSetup
{
    // set up the plots based on the Stoker info
	
    CPTScatterPlot *linePlot;
    CPTMutableLineStyle *lineStyle;
    int sensorCount = 0;
    NSArray *sensorColors =  [NSArray arrayWithObjects: [NSColor redColor], [NSColor blueColor], [NSColor greenColor], [NSColor cyanColor], nil];
    NSColor *plotColor = nil;
	
	stokerData = [[NSMutableDictionary alloc] initWithCapacity:4];
	
    for (int i = 0; i < [theStoker numberOfBlowers]; i++)
    {        
		// First, create an entry in the stokerData dictionary for this blower
		
		[stokerData setObject:	[NSMutableDictionary dictionaryWithObjectsAndKeys: 
								 [theStoker nameForBlower: i], @"name", 
								 [NSNumber numberWithInt: 0],  @"count",
								 [NSMutableArray arrayWithCapacity: 1000], @"plotData", 
								 nil]
					   forKey: [theStoker idForBlower: i]];
		
        linePlot = [[CPTScatterPlot alloc] init];
        linePlot.identifier = [theStoker idForBlower: i];
        linePlot.interpolation = CPTScatterPlotInterpolationStepped;
        linePlot.dataSource = self;
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 1.0f;
        lineStyle.lineColor = [CPTColor blackColor];
        linePlot.dataLineStyle = lineStyle;
        
        [graph addPlot:linePlot];
        [linePlot release];
    }
	
	// get info on the sensors from the Stoker
	
    for (int i = 0; i < [theStoker numberOfSensors]; i++)
    {		
		// First, create an entry in the stokerData dictionary for this sensor
		
		[stokerData setObject:	[NSMutableDictionary dictionaryWithObjectsAndKeys: 
								 [theStoker nameForSensor: i], @"name", 
								 [theStoker typeForSensor: i], @"type", 
								 [theStoker tempForSensor: i], @"temp",
								 [NSMutableArray arrayWithCapacity: 1000], @"plotData", 
								 nil]
					   forKey: [theStoker idForSensor: i]];
		
		[stokerData setObject:	[NSMutableDictionary dictionaryWithObjectsAndKeys: 
								 [theStoker nameForSensor: i], @"name", 
								 [theStoker targetForSensor: i], @"target",
								 [NSMutableArray arrayWithCapacity: 1000], @"plotData", 
								 nil]
					   forKey: [NSString stringWithFormat: @"%@ Target", [theStoker idForSensor: i]]];
		
        plotColor = [[NSUserDefaults standardUserDefaults]  colorForKey: [NSString stringWithFormat: @"PlotColor %@", [theStoker idForSensor: i]]];
        if (!plotColor)
        {
            plotColor = [sensorColors objectAtIndex: sensorCount];
            sensorCount++;
            [[NSUserDefaults standardUserDefaults] setColor: plotColor forKey: [NSString stringWithFormat: @"PlotColor %@", [theStoker idForSensor: i]]];
        }
        [self colorCell: nil setColor: plotColor forRow: i];
        
        // Create a plot for the sensor data
        linePlot = [[CPTScatterPlot alloc] init];
        linePlot.identifier = [theStoker idForSensor: i];
        linePlot.dataSource = self;			
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 1.5f;
        lineStyle.lineColor = [CPTColor colorWithCGColor: CPTNewCGColorFromNSColor(plotColor)];
        linePlot.dataLineStyle = lineStyle;
        
        [graph addPlot:linePlot];
        [linePlot release];
        
        // Create a plot for the sensor target
        linePlot = [[CPTScatterPlot alloc] init];
        linePlot.identifier = [NSString stringWithFormat:@"%@ Target", [theStoker idForSensor: i]];
        linePlot.dataSource = self;
        linePlot.interpolation = CPTScatterPlotInterpolationStepped;
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 2.0f;
        lineStyle.lineColor = [CPTColor colorWithCGColor: CPTNewCGColorFromNSColor(plotColor)];
        lineStyle.dashPattern = [NSArray arrayWithObjects:[NSNumber numberWithFloat:5.0f], [NSNumber numberWithFloat:5.0f], nil];
        linePlot.dataLineStyle = lineStyle;
		
        [graph addPlot:linePlot];
        [linePlot release];
    }
	
	// Save a copy of the plot setup data for debugging purposes
		
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: @"StokerX"];
	NSString *saveFilePath = [supportDir stringByAppendingPathComponent: @"PlotSetupData.plist"];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath: saveFilePath] == NO)
	{
		[fileManager createDirectoryAtPath: supportDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	if (![stokerData writeToFile: saveFilePath atomically: NO])
		NSLog(@"StokerX save PlotSetupData failed");

}


#pragma mark -
#pragma mark Plot Data Source Methods

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
//	NSLog(@"StokerXAppDelegate: numberOfRecordsForPlot: %@ = %d", plot.identifier, [[[stokerData objectForKey: plot.identifier] objectForKey: @"data"] count]);
	
	return [[[stokerData objectForKey: plot.identifier] objectForKey: @"plotData"] count];
	
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{	
//	NSLog(@"StokerXAppDelegate: numberForPlot: %@[%d, %d] = %@", plot.identifier, fieldEnum, index, [[[[stokerData objectForKey: plot.identifier] objectForKey: @"data"] objectAtIndex: index] objectAtIndex: fieldEnum]);
	
    return [[[[stokerData objectForKey: plot.identifier] objectForKey: @"plotData"] objectAtIndex: index] objectAtIndex: fieldEnum];
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
		
		NSArray *thePlots = [graph allPlots];				  
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

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{	
//	NSLog(@"StokerXAppDelegate: tableView: setObjectValue: forTableColumn: %@ row: %d", [tableColumn identifier], rowIndex);

	if ([[tableColumn identifier] isEqual: @"SensorName"])
	{
		[theStoker setName: anObject forSensor: rowIndex];

		NSString *sensorID = [theStoker idForSensor: rowIndex];
		[[stokerData objectForKey: sensorID] setObject: anObject forKey: @"name"];		
}
	else if ([[tableColumn identifier] isEqual: @"TargetTemp"])
	{
		[theStoker setTarget: anObject forSensor: rowIndex];
		
		NSString *sensorID = [theStoker idForSensor: rowIndex];
		NSString *targetID = [NSString stringWithFormat: @"%@ Target", sensorID];
		[[stokerData objectForKey: targetID] setObject: anObject forKey: @"target"];
	}
	else if ([[tableColumn identifier] isEqual: @"Notifications"])
	{
		// edit internal alarm table here
	}
	else if ([[tableColumn identifier] isEqual: @"color"])
	{
		// Nothing to do here, it's done in the delegate for the color well view
	}
}

#pragma mark -
#pragma mark Stoker Delegate Methods

//	Sent when the Stoker has completed it's setup (connected to Stoker and read sensor info)

- (void) stokerHasCompletedSetup: (Stoker *) stk
{
	NSLog(@"Stoker is running version %@", [stk stokerVersion]);
	
	[self plotSetup];
	[sensorTable reloadData];	
			
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

//	Sent when the Stoker has new sensor data

- (void) stokerHasUpdatedSensorData: (Stoker *) stk
{
//	NSLog(@"stokerHasUpdatedSensorData:");
	
	if ([sensorTable currentEditor] != nil)		// don't update - table is being edited
		return;
	
	// could check for minimum time since last update here, if we're chewing up too much CPU redisplaying the graphs...
	
	
	CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
	CPTXYAxisSet   *axisSet   = (CPTXYAxisSet *)graph.axisSet;
	
	// First, check to see if the horizontal axis needs to be re-scaled
	
	if (([[NSDate date] timeIntervalSinceReferenceDate] - startTime) > plotRange)
	{
		plotRange = plotRange * 2.0;				// double previous range
		
		plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(startTime) length:CPTDecimalFromDouble(plotRange)];
		
		axisSet.xAxis.majorIntervalLength = CPTDecimalFromDouble(plotRange/5.0);
	}
	
	// Check to see if the temperature range has changed from Preferences
	
	double minTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey] doubleValue];
	double maxTemp = [[[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey] doubleValue];
	
	if ((minTemp != plotMinTemp) || (maxTemp != plotMaxTemp))
	{
		plotMaxTemp = maxTemp;
		plotMinTemp = minTemp;
		
		plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minTemp) length:CPTDecimalFromDouble(maxTemp - minTemp)];
		
		axisSet.yAxis.majorIntervalLength = CPTDecimalFromDouble((maxTemp - minTemp)/5);;
		
		axisSet.xAxis.orthogonalCoordinateDecimal = CPTDecimalFromDouble(minTemp);
	}

	[graph reloadData];
	[sensorTable reloadData];	
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
		if (exitWaiting)
		{			
			[[NSRunningApplication currentApplication] terminate];
		}
	}
}


// Sent when the stoker has updated Sensor temp
- (void) stoker: (Stoker *) stk updateSensorTemp: (NSNumber *) sensorTemp forSensor: (NSString *) sensorID
{
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
   	NSNumber *currentTime = [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]];
	NSMutableDictionary *theBlower = [stokerData objectForKey: blowerID]; 
	NSMutableArray	*blowerPlotData = [theBlower objectForKey:@"plotData"];
	int activeCount = 0;
							   
	[blowerPlotData addObject: [NSArray arrayWithObjects: currentTime, [NSNumber numberWithDouble: ((double) active * BLOWER_STEP)], nil]];
		
	if (active)
	{
		activeCount = [[theBlower objectForKey: @"count"] intValue];
		activeCount++;
		[theBlower setObject:[NSNumber numberWithInt: activeCount] forKey: @"count"];
	}
	
	// recalculate and display the blower duty cycle info
	
	double totalCycleRatio = (double) activeCount / (double) [blowerPlotData count];
	
	[totalBlowerActivityField  setStringValue: [NSString stringWithFormat:@"%3.0f%%", totalCycleRatio * 100.0]];
	
	int onCount = 0, totalCount = 0;
	NSArray *record;
	
	int index = [[theBlower  objectForKey: @"count"] intValue] - 1;
	
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
	
	double recentCycleRatio = 0.0;
	
	if (totalCount > 0)
	{
		recentCycleRatio = (((float) onCount / (float) totalCount) * 100.0);
	}
	
	[recentBlowerActivityField setStringValue: [NSString stringWithFormat:@"%3.0f%%", recentCycleRatio]];
}

#pragma mark -
#pragma mark Color Well Delegate Methods

-(void)colorCell:(LVColorWellCell *)colorCell setColor:(NSColor *)nsColor forRow:(int)row
{
	CPTColor *cpColor = [CPTColor colorWithCGColor: CPTNewCGColorFromNSColor(nsColor)];
	
	NSString *rowID = [theStoker idForSensor: row];
		
	NSArray *thePlots = [graph allPlots];				  
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
	
	NSArray *thePlots = [graph allPlots];				  
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

//- (NSDictionary*) customParametersForFeedbackReport
//{
//   return [NSDictionary dictionaryWithObjectsAndKeys:@"StokerX", @"application", nil];
//}


#pragma mark -
#pragma mark Sparkle Updater Delegate Methods

- (void)appcastDidFinishLoading:(SUAppcast *)appcast
{
	NSLog(@"appcastDidFinishLoading: %@", appcast);
}

- (void)appcast:(SUAppcast *)appcast failedToLoadWithError:(NSError *)error
{
	NSLog(@"appcast: %@ failedToLoadWithError: %@", appcast, error);
}

// Implement this if you want to do some special handling with the appcast once it finishes loading.
- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast
{
	NSLog(@"Updater didFinishLoadingAppcast:");
	for (SUAppcastItem *item in [appcast items])
	{
		NSLog(@"\t%@ - %@ (%@)", [item title], [item displayVersionString], [item versionString]);
	}
}

// Sent when a valid update is found by the update driver.
- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
	NSLog(@"Updater:didFindValidUpdate: %@ - %@ (%@)", [update title], [update displayVersionString], [update versionString]);
}

// Sent when a valid update is not found.
- (void)updaterDidNotFindUpdate:(SUUpdater *)update
{
	NSLog(@"updaterDidNotFindUpdate");
}

// Sent immediately before installing the specified update.
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
	NSLog(@"Updater:willInstallUpdate: %@ - %@ (%@)", [update title], [update displayVersionString], [update versionString]);
}

// Called immediately before relaunching.
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater
{
	NSLog(@"updaterWillRelaunchApplication");

}

@end

