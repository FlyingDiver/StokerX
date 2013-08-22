//
//  PreferencesController.m
//  StokerX
//
//  Created by Joe Keenan on 8/26/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//
// Manages the preferences panel

#import "PreferencesController.h"

NSString * const kStokeripAddressKey = @"StokeripAddress";
NSString * const kHTTPOnlyModeKey    = @"HTTPOnlyMode";
NSString * const kMinGraphTempKey    = @"MinGraphTemp";
NSString * const kMaxGraphTempKey    = @"MaxGraphTemp";
NSString * const kEmailAddressKey    = @"EmailAddress";
NSString * const kSendTweetsKey      = @"SendTweets";
NSString * const kReportTemplateKey  = @"ReportTemplate";

#define MIN_TEMP_AXIS			0.0
#define MAX_TEMP_AXIS			500.0

@implementation PreferencesController

- (id) init
{	
	if (!(self = [super initWithWindowNibName:@"Preferences"]))
		return nil;
	
	return self;
}

- (IBAction)changeStokeripAddressField:(id)sender
{
	NSLog(@"PreferencesController - saving StokeripAddress: %@", [ipAddress stringValue]);
	[[NSUserDefaults standardUserDefaults] setObject:[ipAddress stringValue] forKey: kStokeripAddressKey];
}

- (IBAction)changeHTTPOnlyMode:(id)sender
{
	NSLog(@"PreferencesController - saving HTTPOnlyMode: %@", [httpOnlyModeCheckBox state] ? @"Yes" : @"No");
	[[NSUserDefaults standardUserDefaults] setBool:[httpOnlyModeCheckBox state] forKey: kHTTPOnlyModeKey];
}

- (IBAction)changeMinGraphTempField:(id)sender
{ 
	NSLog(@"PreferencesController - saving MinGraphTemp: %@", [minGraphTemp stringValue]);
    if ([minGraphTemp doubleValue] < MIN_TEMP_AXIS)
    {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%f", MIN_TEMP_AXIS] forKey: kMinGraphTempKey];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setObject:[minGraphTemp stringValue] forKey: kMinGraphTempKey];
    }
}

- (IBAction)changeMaxGraphTempField:(id)sender
{    
	NSLog(@"PreferencesController - saving MaxGraphTemp: %@", [maxGraphTemp stringValue]);
    if ([maxGraphTemp doubleValue] > MAX_TEMP_AXIS)
    {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%f", MAX_TEMP_AXIS] forKey: kMaxGraphTempKey];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setObject:[maxGraphTemp stringValue] forKey: kMaxGraphTempKey];
    }
}

- (IBAction)changeEmailAddressField:(id)sender
{
	NSLog(@"PreferencesController - saving EmailAddress: %@", [emailAddress stringValue]);
	[[NSUserDefaults standardUserDefaults] setObject:[emailAddress stringValue] forKey: kEmailAddressKey];
}

- (IBAction)changeTemplatePopup:(id)sender
{
	NSLog(@"PreferencesController - saving ReportTemplate: %@", [[templatePopup selectedItem] title]);
	[[NSUserDefaults standardUserDefaults] setObject:[[templatePopup selectedItem] title] forKey: kReportTemplateKey];
}

- (void)windowDidLoad
{
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey])
		[ipAddress setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey]];
	
	[httpOnlyModeCheckBox setState:[[[NSUserDefaults standardUserDefaults] stringForKey: kHTTPOnlyModeKey] boolValue]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey])
		[minGraphTemp setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey])
		[maxGraphTemp setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey])
		[emailAddress setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey]];
	
	// build list of template files for selection pop-up
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: [[NSProcessInfo processInfo] processName]];

	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];	
	NSArray *templateList = [fileManager contentsOfDirectoryAtPath: [NSString stringWithFormat: @"%@/Templates/", supportDir] error: nil];
	for (NSString *template in templateList)
	{
		if ([template rangeOfString: @".html"].location != NSNotFound)
		{
			NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle: [[template lastPathComponent] stringByDeletingPathExtension] action: NULL keyEquivalent: @""];
			[newItem setTarget:self];
			[[templatePopup menu] addItem: newItem];
			[newItem release];
		}
	}
	[templatePopup selectItemWithTitle: [[NSUserDefaults standardUserDefaults] stringForKey: kReportTemplateKey]];

	// Show the window
	
	[[self window] setFrameAutosaveName:@"Prefs Window"];
	[[self window] makeKeyAndOrderFront: self];
	
}

@end
