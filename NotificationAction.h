//
//  NotificationAction.h
//  StokerX
//
//  Created by Joe Keenan on 8/22/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	kAudibleAlarm = 0,
	kGrowlAlert,
	kEmailNotification,
	kTwitterNotification
} ActionTypes;

@interface NotificationAction : NSObject
{
}

+ (NSArray *) actionList;

- (id) initWithName: (NSString *) theName andAction: (ActionTypes) theAction;

@property (nonatomic,retain) 	NSString	*name;
@property (assign)				ActionTypes	action;

@end
