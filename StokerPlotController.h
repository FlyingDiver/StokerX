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

@interface StokerPlotController : NSObject <CPTPlotSpaceDelegate, CPTPlotDataSource, CPTAxisDelegate>
{
    IBOutlet CPTGraphHostingView	*graphView;
	
	CPTXYPlotSpace					*tempGraphPlotSpace; 
	CPTXYPlotSpace					*blowerGraphPlotSpace; 
	
	NSTimeInterval					plotRange;
}

@property (nonatomic, retain) CPTXYGraph			*graph;
@property (nonatomic, assign) NSTimeInterval		startTime;
@property (nonatomic, assign) double				plotMinTemp;
@property (nonatomic, assign) double				plotMaxTemp;
@property (nonatomic, retain) Stoker				*stoker;

- (void) setupGraph;
- (void) setupPlots;
- (void) updateGraphWithStartTime: (NSTimeInterval) start andElapsedTime: (NSTimeInterval) elapsed;

// PDF / image export
-(IBAction) exportToPDF:(id)sender;
-(IBAction) exportToPNG:(id)sender;

@end
