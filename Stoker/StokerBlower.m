//
//  StokerBlower.m
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerBlower.h"

@implementation StokerBlower

@synthesize blowerName;
@synthesize deviceID;
@synthesize state;
@synthesize sensor;

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
	return [NSString stringWithFormat: @"StokerBlower: name = %@, id = %@, state = %d", blowerName, deviceID, state];
}
@end
