//
//  NotificationAction.m
//  StokerX
//
//  Created by Joe Keenan on 8/22/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "NotificationAction.h"

static NSArray *_ActionList = nil;

@implementation NotificationAction

@synthesize name, action;

+ (NSArray *) actionList 
{
    if (!_ActionList) 
	{
		_ActionList = [[NSArray alloc] initWithObjects: 
							[[[NotificationAction alloc] initWithName: @"Audible Alarm"			andAction: kAudibleAlarm] autorelease], 
							[[[NotificationAction alloc] initWithName: @"Growl Alert"			andAction: kVisualAlarm] autorelease],
							[[[NotificationAction alloc] initWithName: @"Email Notification"	andAction: kEmailNotification] autorelease],
							[[[NotificationAction alloc] initWithName: @"Twitter Notification"	andAction: kTwitterNotification] autorelease],
					   nil];

	}
    
	return _ActionList;
}


- (id) initWithName: (NSString *) theName andAction: (ActionTypes) theAction
{
	self = [super init];
	if (self)
	{
		self.name = theName;
		self.action = theAction;
	}
	return self;
}

- (NSString *) description
{
	NSString *actionString = [[[NotificationAction actionList] objectAtIndex: self.action] name];	
	
	return [NSString stringWithFormat: @"NotificationAction Name = '%@', Action = '%@'", self.name, actionString];
}

@end