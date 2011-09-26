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

@synthesize sensorID, value, lastNotified, enabled, test, action;

+ (NSMutableArray *) ruleList
{
	NSData *data;
	NSKeyedUnarchiver *unarchiver;
	id	restoreObject;
	
	if (_RuleList) 
	{
		return _RuleList;
	}
		
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: [[NSProcessInfo processInfo] processName]];
	NSString *saveFilePath = [supportDir stringByAppendingPathComponent: kSavedNotificationsFile];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath: saveFilePath] == YES)
	{						
		data = [NSData dataWithContentsOfFile: saveFilePath];
		unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData: data];
		restoreObject = [unarchiver decodeObjectForKey:@"NotificationRuleList"];
		[unarchiver finishDecoding];
		[unarchiver release];
		
		if ([restoreObject isKindOfClass: [NSArray class]])
		{
			NSLog(@"NotificationRule Restoring Array object");
			_RuleList = restoreObject;
			
			if ([_RuleList count] > 0)
			{
				// make sure we don't crash because rules were removed.
				
				for (NotificationRule *rule in _RuleList)
				{
					if (rule.test >= [[NotificationTest testList] count])
						rule.test = 0;
					
					if (rule.action >= [[NotificationAction actionList] count])
						rule.action = 0;
				}
				
				return _RuleList;
			}
			else
				[_RuleList release];
		}
		else if ([restoreObject isKindOfClass: [NSDictionary class]])
		{			
			// Might need to do fixups here if the version has changed
			
			if ([@"1.0" isEqualTo: [restoreObject objectForKey: @"version"]])
			{
				NSLog(@"NotificationRule Restoring Dictionary object, version = %@", [restoreObject objectForKey: @"version"]);

				_RuleList = [restoreObject objectForKey: @"rules"];
				return  _RuleList;
			}
			else
				NSLog(@"NotificationRule unknown saved rules version");
		}
	}
	
	NSLog(@"NotificationRule creating new rules array");
	_RuleList = [[NSMutableArray alloc] initWithCapacity: 10];

	return _RuleList;
}

+ (void) saveRules: (NSMutableArray *) theRules
{		
	NSMutableData *data;
	NSKeyedArchiver *archiver;
	BOOL result;
	
	NSString *versionString = @"1.0";	// version of rules graph
	
	NSDictionary *saveDict = [NSDictionary dictionaryWithObjectsAndKeys: versionString, @"version", theRules, @"rules", nil];
	
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
	[archiver encodeObject: saveDict forKey:@"NotificationRuleList"];
	[archiver finishEncoding];
	result = [data writeToFile: saveFilePath atomically:YES];
	[archiver release];

	if (!result)
		NSLog(@"NotificationRule saveRules: failed");
}

- (id)init
{
    self = [super init];
    if (self) 
	{
        // Initialization code here.
    }
    
    return self;
}
- (void)dealloc 
{
    [sensorID release];
	[value release];
	[lastNotified release];
	
    [super dealloc];
}

- (NSString *) description
{
	NSString *enabledString = self.enabled ? @"Yes" : @"No";
	NSString *testString = [[[NotificationTest testList] objectAtIndex: self.test] name];
	NSString *actionString = [[[NotificationAction actionList] objectAtIndex: self.action] name];
					  
					  
	return [NSString stringWithFormat: @"NotificationRule ID = %@, Enabled %@, Value = %@, Test = '%@', Action = '%@'",
			self.sensorID, enabledString, self.value, testString, actionString];
}

- (void)encodeWithCoder:(NSCoder *)coder 
{
    [coder encodeObject: sensorID   forKey: @"NRSensorID"];
    [coder encodeObject: value      forKey: @"NRValue"];
    [coder encodeBool: enabled      forKey: @"NREnabled"];
    [coder encodeInteger: test      forKey: @"NRTest"];
    [coder encodeInteger: action    forKey: @"NRAction"];
}

- (id)initWithCoder:(NSCoder *)coder 
{
	self = [super init];

    sensorID	= [[coder decodeObjectForKey: @"NRSensorID"] retain];
    value		= [[coder decodeObjectForKey: @"NRValue"] retain];
    enabled		= [coder decodeBoolForKey:    @"NREnabled"];
    test		= [coder decodeIntegerForKey: @"NRTest"];
    action		= [coder decodeIntegerForKey: @"NRAction"];

    return self;
}

@end
