//
//  StokerPlotController.m
//  StokerX
//
//  Created by Joe Keenan on 9/10/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerPlotController.h"

#define MINUTES	60.0
#define TIME_RANGE_START		20 * MINUTES    
#define PLOT_INTERVAL_START		5 * MINUTES  

#define BLOWER_PLOT_RESERVE		0.10	// 10%, more or less

@implementation CPTGraphHostingView(rightMouseSupport)

- (void)rightMouseDown:(NSEvent *)theEvent
{
	[self mouseDown: theEvent];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	[self mouseDragged: theEvent];
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
	[self mouseUp: theEvent];
}

@end


@implementation StokerPlotController

@synthesize graph, graphView, annotationList, startTime,plotMaxTemp, plotMinTemp, stoker;

-(void)setupGraph
{	    
	NSDateFormatter *dateFormatter;
	
	// initial graphing bounds
	
	plotRange = TIME_RANGE_START;
	startTime  = [[NSDate date] timeIntervalSinceReferenceDate];
		
	// Create graph from theme
    graph = [(CPTXYGraph *)[CPTXYGraph alloc] initWithFrame:CGRectZero];
	CPTTheme *theme = [CPTTheme themeNamed:kCPTSlateTheme];
	[graph applyTheme:theme];
	graphView.hostedGraph = graph;
	
	// add some padding
	graph.paddingLeft = 10.0;
	graph.paddingTop = 10.0;
	graph.paddingRight = 10.0;
	graph.paddingBottom = 10.0;
	
	graph.plotAreaFrame.paddingTop = 40.0;
	graph.plotAreaFrame.paddingBottom = 50.0;
	graph.plotAreaFrame.paddingLeft = 50.0;
	graph.plotAreaFrame.paddingRight = 20.0;
	graph.plotAreaFrame.cornerRadius = 10.0;
	
    // Setup plot space(s) 

	double initialRange = plotMaxTemp - plotMinTemp;
	double displacement = initialRange * BLOWER_PLOT_RESERVE;
	double adjustedStart = plotMinTemp - displacement;
	double adjustedRange = initialRange + displacement;
	
    tempGraphPlotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
	tempGraphPlotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(startTime) length:CPTDecimalFromDouble(plotRange)];
    tempGraphPlotSpace.yRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(adjustedStart) length: CPTDecimalFromDouble(adjustedRange)];
  	tempGraphPlotSpace.identifier = @"SensorPlotSpace";
	tempGraphPlotSpace.allowsUserInteraction = YES;
    tempGraphPlotSpace.delegate = self;
	
	// line styles
    CPTMutableLineStyle *gridLineStyle = [CPTMutableLineStyle lineStyle];
    gridLineStyle.lineWidth = 0.75;
    gridLineStyle.lineColor = [[CPTColor colorWithGenericGray:0.2] colorWithAlphaComponent:0.75];
    
	CPTMutableLineStyle *tickLineStyle = [CPTMutableLineStyle lineStyle];
	tickLineStyle.lineColor = [CPTColor blackColor];
	tickLineStyle.lineWidth = 2.0f;
	
    // Axes
	CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
	CPTXYAxis *timeAxis = axisSet.xAxis;
    CPTXYAxis *tempAxis = axisSet.yAxis;
    
	dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    dateFormatter.dateStyle = NSDateFormatterNoStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    CPTTimeFormatter *timeFormatter = [[[CPTTimeFormatter alloc] initWithDateFormatter:dateFormatter] autorelease];
    
	timeAxis.majorIntervalLength = CPTDecimalFromDouble(PLOT_INTERVAL_START);
    timeAxis.minorTicksPerInterval = 0;
    timeAxis.labelFormatter = timeFormatter;
	timeAxis.majorTickLineStyle = tickLineStyle;
	timeAxis.axisLineStyle = tickLineStyle;
	timeAxis.majorTickLength = 7.0f;
	timeAxis.labelOffset = 3.0f;
	timeAxis.orthogonalCoordinateDecimal = CPTDecimalFromDouble(adjustedStart);
	timeAxis.delegate = self;
	
    tempAxis.majorIntervalLength = CPTDecimalFromDouble(50.0);;
	tempAxis.minorTicksPerInterval = 0;
	tempAxis.majorGridLineStyle = gridLineStyle;
	tempAxis.axisLineStyle = tickLineStyle;
	tempAxis.majorTickLength = 0.0f;
	tempAxis.labelOffset = 3.0f;
	tempAxis.orthogonalCoordinateDecimal = CPTDecimalFromDouble(startTime);
	tempAxis.delegate = self;
	
	NSArray *exclusionRanges  = [NSArray arrayWithObjects:
								 [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-50.0) length:CPTDecimalFromDouble(adjustedStart)],
								 nil];
	tempAxis.labelExclusionRanges = exclusionRanges;
	
	// Add plotSpace for the blower data
    blowerGraphPlotSpace = [[CPTXYPlotSpace alloc] init];
	blowerGraphPlotSpace.identifier = @"BlowerPlotSpace";
	blowerGraphPlotSpace.xRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(startTime) length: CPTDecimalFromDouble(plotRange)];
    blowerGraphPlotSpace.yRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromInt(0) length: CPTDecimalFromInt(20)];
	[graph addPlotSpace: blowerGraphPlotSpace];
	 		
}	

