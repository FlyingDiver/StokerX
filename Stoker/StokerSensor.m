//
//  StokerSensor.m
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerSensor.h"
#import "StokerBlower.h"

@implementation StokerSensor

@synthesize tempCurrent, tempTarget, control, blower;

- (NSString *) description
{
	return [NSString stringWithFormat: @"StokerSensor: name = %@, id = %@, tc = %@, ta = %@, blower = %@, temp plot count = %ld", 
			self.deviceName, self.deviceID, self.tempCurrent, self.tempTarget, self.blower.deviceID, (unsigned long)[self.plotData count]];
}

@end
