//
//  StokerDevice.m
//  StokerX
//
//  Created by Joe Keenan on 9/24/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerDevice.h"

@implementation StokerDevice

@synthesize deviceID, deviceName, plotData;

- (id)init
{
    self = [super init];
    if (self) 
	{
		plotData = [[NSMutableArray alloc] initWithCapacity: 100];
	}
    
    return self;
}

- (id)initWithName: (NSString *) devName andID: (NSString *) devID
{
    self = [super init];
    if (self) 
	{
		plotData = [[NSMutableArray alloc] initWithCapacity: 100];
		self.deviceName = devName;
		self.deviceID = devID;
	}
    
    return self;
}

- (void)dealloc 
{
	self.deviceName = nil;
	self.deviceID = nil;
	
    [plotData release];
	
    [super dealloc];
}


@end