// Configure the plots and data structures based on the sensors and blowers found

- (void) setupPlots
{
    // set up the plots based on the Stoker info
	
    CPTScatterPlot *linePlot;
    CPTMutableLineStyle *lineStyle;
    int sensorCount = 0;
    NSArray *sensorColors =  [NSArray arrayWithObjects: [NSColor redColor], [NSColor blueColor], [NSColor greenColor], [NSColor cyanColor], nil];
    NSColor *plotColor = nil;
	NSMutableArray *legendArray = [NSMutableArray arrayWithCapacity: 10];
		
    for (int i = 0; i < [stoker numberOfBlowers]; i++)
    {        		
        linePlot = [[[CPTScatterPlot alloc] init] autorelease];
        linePlot.identifier = [stoker idForBlower: i];
		linePlot.title = [stoker nameForBlower: i];
        linePlot.interpolation = CPTScatterPlotInterpolationStepped;
        linePlot.dataSource = self;
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 1.0f;
        lineStyle.lineColor = [CPTColor blackColor];
        linePlot.dataLineStyle = lineStyle;
        
		[graph addPlot:linePlot toPlotSpace:blowerGraphPlotSpace];
	}
	
	// get info on the sensors from the Stoker
	
    for (int i = 0; i < [stoker numberOfSensors]; i++)
    {				
        plotColor = [[NSUserDefaults standardUserDefaults]  colorForKey: [NSString stringWithFormat: @"PlotColor %@", [stoker idForSensor: i]]];
        if (!plotColor)
        {
            plotColor = [sensorColors objectAtIndex: sensorCount];
            sensorCount++;
            [[NSUserDefaults standardUserDefaults] setColor: plotColor forKey: [NSString stringWithFormat: @"PlotColor %@", [stoker idForSensor: i]]];
        }
		
		struct CGColor *cgColor = CPTCreateCGColorFromNSColor(plotColor);
		
        // Create a plot for the sensor data
        linePlot = [[[CPTScatterPlot alloc] init] autorelease];
        linePlot.identifier = [stoker idForSensor: i];
        linePlot.title = [stoker nameForSensor: i];
        linePlot.dataSource = self;			
		linePlot.delegate = self;								// only add delegate and HitDetection for plots we want the user to be able to click on
		linePlot.plotSymbolMarginForHitDetection = 5.0f;
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 1.5f;
		lineStyle.lineColor = [CPTColor colorWithCGColor: cgColor];
        linePlot.dataLineStyle = lineStyle;
        
		[graph addPlot:linePlot toPlotSpace:tempGraphPlotSpace];
 		[legendArray addObject: linePlot];
       
        // Create a plot for the sensor target
        linePlot = [[[CPTScatterPlot alloc] init] autorelease];
        linePlot.identifier = [NSString stringWithFormat:@"%@ Target", [stoker idForSensor: i]];
        linePlot.dataSource = self;
        linePlot.interpolation = CPTScatterPlotInterpolationStepped;
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 2.0f;
		lineStyle.lineColor = [CPTColor colorWithCGColor: cgColor];
        lineStyle.dashPattern = [NSArray arrayWithObjects:[NSNumber numberWithFloat:5.0f], [NSNumber numberWithFloat:5.0f], nil];
        linePlot.dataLineStyle = lineStyle;
		
		CFRelease(cgColor);
		[graph addPlot:linePlot toPlotSpace:tempGraphPlotSpace];
    }

	// Add legend
	graph.legend = [CPTLegend legendWithPlots: legendArray];

	lineStyle = [CPTMutableLineStyle lineStyle];
	lineStyle.lineWidth = 0.0f;
	graph.legend.borderLineStyle = lineStyle;

	CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
	graph.legend.textStyle = axisSet.xAxis.titleTextStyle;
	graph.legend.numberOfRows = 1;
	graph.legend.swatchSize = CGSizeMake(25.0, 25.0);
	graph.legendAnchor = CPTRectAnchorTop;
	graph.legendDisplacement = CGPointMake(0.0, -15.0);
}

