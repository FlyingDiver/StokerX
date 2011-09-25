//
//  NotificationRule.h
//  StokerX
//
//  Created by Joe Keenan on 8/22/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NotificationAction.h"
#import "NotificationTest.h"

#define kSavedNotificationsFile	@"Notifications.plist"

@interface NotificationRule : NSObject
{
}

+ (NSMutableArray *)	ruleList;
+ (void)				saveRules: (NSMutableArray *) ruleList;

@property (nonatomic, copy) 	NSString		*sensorID;
@property (nonatomic, retain) 	NSNumber		*value;
@property (nonatomic, retain)	NSNumber		*lastNotified;
@property (assign)				Boolean			enabled;
@property (assign)				TestTypes		test;
@property (assign)				ActionTypes		action;
@end
