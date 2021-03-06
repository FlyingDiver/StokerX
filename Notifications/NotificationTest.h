//
//  NotificationTest.h
//  StokerX
//
//  Created by Joe Keenan on 8/22/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	kSensorUnderTemp = 0,
	kSensorOverTemp,
	kSensorTargetTemp,
	kPeriodic,
} TestTypes;

@interface NotificationTest : NSObject
{
	NSString	*name;
	TestTypes	test;
}

+ (NSArray *) testList;

- (id) initWithName: (NSString *) theName andTest: (TestTypes) theTest;

@property (nonatomic,copy) 	NSString	*name;
@property (assign)			TestTypes	test;
@end
