//
//  NotificationController.m
//  StokerX
//
//  Created by Joe Keenan on 8/16/11.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//
// Manages the Notifications window

#import "NotificationController.h"
#import "PreferencesController.h"
#import "EmailSender.h"

@implementation NotificationController

@synthesize ruleList, sensorList, sensorDict, tweetController;

#pragma mark -
#pragma mark Constructor/Destructor Methods

- (id)init
{		
	if (!(self = [super initWithWindowNibName:@"Notifications"]))
		return nil;
				
	// We need two data structures for the Sensor data.  An array to provide ordered access
	// for popup lists, and a dictionary for lookup by ID (so we don't need to search the array)
	
	self.sensorDict =	[NSMutableDictionary dictionaryWithCapacity: 5];
	self.sensorList =	[NSMutableArray arrayWithCapacity: 5];
	
	// the notification items saved from the last run
	self.ruleList =	[NotificationRule ruleList];
	
	[GrowlApplicationBridge setGrowlDelegate: self]; 
		
	return self;
}

- (void)dealloc 
{
	self.sensorDict = nil;
	self.sensorList = nil;
	self.ruleList = nil;
	
    [super dealloc];
}

- (void)windowDidLoad
{
	[[self window] setFrameAutosaveName:@"Rules Window"];
	[[self window] makeKeyAndOrderFront: self];
	
	[ruleTable setTarget: self];
	[ruleTable setDoubleAction: @selector(editRow)];
		
	// Before we can display anything, we need to build the popups
	
	for (NSMutableDictionary *theSensor in sensorList) 
	{				
		NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle: [theSensor objectForKey: @"name"] action: NULL keyEquivalent: @""];		
		[newItem setTag: [[theSensor objectForKey: @"index"] intValue]];
		[newItem setTarget:self];
		[[sensorPopup menu] addItem: newItem];
		[newItem release];
	}
	
	for (NotificationTest *theTest in [NotificationTest testList]) 
	{		
		NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle: theTest.name action: NULL keyEquivalent: @""];		
		[newItem setTag: theTest.test];
		[newItem setTarget:self];
		[[testPopup menu] addItem: newItem];
		[newItem release];
	}

	for (NotificationAction *theAction in [NotificationAction actionList]) 
	{		
		NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle: theAction.name action: NULL keyEquivalent: @""];		
		[newItem setTag: theAction.action];
		[newItem setTarget:self];
		[[actionPopup menu] addItem: newItem];
		[newItem release];
	}
	
	// now we need to validate the rule list we restored from the file, and disable any items for sensors that aren't installed
	
	for (NotificationRule *rule in ruleList)
	{
		Boolean found = NO;
		for (NSMutableDictionary *sensor in sensorList)
		{						
			if ([[rule sensorID] isEqualTo: [sensor objectForKey: @"id"]])
			{
				found = YES;
				break;
			}
		}
		if (!found)
		{
			rule.enabled = NO;
		}		
	}
	
	// now we can display the notifications table
	[ruleTable reloadData];
}

// called from App Delegate for each sensor reported by the Stoker

- (void) addSensor: (NSString *) sensorID name: (NSString *) sensorName
{				
//	NSLog(@"NotificationsController addSensor: %@ name: %@ index: %ld", sensorID, sensorName, index);
	
	NSMutableDictionary *oldSensor = [sensorDict objectForKey: sensorID];
	
	if (oldSensor)		// already in list, so it's a name change
	{
		NSNumber *index = [oldSensor objectForKey: @"index"];

		NSMutableArray *newSensor = [NSMutableDictionary dictionaryWithObjectsAndKeys: sensorName, @"name", sensorID, @"id", index , @"index", nil];

		[sensorList replaceObjectAtIndex: [index intValue] withObject: newSensor];
		[sensorDict setObject: newSensor forKey: sensorID];

	}
	else
	{
		NSNumber *index = [NSNumber numberWithInt: [sensorList count]];
		
		NSMutableArray *newSensor = [NSMutableDictionary dictionaryWithObjectsAndKeys: sensorName, @"name", sensorID, @"id", index, @"index", nil];

		[sensorList addObject: newSensor];
		[sensorDict setObject: newSensor forKey: sensorID];
	}
}

