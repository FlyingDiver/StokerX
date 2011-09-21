//
//  StokerSensor.m
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerSensor.h"

@implementation StokerSensor

@synthesize sensorName;
@synthesize deviceID;
@synthesize tempCurrent;
@synthesize tempTarget;
@synthesize blowerID;
@synthesize control;
@synthesize blower;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}
- (NSString *) description
{
	return [NSString stringWithFormat: @"StokerSensor: name = %@, id = %@, tc = %@, ta = %@, blower = %@", sensorName, deviceID, tempCurrent, tempTarget, blowerID];
}
@end
