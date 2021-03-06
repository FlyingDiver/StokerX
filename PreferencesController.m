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
NSString * const kReportTemplateKey  = @"ReportTemplate";
NSString * const kSendTweetsKey      = @"SendTweets";
NSString * const kSendPushMessagesKey = @"SendPushMessages";

NSString * const kEmailAddressKey    = @"EmailAddress";
NSString * const kSMTPServerKey		 = @"SMTPServer";
NSString * const kSMTPPortKey		 = @"SMTPPort";
NSString * const kConnectionTypeKey	 = @"SMTPConnectionType";
NSString * const kAuthTypeKey		 = @"SMTPAuthType";

NSString * const kStokerSMTPService	 = @"StokerX: SMTP";
NSString * const kStokerSMTPLogin	 = @"SMTPLogin";
NSString * const kStokerSMTPPassword = @"SMTPPassword";


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

- (IBAction)changeHTTPOnlyMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[httpOnlyModeCheckBox state] forKey: kHTTPOnlyModeKey];
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

- (IBAction)changeTemplatePopup:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[[templatePopup selectedItem] title] forKey: kReportTemplateKey];
}

- (IBAction) validateSMTP:(id)sender
{
	if ([[self.smtpServer stringValue] length] == 0)
	{
		[self.messageField setStringValue: @"SMTP server name required!"];
		return;
	}
	if ([[self.smtpPort stringValue] length] == 0)
	{
		[self.messageField setStringValue: @"SMTP port number required!"];
		return;
	}
	if ([[self.smtpUsername stringValue] length] == 0)
	{
		[self.messageField setStringValue: @"Username required!"];
		return;
	}
	if ([[self.smtpPassword stringValue] length] == 0)
	{
		[self.messageField setStringValue: @"Password required!"];
		return;
	}
	
	[[NSUserDefaults standardUserDefaults] setObject: [self.smtpServer stringValue]
											  forKey: kSMTPServerKey];
	
	[[NSUserDefaults standardUserDefaults] setObject: [self.smtpPort stringValue]
											  forKey: kSMTPPortKey];
	
	[[NSUserDefaults standardUserDefaults] setInteger: [[self.connectionType selectedItem] tag]
											   forKey: kConnectionTypeKey];
	
	[[NSUserDefaults standardUserDefaults] setInteger: [[self.authType selectedItem] tag]
											   forKey: kAuthTypeKey];
	
	[SSKeychain deletePasswordForService: kStokerSMTPService account: kStokerSMTPLogin];
	[SSKeychain deletePasswordForService: kStokerSMTPService account: kStokerSMTPPassword];
	[SSKeychain setPassword: [self.smtpUsername stringValue] forService: kStokerSMTPService account: kStokerSMTPLogin];
	[SSKeychain setPassword: [self.smtpPassword stringValue] forService: kStokerSMTPService account: kStokerSMTPPassword];
		
	[self.busyIndicator startAnimation: self];
	[self.validateButton setEnabled: NO];
	
	EmailSender *smtpTest = [[EmailSender alloc] init];
	[smtpTest validateSMTPWithCompletionHandler:^(BOOL valid)
	 {
		 if (!valid)
		 {
			 [self.busyIndicator stopAnimation: self];
			 [self.validateButton setEnabled: YES];
			 [self.messageField setStringValue: @"Unable to validate SMTP settings.  Try again."];
		 }
		 else
		 {
			 [self.busyIndicator stopAnimation: self];
			 [self.validateButton setEnabled: YES];
             [self.messageField setStringValue: @"SMTP settings validation successful - Saved!"];			 
		 }
		 [smtpTest release];
	 }];
}

- (IBAction)stokerCommHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://stokerx.com/user-guide/11-stoker-communications"]];
}

- (IBAction)smtpHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"http://stokerx.com/user-guide/10-email-notifications"]];
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
	
	// build list of template files for selection pop-up
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: [[NSProcessInfo processInfo] processName]];

	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
	NSString *templateDir = [NSString stringWithFormat: @"%@/Templates/", supportDir];
	NSArray *templateList = [fileManager contentsOfDirectoryAtPath: templateDir  error: nil];
	BOOL isDir;
	for (NSString *template in templateList)
	{
		[fileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@", templateDir, template] isDirectory: &isDir];
		if (isDir)
		{
			NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle: template action: NULL keyEquivalent: @""];
			[newItem setTarget:self];
			[[templatePopup menu] addItem: newItem];
			[newItem release];
		}
	}
	[templatePopup selectItemWithTitle: [[NSUserDefaults standardUserDefaults] stringForKey: kReportTemplateKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey])
		[emailAddress setStringValue:[[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kSMTPServerKey])
		[self.smtpServer setStringValue: [[NSUserDefaults standardUserDefaults] stringForKey: kSMTPServerKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kSMTPPortKey])
		[self.smtpPort setStringValue: [[NSUserDefaults standardUserDefaults] stringForKey: kSMTPPortKey]];
	
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kAuthTypeKey])
		[self.authType selectItemWithTag: [[NSUserDefaults standardUserDefaults] integerForKey: kAuthTypeKey]];
	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kConnectionTypeKey])
		[self.connectionType selectItemWithTag: [[NSUserDefaults standardUserDefaults] integerForKey: kConnectionTypeKey]];
	
	if ([SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPLogin])
		[self.smtpUsername setStringValue: [SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPLogin]];
	
	if ([SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPPassword])
		[self.smtpPassword setStringValue: [SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPPassword]];
	
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: kEmailAddressKey
											   options: NSKeyValueObservingOptionNew
											   context: NULL];
	// Show the window
	
	[[self window] setFrameAutosaveName:@"Prefs Window"];
	[[self window] makeKeyAndOrderFront: self];
	
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualTo: kEmailAddressKey])
	{		
//		EmailSender *providerCheck = [[EmailSender alloc] init];
//		[providerCheck findProviderForEmail: [change objectForKey:NSKeyValueChangeNewKey]];
		
	}
}


@end
