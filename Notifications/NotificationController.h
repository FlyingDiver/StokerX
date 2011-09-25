//
//  NotificationController.h
//  StokerX
//
//  Created by Joe Keenan on 8/16/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Growl/Growl.h"
#import "MiniTwitter.h"
#import "NotificationAction.h"
#import "NotificationRule.h"
#import "NotificationTest.h"

@interface NotificationController : NSWindowController  <NSTableViewDataSource, GrowlApplicationBridgeDelegate>
{
	IBOutlet NSTableView	*ruleTable;
	IBOutlet NSWindow		*ruleEditPanel;
	
	IBOutlet NSPopUpButton	*sensorPopup;
	IBOutlet NSPopUpButton	*testPopup;
	IBOutlet NSPopUpButton	*actionPopup;
	IBOutlet NSTextField	*valueTextField;
}

- (IBAction) editRuleList: (NSSegmentedControl *) sender;
- (IBAction) changeRuleTest:(id)sender;
- (IBAction) changeRuleValue:(id)sender;
- (IBAction) changeRuleAction:(id)sender;

- (void) addSensor: (NSString *) sensorID name: (NSString *) sensorName;
- (void) checkSensor: (NSString *) sensorID andTemp: (NSNumber *) sensorTemp;

- (void) doNotification: (NotificationRule *) criteria withMessage: (NSString *) message;

- (NSString *) notificationsTextForSensor: (NSString *) sensorID;

@property (nonatomic, retain) NSMutableArray		*ruleList;	
@property (nonatomic, retain) NSMutableArray		*sensorList;	
@property (nonatomic, retain) NSMutableDictionary	*sensorDict;
@property (nonatomic, retain) MiniTwitter			*tweetController;

@end
