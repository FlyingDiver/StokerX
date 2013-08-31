//
//  StokerPlotController.h
//  StokerX
//
//  Created by Joe Keenan on 9/10/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CorePlot/CorePlot.h"
#import "Stoker.h"
#import "nsColorSupport.h"

@interface CPTGraphHostingView(rightMouseSupport)
- (void)rightMouseDown:(NSEvent *)theEvent;
- (void)rightMouseDragged:(NSEvent *)theEvent;
- (void)rightMouseUp:(NSEvent *)theEvent;
@end

@class StokerXAppDelegate;

@interface StokerPlotController : NSObject <CPTPlotSpaceDelegate, CPTPlotDataSource, CPTScatterPlotDataSource, CPTAxisDelegate>
{
    IBOutlet CPTGraphHostingView	*graphView;

	IBOutlet StokerXAppDelegate		*appDelegate;
	
	CPTXYPlotSpace		*tempGraphPlotSpace; 
	CPTXYPlotSpace		*blowerGraphPlotSpace; 
	CPTXYGraph			*graph;
	
	NSMutableArray		*annotationList;
	NSTimeInterval		plotRange;
	NSTimeInterval		startTime;
	double				plotMinTemp;
	double				plotMaxTemp;
	Stoker				*stoker;
}

@property (nonatomic, retain) CPTGraphHostingView	*graphView;
@property (nonatomic, retain) CPTXYGraph			*graph;
@property (nonatomic, retain) NSMutableArray		*annotationList;
@property (nonatomic, assign) NSTimeInterval		startTime;
@property (nonatomic, assign) double				plotMinTemp;
@property (nonatomic, assign) double				plotMaxTemp;
@property (nonatomic, retain) Stoker				*stoker;

- (void) setupGraph;
- (void) setupPlots;
- (void) updateGraphWithStartTime: (NSTimeInterval) start andElapsedTime: (NSTimeInterval) elapsed;

// PDF / image export
-(IBAction) exportToPDF:(id)sender;

@end

// Handle mouse down events on the plot

@protocol StokerPlotControllerDelegate <NSObject>

- (void) plotController: (StokerPlotController *) plotController addedNoteNumber: (NSInteger) noteNumber;
- (void) plotController: (StokerPlotController *) plotController selectedNoteWithString: (NSString *) string;

@end
