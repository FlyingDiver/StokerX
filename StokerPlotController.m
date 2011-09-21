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

@implementation StokerPlotController

@synthesize graph, startTime,plotMaxTemp, plotMinTemp, stoker, stokerData;

-(void)awakeFromNib
{	    
	NSDateFormatter *dateFormatter;
	
	// initial graphing bounds
	
	plotRange = TIME_RANGE_START;
	startTime  = [[NSDate date] timeIntervalSinceReferenceDate];
		
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
	
    // Setup scatter plot space 

	double initialRange = plotMaxTemp - plotMinTemp;
	double displacement = initialRange * BLOWER_PLOT_RESERVE;
	double adjustedStart = plotMinTemp - displacement;
	double adjustedRange = initialRange + displacement;
	
    tempGraphPlotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
	tempGraphPlotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(startTime) length:CPTDecimalFromDouble(plotRange)];
    tempGraphPlotSpace.yRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(adjustedStart) length: CPTDecimalFromDouble(adjustedRange)];
  	tempGraphPlotSpace.identifier = @"Sensor Plot Space";
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
	
    tempAxis.majorIntervalLength = CPTDecimalFromDouble(50.0);;
	tempAxis.minorTicksPerInterval = 0;
	tempAxis.majorGridLineStyle = gridLineStyle;
	tempAxis.axisLineStyle = tickLineStyle;
	tempAxis.majorTickLength = 0.0f;
	tempAxis.labelOffset = 3.0f;
	tempAxis.orthogonalCoordinateDecimal = CPTDecimalFromDouble(startTime);
	
	NSArray *exclusionRanges  = [NSArray arrayWithObjects:
								 [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0) length:CPTDecimalFromDouble(adjustedStart)],
								 nil];
	tempAxis.labelExclusionRanges = exclusionRanges;
	
	// Add plotSpace for the blower data
    blowerGraphPlotSpace = [[CPTXYPlotSpace alloc] init];
	blowerGraphPlotSpace.identifier = @"Blower Plot Space";
	blowerGraphPlotSpace.xRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(startTime) length: CPTDecimalFromDouble(plotRange)];
    blowerGraphPlotSpace.yRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromInt(0) length: CPTDecimalFromInt(20)];
	[graph addPlotSpace: blowerGraphPlotSpace];
	 
 }	

// Configure the plots and data structures based on the sensors and blowers found

