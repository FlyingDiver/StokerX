//
//  StokerBlower.m
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerBlower.h"
#import "StokerSensor.h"

@implementation StokerBlower

@synthesize state, sensor, onCount;


- (NSString *) description
{
	return [NSString stringWithFormat: @"StokerBlower: name = %@, id = %@, state = %ld, on count = %ld, plot count = %ld", 
			self.deviceName, self.deviceID, (unsigned long)self.state, (long) self.onCount, (long) [self.plotData count]];
}

@end