// Called via timer to update the UI

- (void) updateGraphWithStartTime: (NSTimeInterval) start andElapsedTime: (NSTimeInterval) elapsed
{	
//	NSLog(@"StokerPlotController updateGraphWithStartTime: %f andElapsedTime: %f", start, elapsed);

	CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
	CPTXYAxis *timeAxis = axisSet.xAxis;
    CPTXYAxis *tempAxis = axisSet.yAxis;
	
	// Check to see if the horizontal axis needs to be re-scaled
	
	if (elapsed > (plotRange * 0.95))	// 95% max
	{
		if (plotRange < (90.0 * MINUTES))
		{
			plotRange = plotRange + (15.0 * MINUTES);
		}
		else if (plotRange < (180.0 * MINUTES))
		{
			plotRange = plotRange + (30.0 * MINUTES);
		}
		else
		{
			plotRange = plotRange + (60.0 * MINUTES);
		}
		
		// adjust the axis ticks to something that looks nice
		
		if (plotRange < 40.0 * MINUTES)
		{
			timeAxis.majorIntervalLength = CPTDecimalFromDouble(5.0 * MINUTES);			
		}
		else if (plotRange < 80.0 * MINUTES)
		{
			timeAxis.majorIntervalLength = CPTDecimalFromDouble(10.0 * MINUTES);			
		}
		else if (plotRange < 120.0 * MINUTES)
		{
			timeAxis.majorIntervalLength = CPTDecimalFromDouble(15.0 * MINUTES);			
		}
		else if (plotRange < 240.0 * MINUTES)
		{
			timeAxis.majorIntervalLength = CPTDecimalFromDouble(30.0 * MINUTES);			
		}
		else if (plotRange < 480.0 * MINUTES)
		{
			timeAxis.majorIntervalLength = CPTDecimalFromDouble(60.0 * MINUTES);			
		}
		else if (plotRange < 960.0 * MINUTES)
		{
			timeAxis.majorIntervalLength = CPTDecimalFromDouble(120.0 * MINUTES);			
		}
		else
		{
			timeAxis.majorIntervalLength = CPTDecimalFromDouble(240.0 * MINUTES);			
		}
	}
	
	// Now make sure the plot ranges and axis crossing points are correct
	
	double initialRange = plotMaxTemp - plotMinTemp;
	double displacement = initialRange * BLOWER_PLOT_RESERVE;
	double adjustedStart = plotMinTemp - displacement;
	double adjustedRange = initialRange + displacement;
	
	tempGraphPlotSpace.xRange   = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(start) length:CPTDecimalFromDouble(plotRange)];
    tempGraphPlotSpace.yRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(adjustedStart) length: CPTDecimalFromDouble(adjustedRange)];

	blowerGraphPlotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(start) length:CPTDecimalFromDouble(plotRange)];

	NSArray *exclusionRanges  = [NSArray arrayWithObjects:
								 [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-50.0) length:CPTDecimalFromDouble(adjustedStart)],
								 nil];
	tempAxis.labelExclusionRanges = exclusionRanges;
	tempAxis.orthogonalCoordinateDecimal = CPTDecimalFromDouble(start);
	timeAxis.orthogonalCoordinateDecimal = CPTDecimalFromDouble(adjustedStart);

	// update the UI
	
	[graph reloadData];
}        


#pragma mark -
#pragma mark Plot Data Source Methods