- (NSString *) notificationsTextForSensor: (NSString *) sensorID
{	
	// Need to loop through the criteria list, assembling a string that represents the notifications for this sensor
	
	NSMutableString *text = [NSMutableString stringWithCapacity: 5];
	
	for (NotificationRule *rule in ruleList)
	{
		if ([[rule sensorID] isEqualTo: sensorID] && [rule enabled])
		{
			switch ([rule action]) 
			{
				case kGrowlAlert:
					[text appendString: @"G"];
					break;
					
				case kEmailNotification:
					[text appendString: @"E"];
					break;
					
				case kTwitterNotification:
					[text appendString: @"T"];
					break;
					
				default:
					break;
			}
		}
	}
	
	return text;
}


- (void) checkSensor: (NSString *) sensorID andTemp: (NSNumber *) sensorTemp
{	
	for (NotificationRule *rule in ruleList)
	{
		if ([rule enabled])				// skip rules not enabled
		{
			if ([sensorID isEqualToString: [rule sensorID]])		// look for matching sensor
			{				
				switch ([rule test])		// branch depending on condition to be tested
				{
					case kSensorUnderTemp:			
						if ([sensorTemp compare: [rule value]] == NSOrderedAscending)
						{
							[self doNotification: rule withMessage: 
								[NSString stringWithFormat: @"StokerX Under Temperature Alarm (%3.1f) for sensor \"%@\".", [sensorTemp floatValue], [[sensorDict objectForKey: rule.sensorID] objectForKey: @"name"]]];
						}
						break;
						
					case kSensorOverTemp:
						if ([sensorTemp compare: [rule value]] == NSOrderedDescending)
						{
							[self doNotification: rule withMessage: 
								[NSString stringWithFormat: @"StokerX Over Temperature Alarm (%3.1f) for sensor \"%@\".", [sensorTemp floatValue], [[sensorDict objectForKey: rule.sensorID] objectForKey: @"name"]]];
						}
						break;
						
					case kSensorTargetTemp:
						if ([sensorTemp compare: [rule value]] == NSOrderedDescending)
						{
							[self doNotification: rule withMessage: 
								[NSString stringWithFormat: @"StokerX Target Temperature (%3.1f) for sensor \"%@\".", [sensorTemp floatValue], [[sensorDict objectForKey: rule.sensorID] objectForKey: @"name"]]];						
						}
						break;
						
					case kPeriodic:
						if (!([rule lastNotified] && (([[NSDate date] timeIntervalSinceReferenceDate] - [[rule lastNotified] doubleValue]) < [[rule value] doubleValue])))
						{
							[self doNotification: rule withMessage: 
									[NSString stringWithFormat: @"StokerX Periodic Notification for sensor \"%@\", current temperature is %3.1f.", 
										[[sensorDict objectForKey: rule.sensorID] objectForKey: @"name"], [sensorTemp floatValue]]];
							[rule setLastNotified: [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]]];
						}
						break;
												
					default:
						NSLog(@"Unknown condition for notification criteria:\r%@", rule);
						break;
				}
			}
		}
	}
}


