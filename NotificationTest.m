//
//  NotificationTest.m
//  StokerX
//
//  Created by Joe Keenan on 8/22/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "NotificationTest.h"

static NSArray *_TestList = nil;

@implementation NotificationTest

@synthesize name, test;

+ (NSArray *) testList 
{
    if (!_TestList) 
	{
		_TestList = [[NSArray alloc] initWithObjects: 
						[[[NotificationTest alloc] initWithName: @"Sensor Under Temp"	andTest: kSensorUnderTemp] autorelease], 
						[[[NotificationTest alloc] initWithName: @"Sensor Over Temp"	andTest: kSensorOverTemp] autorelease],
						[[[NotificationTest alloc] initWithName: @"Sensor at Target"	andTest: kSensorTargetTemp] autorelease],
						[[[NotificationTest alloc] initWithName: @"Periodic Report"		andTest: kPeriodic] autorelease],
						[[[NotificationTest alloc] initWithName: @"StokerX Error"		andTest: kAppError] autorelease],
					   nil];
		
	}
    
	return _TestList;
}

- (id) initWithName: (NSString *) theName andTest: (TestTypes) theTest
{
	self = [super init];
	if (self)
	{
		self.name = theName;
		self.test = theTest;
	}
	return self;
}

- (NSString *) description
{
	NSString *testString = [[[NotificationTest testList] objectAtIndex: self.test] name];	
	
	return [NSString stringWithFormat: @"NotificationTest Name = '%@', Test = '%@'", self.name, testString];
}

@end
