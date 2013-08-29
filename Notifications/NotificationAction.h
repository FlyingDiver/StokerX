//
//  NotificationAction.h
//  StokerX
//
//  Created by Joe Keenan on 8/22/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	kGrowlAlert = 0,
	kEmailNotification,
	kTwitterNotification,
	kProwlNotification
} ActionTypes;

@interface NotificationAction : NSObject
{
	NSString	*name;
	ActionTypes	action;
}

+ (NSArray *) actionList;

- (id) initWithName: (NSString *) theName andAction: (ActionTypes) theAction;

@property (nonatomic,copy) 	NSString	*name;
@property (assign)			ActionTypes	action;

@end