- (void) doNotification: (NotificationRule *) rule withMessage: (NSString *) message
{	
	NSNumber *lastNotification = [rule lastNotified];
	
	// check to see if this notification has been done in the last minute.  Alerts are never repeated sooner than that
	
	if (lastNotification && (([[NSDate date] timeIntervalSinceReferenceDate] - [lastNotification doubleValue]) < 60.0))
		return;
	
	[rule setLastNotified: [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]]];
	
	switch ([rule action])		// branch depending on notification to use
	{							
		case kGrowlAlert:
		{			
			[GrowlApplicationBridge notifyWithTitle: @"StokerX"				
										description: message	
								   notificationName: [[[NotificationTest testList] objectAtIndex: [rule test]] name]		
										   iconData: nil				
										   priority: 0		
										   isSticky: NO		
									   clickContext: nil];
			break;
		}
			
		case kEmailNotification:
		{			
			EmailSender *emailSender = [[EmailSender alloc] init];
			[emailSender sendEmailMessage: message to: [[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey]];
			[emailSender release];
			break;
		}
			
		case kTwitterNotification:
		{
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setDateFormat:@"HH:mm:ss"];
			NSString *formattedMessage = [NSString stringWithFormat: @"%@ \nTime: %@", message, [dateFormatter stringFromDate: [NSDate date]]];
			
			[self.tweetController sendTweet: formattedMessage];
			break;
		}
			
		default:
		{
			NSLog(@"Unknown condition for notification, message = \"%@\"\r%@", message, rule);
			break;
		}
	}
	
}

#pragma mark -
#pragma mark Rule Table Editing Methods

- (IBAction) editRow;
{		
	// populate the pop-ups on the panel
	
	NotificationRule *theRule = [ruleList objectAtIndex: [ruleTable selectedRow]];
	NSDictionary *sensor = [sensorDict objectForKey: theRule.sensorID];
	NSInteger index = [[sensor objectForKey: @"index"] intValue];
	
	[sensorPopup selectItemAtIndex: index];
	[testPopup selectItemAtIndex:   theRule.test];
	[actionPopup selectItemAtIndex: theRule.action];
	[valueTextField setStringValue: [theRule.value stringValue]];
	
	// show as a sheet
	
	[NSApp beginSheet: ruleEditPanel 
	   modalForWindow: [self window] 
		modalDelegate: self 
	   didEndSelector: @selector(ruleEditDidEnd:returnCode:contextInfo:) 
		  contextInfo: (void *) theRule];

}


- (IBAction) editRuleList: (NSSegmentedControl *) sender;
{
	switch ([sender selectedSegment]) 
	{
		case 0:											// Add
		{
			[sensorPopup selectItemAtIndex: 0];
			[testPopup selectItemAtIndex: 0];
			[actionPopup selectItemAtIndex: 0];
			[valueTextField setStringValue: @""];
							
			[NSApp beginSheet: ruleEditPanel 
			   modalForWindow: [self window] 
				modalDelegate: self 
			   didEndSelector: @selector(ruleEditDidEnd:returnCode:contextInfo:) 	
				  contextInfo: nil];
			break;
		}	
			
		case 1:											// Delete
		{
			if ([ruleTable selectedRow] < 0)
				break;
			
			[ruleList removeObjectAtIndex: [ruleTable selectedRow]];
			[ruleTable reloadData];
			[NotificationRule saveRules: ruleList];
			break;
		}	
			
		case 2:
		{
			if ([ruleTable selectedRow] < 0)			// Edit
				break;
		
			[self editRow];
			break;
		}
			
		default:
			break;
	}
}

- (IBAction)closeCriteriaEditPanel:(id)sender
{
	[ruleEditPanel orderOut:self];
	[NSApp endSheet: ruleEditPanel returnCode:([sender tag] == 1) ? NSOKButton : NSCancelButton];
}