// simple redirects to the data source methods in the stoker

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{	
	NSString *identifier = [NSString stringWithString: (NSString *) plot.identifier];
	NSRange target = [identifier rangeOfString: @" Target"];

	if (target.location == NSNotFound)
	{
		return [stoker numberOfRecordsForPlot: plot.identifier];
	}
	else
	{
		identifier = [identifier substringToIndex: target.location];
		return [stoker numberOfRecordsForPlot: identifier];
	}
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{	
	NSString *identifier = [NSString stringWithString: (NSString *) plot.identifier];
	NSRange target = [identifier rangeOfString: @" Target"];
	
	if (target.location == NSNotFound)
	{
		return [stoker plotValueForPlot: plot.identifier field: fieldEnum recordIndex: index];
	}
	else
	{
		identifier = [identifier substringToIndex: target.location];
		if (fieldEnum == 0)
			return [stoker plotValueForPlot: identifier field: 0 recordIndex: index];
		else
			return [stoker plotValueForPlot: identifier field: 2 recordIndex: index];
	}
}

#pragma mark -
#pragma mark Scatter Plot delegate methods

-(void)scatterPlot:(CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex:(NSUInteger)index
{   							   
    // Setup a style for the annotation
    CPTMutableTextStyle *hitAnnotationTextStyle = [CPTMutableTextStyle textStyle];
    hitAnnotationTextStyle.color = plot.dataLineStyle.lineColor;
    hitAnnotationTextStyle.fontSize = 16.0f;
    hitAnnotationTextStyle.fontName = @"Helvetica-Bold";
	
    // Determine point of symbol in plot coordinates
	NSNumber *time = [stoker plotValueForPlot: plot.identifier field: 0 recordIndex: index];
	NSNumber *temp = [stoker plotValueForPlot: plot.identifier field: 1 recordIndex: index];
    NSArray *anchorPoint = [NSArray arrayWithObjects:time, temp, nil];
	
    // Make a string for the temp value
    NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
    [formatter setMaximumFractionDigits: 1];
	[formatter setMinimumFractionDigits: 1];
    NSString *tempString = [formatter stringFromNumber:temp];
	
    // Now add the annotation to the plot area
    CPTPlotSpaceAnnotation *annotation = [[[CPTPlotSpaceAnnotation alloc] initWithPlotSpace:tempGraphPlotSpace anchorPlotPoint:anchorPoint] autorelease];
    annotation.contentLayer = [[[CPTTextLayer alloc] initWithText:tempString style:hitAnnotationTextStyle] autorelease];
    annotation.displacement = CGPointMake(0.0f, 20.0f);
    annotation.rotation = (45.0 * M_PI)/180.0;
    [graph.plotAreaFrame.plotArea addAnnotation: annotation];
	
	// Now set up a timer to make it go away after a few seconds
	
	 [NSTimer  scheduledTimerWithTimeInterval:(NSTimeInterval) 10.0
									   target: self 
									 selector: @selector(removeAnnotation:)
									 userInfo: annotation  
									  repeats: NO];
}

- (void) removeAnnotation: (NSTimer *) theTimer
{	
	CPTPlotSpaceAnnotation *annotation = [theTimer userInfo];

	[graph.plotAreaFrame.plotArea removeAnnotation: annotation];
}

#pragma mark -
#pragma mark Plot Space delegate methods

-(BOOL)plotSpace:(CPTPlotSpace *)space shouldHandlePointingDeviceDownEvent:(id)event atPoint:(CGPoint)point
{
	NSEvent *theEvent = (NSEvent *) event;
	NSDecimal plotPoint[2];
	
	if (theEvent.type == NSLeftMouseDown)		// check for hitting an existing annotation
	{
		if (!self.annotationList)
			return NO;
		
		// set up the anchor point for the annotation
		
		CGPoint plotAreaPoint = [graph convertPoint:point toLayer:graph.plotAreaFrame.plotArea];
		[tempGraphPlotSpace plotPoint: plotPoint forPlotAreaViewPoint:plotAreaPoint];
		NSArray *anchorPoint = [NSArray arrayWithObjects: [NSDecimalNumber decimalNumberWithDecimal: plotPoint[0]], [NSDecimalNumber decimalNumberWithDecimal: plotPoint[1]], nil];

		for (CPTPlotSpaceAnnotation *annotation in annotationList)
		{
			NSArray *plotPoint = [annotation anchorPlotPoint];
			
			double xdiff = fabs([[anchorPoint objectAtIndex: 0] doubleValue] - [[plotPoint objectAtIndex: 0] doubleValue]);
			double ydiff = fabs([[anchorPoint objectAtIndex: 1] doubleValue] - [[plotPoint objectAtIndex: 1] doubleValue]);
			
			if ((xdiff < 5.0) && (ydiff < 5.0))
			{
				NSLog(@"StokerPlotController - plotPoint diffs = %f,%f, annotation = %@", xdiff, ydiff, [(CPTTextLayer *)[annotation contentLayer] text]);
				[appDelegate  plotController: self selectedNoteWithString: [(CPTTextLayer *)[annotation contentLayer] text]];
		
			}
		}
	}
	else if ((theEvent.type == NSRightMouseDown) || (theEvent.modifierFlags & NSControlKeyMask))
	{
		// make sure we have an annotation list
		
		if (!self.annotationList)
			annotationList = [[NSMutableArray alloc] initWithCapacity: 20];
			
		// set up the anchor point for the annotation
		
		CGPoint plotAreaPoint = [graph convertPoint:point toLayer:graph.plotAreaFrame.plotArea];
		[tempGraphPlotSpace plotPoint: plotPoint forPlotAreaViewPoint:plotAreaPoint];
		NSArray *anchorPoint = [NSArray arrayWithObjects: [NSDecimalNumber decimalNumberWithDecimal: plotPoint[0]], [NSDecimalNumber decimalNumberWithDecimal: plotPoint[1]], nil];

		// Setup a style for the annotation
		CPTMutableTextStyle *hitAnnotationTextStyle = [CPTMutableTextStyle textStyle];
		hitAnnotationTextStyle.color = [CPTColor whiteColor];
		hitAnnotationTextStyle.fontSize = 14.0f;
		hitAnnotationTextStyle.fontName = @"Helvetica-Bold";
		
		// create the annotation
		
		CPTPlotSpaceAnnotation *annotation = [[[CPTPlotSpaceAnnotation alloc] initWithPlotSpace:tempGraphPlotSpace anchorPlotPoint:anchorPoint] autorelease];
		[annotationList addObject: annotation];
		annotation.contentLayer = [[[CPTTextLayer alloc] initWithText: [NSString stringWithFormat: @"(%ld)", (long) [annotationList count]]
																style: hitAnnotationTextStyle] autorelease];

		// Now add the annotation to the plot area
		[graph.plotAreaFrame.plotArea addAnnotation: annotation];
		
		// and bring up the notes window
		[appDelegate plotController: self addedNoteNumber: [annotationList count]];

		return YES;
	}

	return NO;
}


/*

-(CGPoint)plotSpace:(CPTPlotSpace *)space willDisplaceBy:(CGPoint)proposedDisplacementVector
{
	NSLog(@"StokerPlotController - plotSpace: %@ willDisplaceBy: %f,%f",
		  space.identifier, (double) proposedDisplacementVector.x, (double) proposedDisplacementVector.y);
	
	CGPoint newVector;
	newVector.x = proposedDisplacementVector.x;
	newVector.y = 0.0;
	return newVector;
}

-(CPTPlotRange *)plotSpace:(CPTPlotSpace *)space willChangePlotRangeTo:(CPTPlotRange *)newRange forCoordinate:(CPTCoordinate)coordinate
{
	NSLog(@"StokerPlotController - plotSpace: %@ willChangePlotRangeTo: %@ forCoordinate: %d",
		  space.identifier, [newRange description], (int) coordinate);
	
	return newRange;
}


-(void)plotSpace:(CPTPlotSpace *)space didChangePlotRangeForCoordinate:(CPTCoordinate)coordinate
{
	NSLog(@"StokerPlotController - plotSpace: %@ didChangePlotRangeForCoordinate: %d", space.identifier, (int) coordinate);
}
*/

#pragma mark -
#pragma mark Axis delegate methods
/*
-(BOOL)axisShouldRelabel:(CPTAxis *)axis
{
	NSLog(@"StokerPlotController - axisShouldRelabel: %@", axis.title);
	
	return  YES;
}

-(void)axisDidRelabel:(CPTAxis *)axis
{
	NSLog(@"StokerPlotController - axisDidRelabel: %@", axis.title);
}

-(BOOL)axis:(CPTAxis *)axis shouldUpdateAxisLabelsAtLocations:(NSSet *)locations
{
	NSLog(@"StokerPlotController - axis: %@ shouldUpdateAxisLabelsAtLocations: %@", axis.title, locations);

	return YES;
}
*/

#pragma mark -
#pragma mark PDF / image export

-(IBAction)exportToPDF:(id)sender
{
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"yyyy-MM-dd"];
	NSString *formattedDateString = [dateFormatter stringFromDate: [NSDate date]];
		
	NSSavePanel *pdfSavingDialog = [NSSavePanel savePanel];
	[pdfSavingDialog setAllowedFileTypes: [NSArray arrayWithObject:@"pdf"]];
	[pdfSavingDialog setNameFieldStringValue: [NSString stringWithFormat: @"StokerX %@", formattedDateString]];
	
	[pdfSavingDialog beginWithCompletionHandler:^(NSInteger result)
	 {
		 if (result==NSFileHandlingPanelOKButton)
		 {
			 NSData *dataForPDF = [graph dataForPDFRepresentationOfLayer];
			 [dataForPDF writeToURL: pdfSavingDialog.URL atomically:NO];
		 }		 
	 }];
}

@end