- (void) plotSetup
{
	NSLog(@"StokerPlotController plotSetup");

    // set up the plots based on the Stoker info
	
    CPTScatterPlot *linePlot;
    CPTMutableLineStyle *lineStyle;
    int sensorCount = 0;
    NSArray *sensorColors =  [NSArray arrayWithObjects: [NSColor redColor], [NSColor blueColor], [NSColor greenColor], [NSColor cyanColor], nil];
    NSColor *plotColor = nil;
		
    for (int i = 0; i < [stoker numberOfBlowers]; i++)
    {        
		// First, create an entry in the stokerData dictionary for this blower
		
		[stokerData setObject:	[NSMutableDictionary dictionaryWithObjectsAndKeys: 
								 [stoker nameForBlower: i], @"name", 
								 [NSNumber numberWithInt: 0],  @"count",
								 [NSMutableArray arrayWithCapacity: 1000], @"plotData", 
								 nil]
					   forKey: [stoker idForBlower: i]];
		
        linePlot = [[[CPTScatterPlot alloc] init] autorelease];
        linePlot.identifier = [stoker idForBlower: i];
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
		// First, create an entry in the stokerData dictionary for this sensor
		
		[stokerData setObject:	[NSMutableDictionary dictionaryWithObjectsAndKeys: 
								 [stoker nameForSensor: i], @"name", 
								 [stoker typeForSensor: i], @"type", 
								 [stoker tempForSensor: i], @"temp",
								 [NSMutableArray arrayWithCapacity: 1000], @"plotData", 
								 nil]
					   forKey: [stoker idForSensor: i]];
		
		[stokerData setObject:	[NSMutableDictionary dictionaryWithObjectsAndKeys: 
								 [stoker nameForSensor: i], @"name", 
								 [stoker targetForSensor: i], @"target",
								 [NSMutableArray arrayWithCapacity: 1000], @"plotData", 
								 nil]
					   forKey: [NSString stringWithFormat: @"%@ Target", [stoker idForSensor: i]]];
		
        plotColor = [[NSUserDefaults standardUserDefaults]  colorForKey: [NSString stringWithFormat: @"PlotColor %@", [stoker idForSensor: i]]];
        if (!plotColor)
        {
            plotColor = [sensorColors objectAtIndex: sensorCount];
            sensorCount++;
            [[NSUserDefaults standardUserDefaults] setColor: plotColor forKey: [NSString stringWithFormat: @"PlotColor %@", [stoker idForSensor: i]]];
        }
        
        // Create a plot for the sensor data
        linePlot = [[[CPTScatterPlot alloc] init] autorelease];
        linePlot.identifier = [stoker idForSensor: i];
        linePlot.dataSource = self;			
		linePlot.delegate = self;								// only add delegate and HitDetection for plots we want the user to be able to click on
		linePlot.plotSymbolMarginForHitDetection = 5.0f;
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 1.5f;
        lineStyle.lineColor = [CPTColor colorWithCGColor: CPTNewCGColorFromNSColor(plotColor)];
        linePlot.dataLineStyle = lineStyle;
        
		[graph addPlot:linePlot toPlotSpace:tempGraphPlotSpace];
        
        // Create a plot for the sensor target
        linePlot = [[[CPTScatterPlot alloc] init] autorelease];
        linePlot.identifier = [NSString stringWithFormat:@"%@ Target", [stoker idForSensor: i]];
        linePlot.dataSource = self;
        linePlot.interpolation = CPTScatterPlotInterpolationStepped;
        
        lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 2.0f;
        lineStyle.lineColor = [CPTColor colorWithCGColor: CPTNewCGColorFromNSColor(plotColor)];
        lineStyle.dashPattern = [NSArray arrayWithObjects:[NSNumber numberWithFloat:5.0f], [NSNumber numberWithFloat:5.0f], nil];
        linePlot.dataLineStyle = lineStyle;
		
		[graph addPlot:linePlot toPlotSpace:tempGraphPlotSpace];
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

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{	
//	NSLog(@"StokerPlotController numberOfRecordsForPlot: %@ = %ld", plot.identifier, [[[stokerData objectForKey: plot.identifier] objectForKey: @"plotData"] count]);

	return [[[stokerData objectForKey: plot.identifier] objectForKey: @"plotData"] count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{	
//	NSLog(@"StokerPlotController numberForPlot: %@ field: %ld recordIndex: %ld = %@", 
//		  plot.identifier, fieldEnum, index, [[[[stokerData objectForKey: plot.identifier] objectForKey: @"plotData"] objectAtIndex: index] objectAtIndex: fieldEnum]);

    return [[[[stokerData objectForKey: plot.identifier] objectForKey: @"plotData"] objectAtIndex: index] objectAtIndex: fieldEnum];
}

#pragma mark -
#pragma mark Plot delegate method

-(void)scatterPlot:(CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex:(NSUInteger)index
{   							   
    // Setup a style for the annotation
    CPTMutableTextStyle *hitAnnotationTextStyle = [CPTMutableTextStyle textStyle];
    hitAnnotationTextStyle.color = plot.dataLineStyle.lineColor;
    hitAnnotationTextStyle.fontSize = 16.0f;
    hitAnnotationTextStyle.fontName = @"Helvetica-Bold";
	
    // Determine point of symbol in plot coordinates
    NSArray *plotData = [[stokerData objectForKey: plot.identifier] objectForKey: @"plotData"];
    NSNumber *time = [[plotData objectAtIndex:index] objectAtIndex: 0];
    NSNumber *temp = [[plotData objectAtIndex:index] objectAtIndex: 1];
    NSArray *anchorPoint = [NSArray arrayWithObjects:time, temp, nil];
	
    // Make a string for the temp value
    NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
    [formatter setMaximumFractionDigits: 1];
	[formatter setMinimumFractionDigits: 1];
    NSString *tempString = [formatter stringFromNumber:temp];
	
    // Now add the annotation to the plot area
    CPTTextLayer *textLayer = [[[CPTTextLayer alloc] initWithText:tempString style:hitAnnotationTextStyle] autorelease];
    CPTPlotSpaceAnnotation *annotation = [[[CPTPlotSpaceAnnotation alloc] initWithPlotSpace:tempGraphPlotSpace anchorPlotPoint:anchorPoint] autorelease];
    annotation.contentLayer = textLayer;
    annotation.displacement = CGPointMake(0.0f, 20.0f);
    [graph.plotAreaFrame.plotArea addAnnotation: annotation];   
	
	// Now set up a timer to make it go away after a few seconds
	
	 [NSTimer  scheduledTimerWithTimeInterval:(NSTimeInterval) 5.0  
									   target: self 
									 selector: @selector(removeAnnotation:)
									 userInfo: annotation  
									  repeats: NO];
}

- (void) removeAnnotation: (NSTimer *) theTimer
{	
	CPTPlotSpaceAnnotation *annotation = [theTimer userInfo];

	[graph.plotAreaFrame.plotArea removeAnnotation: annotation];
//	[annotation release];
//	annotation = nil;
}

@end