- (void)ruleEditDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	// bail if user Cancelled
	
	if (returnCode == NSCancelButton) 
		return;
		
	NotificationRule *theRule;
	
	// get the current values from the panel and put them in the record
	
	if (!contextInfo)		// no record, so this is an add
	{
		theRule = [[NotificationRule alloc] init];
		[theRule setEnabled: TRUE];
		[[NotificationRule ruleList] addObject: theRule];
	}
	else
	{
		theRule = [(NotificationRule *) contextInfo retain]; 
	}

	NSInteger sensorNum = [[sensorPopup selectedItem] tag];
	NSAssert1((sensorNum < [sensorList count]), @"SensorPopup tag out of range: %ld", sensorNum);
	
	NSMutableDictionary *sensor = [sensorList objectAtIndex: [[sensorPopup selectedItem] tag]];
								   
	theRule.sensorID		= [sensor objectForKey: @"id"];
	theRule.test			= [[testPopup selectedItem] tag];
	theRule.action			= [[actionPopup selectedItem] tag];
	theRule.value			= [NSNumber numberWithDouble: [valueTextField doubleValue]];
	theRule.lastNotified	= [NSNumber numberWithDouble: 0.0];	

	NSLog(@"Notifications ruleEditDidEnd: new rule = %@", theRule);

	[NotificationRule saveRules: ruleList];
	[theRule release];
	
	[ruleTable reloadData];
}

// These don't actually need to do anything, because the selected item is queried when the sheet is dismissed

- (IBAction) changeRuleSensor:(id)sender
{	
//	NSLog(@"Notifications changeRuleSensor: new sensor = %@ (%ld)", [sensorList objectAtIndex: [[sender selectedItem] tag]], [[sender selectedItem] tag]);
	
}
- (IBAction) changeRuleTest:(id)sender
{	
//	NSLog(@"Notifications changeRuleTest: new test = %@ (%ld)", [[NotificationTest testList] objectAtIndex: [[sender selectedItem] tag]], [[sender selectedItem] tag]);
	
}
- (IBAction) changeRuleValue:(id)sender
{
//	NSLog(@"Notifications changeRuleValue: new value = %@", [sender stringValue]);
}
- (IBAction) changeRuleAction:(id)sender
{
//	NSLog(@"Notifications changeRuleAction: new action = %@ (%ld)", [[NotificationAction actionList] objectAtIndex: [[sender selectedItem] tag]], [[sender selectedItem] tag]);
}

#pragma mark -
#pragma mark Table View Data Source and Delegate Methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (!ruleList)
		return 0;
	
	return [ruleList count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{		    
	NotificationRule *theRule = [ruleList objectAtIndex: rowIndex];
	
	if ([[tableColumn identifier] isEqual: @"Enabled"])
	{
		return [NSNumber numberWithInt: theRule.enabled];
	}
	else if ([[tableColumn identifier] isEqual: @"Sensor"])
	{
		return [[sensorDict objectForKey: theRule.sensorID] objectForKey: @"name"];
	}
	else if ([[tableColumn identifier] isEqual: @"Test"])
	{
		return [[[NotificationTest testList] objectAtIndex: theRule.test]  name];
	}
	else if ([[tableColumn identifier] isEqual: @"Value"])
	{
		return theRule.value;
	}
	else if ([[tableColumn identifier] isEqual: @"Action"])
	{
		return [[[NotificationAction actionList] objectAtIndex: theRule.action] name];
	}
	else
		return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{	
	NotificationRule *theRule = [ruleList objectAtIndex: rowIndex];

	if ([[tableColumn identifier] isEqual: @"Enabled"])
	{
		[theRule setEnabled: [anObject intValue] ? TRUE : FALSE];
	}
	[NotificationRule saveRules: ruleList];
	
	return;

}


#pragma mark -
#pragma mark Growl Delegate Methods

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSMutableArray *notifications = [[[NSMutableArray alloc] initWithCapacity: 10] autorelease];
		
	for (NotificationTest *test in  [NotificationTest testList])
	{
		[notifications addObject: [test name]];
	}
	
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  notifications, GROWL_NOTIFICATIONS_ALL,
						  notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
	
	return dict;
}

- (void) growlIsReady
{
	NSLog(@"Notifications growlIsReady");
}

- (void) growlNotificationWasClicked:(id)clickContext
{
	NSLog(@"Notifications growlNotificationWasClicked:");
}

- (void) growlNotificationTimedOut:(id)clickContext
{
	NSLog(@"Notifications growlNotificationTimedOut:");	
}

@end
