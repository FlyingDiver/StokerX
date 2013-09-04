//
//  EmailSender.m
//  StokerX
//
//  Created by Joe Keenan on 8/15/2011.
//  Copyright 2011 Joseph P. Keenan Jr. All rights reserved.
//

#import <CoreServices/CoreServices.h>
#import "EmailSender.h"
#import "PreferencesController.h"

@implementation EmailSender

- (void)sendEmailMessage:(NSString *) messageBody to: (NSString *) recipient
{	
	MCOSMTPSession *smtpSession = [[MCOSMTPSession alloc] init];
	
	smtpSession.hostname = [[NSUserDefaults standardUserDefaults] stringForKey: kSMTPServerKey];
	smtpSession.port = [[NSUserDefaults standardUserDefaults] integerForKey: kSMTPPortKey];
	smtpSession.connectionType = [[NSUserDefaults standardUserDefaults] integerForKey: kConnectionTypeKey];
	smtpSession.authType =[[NSUserDefaults standardUserDefaults] integerForKey: kAuthTypeKey];	
	smtpSession.username = [SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPLogin];
	smtpSession.password = [SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPPassword];

	MCOMessageBuilder * builder = [[MCOMessageBuilder alloc] init];
	
	[[builder header] setFrom:[MCOAddress addressWithDisplayName:nil mailbox: recipient]];

	[[builder header] setTo: [NSArray arrayWithObject: [MCOAddress addressWithMailbox: recipient]]];
	
	[[builder header] setSubject: @"StokerX Notification"];
	
	[builder setTextBody: messageBody];
		
	MCOSMTPSendOperation *sendOperation = [smtpSession sendOperationWithData: [builder data]];
	[sendOperation start:^(NSError *error)
	{
		if(error)
		{
			NSLog(@"EmailSender sendEmailMessage: error: code = %ld, domain = %@\nuserInfo = %@",  (long)error.code, error.domain, error.userInfo);
		}
	}];
}

- (void) validateSMTPWithCompletionHandler:(void (^)(BOOL))handler
{	
	MCOSMTPSession *smtpSession = [[MCOSMTPSession alloc] init];
	
	smtpSession.hostname = [[NSUserDefaults standardUserDefaults] stringForKey: kSMTPServerKey];
	smtpSession.port = [[NSUserDefaults standardUserDefaults] integerForKey: kSMTPPortKey];
	smtpSession.connectionType = [[NSUserDefaults standardUserDefaults] integerForKey: kConnectionTypeKey];
	smtpSession.authType =[[NSUserDefaults standardUserDefaults] integerForKey: kAuthTypeKey];
	smtpSession.username = [SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPLogin];
	smtpSession.password = [SSKeychain passwordForService: kStokerSMTPService account: kStokerSMTPPassword];

	
	NSString *checkEmail = [[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey];
	MCOSMTPOperation *checkOperation = [smtpSession checkAccountOperationWithFrom: [MCOAddress addressWithMailbox: checkEmail]];
	[checkOperation start:^(NSError *error)
	 {
		 if(error)
		 {
			 NSLog(@"SMTP check error = %@", error);
			 handler(FALSE);
		 }
		 else
		 {
			 handler(TRUE);
		 }
	 }];
}

- (BOOL) findProviderForEmail: (NSString *) emailAddress
{
	MCOMailProvidersManager *providerManager = [MCOMailProvidersManager sharedManager];
	
	MCOMailProvider *provider = [providerManager providerForEmail: emailAddress];
	if (!provider)
	{
		NSLog(@"No Email Provider found for %@", emailAddress);
		return false;
	}
	
	NSLog(@"Email Providers found for %@:", emailAddress);
	NSArray *providers = [provider smtpServices];
	for (MCONetService *i in providers)
	{
		NSLog(@"\tHostname = %@, port = %d, connectionType = %u, hostnameWithEmail = %@",
			  i.hostname, i.port, i.connectionType, [i hostnameWithEmail: emailAddress]);
	}
	return true;
}

@end
