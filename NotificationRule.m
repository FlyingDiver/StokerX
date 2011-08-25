//
//  NotificationRule.m
//  StokerX
//
//  Created by Joe Keenan on 8/22/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "NotificationRule.h"

static NSMutableArray *_RuleList = nil;

@implementation NotificationRule

@synthesize sensorName, sensorID, value, lastNotified, enabled, test, action;

+ (NSMutableArray *) ruleList
{
	NSData *data;
	NSKeyedUnarchiver *unarchiver;

	if (_RuleList) 
	{
		return _RuleList;
	}
		
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: @"StokerX"];
	
	NSString *saveFilePath = [supportDir stringByAppendingPathComponent: kSavedNotificationsFile];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath: saveFilePath] == YES)
	{						
		data = [NSData dataWithContentsOfFile: saveFilePath];
		unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData: data];
		_RuleList = [unarchiver decodeObjectForKey:@"NotificationRuleList"];
		[unarchiver finishDecoding];
		[unarchiver release];
	}
/*	else
	{
		NSLog(@"[NotificationRule ruleList] Creating ruleList from scratch");

		_RuleList = [[NSMutableArray alloc] initWithCapacity: 10];	// empty array
		NotificationRule *newRule;
		
		newRule = [[NotificationRule alloc] init];
		newRule.sensorName =  @"Pit Sensor";
		newRule.sensorID =  @"CA0000125914D130";
		newRule.enabled = TRUE;
		newRule.test = kSensorOverTemp;
		newRule.action = kAudibleAlarm;
		newRule.value = [NSNumber numberWithDouble: 250.0];
		[_RuleList addObject: newRule];
		[newRule release];
		
		newRule = [[NotificationRule alloc] init];
		newRule.sensorName =  @"Pit Sensor";
		newRule.sensorID =  @"CA0000125914D130";
		newRule.enabled = TRUE;
		newRule.test = kSensorUnderTemp;
		newRule.action = kVisualAlarm;
		newRule.value = [NSNumber numberWithDouble: 200.0];
		[_RuleList addObject: newRule];
		[newRule release];
		
		newRule = [[NotificationRule alloc] init];
		newRule.sensorName =  @"Food A";
		newRule.sensorID =  @"FF0000125914C330";
		newRule.enabled = TRUE;
		newRule.test = kSensorTargetTemp;
		newRule.action = kEmailNotification;
		newRule.value = [NSNumber numberWithDouble: 190.0];
		[_RuleList addObject: newRule];
		[newRule release];
		
		newRule = [[NotificationRule alloc] init];
		newRule.sensorName =  @"Food A";
		newRule.sensorID =  @"FF0000125914C330";
		newRule.enabled = TRUE;
		newRule.test = kPeriodic;
		newRule.action = kEmailNotification;
		newRule.value = [NSNumber numberWithDouble: 600.0];
		[_RuleList addObject: newRule];
		[newRule release];
		
		newRule = [[NotificationRule alloc] init];
		newRule.sensorName =  @"Food A";
		newRule.sensorID =  @"FF0000125914C330";
		newRule.enabled = TRUE;
		newRule.test = kPeriodic;
		newRule.action = kTwitterNotification;
		newRule.value = [NSNumber numberWithDouble: 600.0];
		[_RuleList addObject: newRule];
		[newRule release];
		
		[self saveRules: _RuleList];
	}
 */
	return _RuleList;
}

+ (void) saveRules: (NSMutableArray *) ruleList
{		
	NSMutableData *data;
	NSKeyedArchiver *archiver;
	BOOL result;
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: @"StokerX"];
	
	NSString *saveFilePath = [supportDir stringByAppendingPathComponent: kSavedNotificationsFile];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath: saveFilePath] == NO)
	{
		[fileManager createDirectoryAtPath: supportDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
	data = [NSMutableData data];
	archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData: data];
	[archiver encodeObject: ruleList forKey:@"NotificationRuleList"];
	[archiver finishEncoding];
	result = [data writeToFile: saveFilePath atomically:YES];
	[archiver release];

	if (!result)
		NSLog(@"NotificationRule saveRules: failed");
}

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
	NSString *enabledString = self.enabled ? @"Yes" : @"No";
	NSString *testString = [[[NotificationTest testList] objectAtIndex: self.test] name];
	NSString *actionString = [[[NotificationAction actionList] objectAtIndex: self.action] name];
					  
					  
	return [NSString stringWithFormat: @"NotificationRule Name = '%@', ID = %@, Enabled %@, Value = %@, Test = '%@', Action = '%@'",
			self.sensorName, self.sensorID, enabledString, self.value, testString, actionString];
}

- (void)encodeWithCoder:(NSCoder *)coder 
{
    [coder encodeObject: sensorName forKey: @"NRSensorName"];
    [coder encodeObject: sensorID   forKey: @"NRSensorID"];
    [coder encodeObject: value      forKey: @"NRValue"];
    [coder encodeBool: enabled      forKey: @"NREnabled"];
    [coder encodeInteger: test      forKey: @"NRTest"];
    [coder encodeInteger: action    forKey: @"NRAction"];
}

- (id)initWithCoder:(NSCoder *)coder 
{
	self = [super init];

    sensorName	= [[coder decodeObjectForKey: @"NRSensorName"] retain];
    sensorID	= [[coder decodeObjectForKey: @"NRSensorID"] retain];
    value		= [[coder decodeObjectForKey: @"NRValue"] retain];
    enabled		= [coder decodeBoolForKey:    @"NREnabled"];
    test		= [coder decodeIntegerForKey: @"NRTest"];
    action		= [coder decodeIntegerForKey: @"NRAction"];

    return self;
}

@end
