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
NSString * const kStokerhttpPortKey  = @"StokerhttpPort";
NSString * const kTelnetKey          = @"TelnetMode";
NSString * const kMinGraphTempKey    = @"MinGraphTemp";
NSString * const kMaxGraphTempKey    = @"MaxGraphTemp";
NSString * const kEmailAddressKey    = @"EmailAddress";
NSString * const kLidOffEnabledKey   = @"LidOffEnabled";
NSString * const kLidOffDropKey      = @"LidOffDrop";
NSString * const kLidOffWaitKey      = @"LidOffWait";
NSString * const kSendTweetsKey      = @"SendTweets";
NSString * const kAlarmSoundKey      = @"AlarmSound";

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
	[[NSUserDefaults standardUserDefaults] setObject:[ipAddress stringValue] forKey: kStokeripAddressKey];
}

- (IBAction)changeStokerhttpPortField:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[httpPort stringValue] forKey: kStokerhttpPortKey];
}

- (IBAction)changeTelnetMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[telnetCheckBox state] forKey: kTelnetKey];
}

- (IBAction)changeMinGraphTempField:(id)sender
{ 
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
	[[NSUserDefaults standardUserDefaults] setObject:[emailAddress stringValue] forKey: kEmailAddressKey];
}

- (void)windowDidLoad
{
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey])
		[ipAddress setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kStokeripAddressKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kStokerhttpPortKey])
		[httpPort setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kStokerhttpPortKey]];
	
	[telnetCheckBox setState:[[[NSUserDefaults standardUserDefaults] stringForKey: kTelnetKey] boolValue]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey])
		[minGraphTemp setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kMinGraphTempKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey])
		[maxGraphTemp setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kMaxGraphTempKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey])
		[emailAddress setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey]];
	
	[alarmPicker setPrefsPrefix: kAlarmSoundKey];			
	[alarmPicker setDefaultSoundPath: @"/System/Library/Sounds/Glass.aiff"];
	
	[[self window] setFrameAutosaveName:@"Prefs Window"];
	[[self window] makeKeyAndOrderFront: self];
	
}

@end
