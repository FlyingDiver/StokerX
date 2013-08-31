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
	
	NSArray *smtpAccounts = [SSKeychain accountsForService: kStokerSMTPLogin];
	smtpSession.username = [[smtpAccounts objectAtIndex: 0] objectForKey: @"acct"];
	smtpSession.password = [SSKeychain passwordForService: kStokerSMTPLogin account: smtpSession.username];	

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
	
	NSArray *smtpAccounts = [SSKeychain accountsForService: kStokerSMTPLogin];
	smtpSession.username = [[smtpAccounts objectAtIndex: 0] objectForKey: @"acct"];
	smtpSession.password = [SSKeychain passwordForService: kStokerSMTPLogin account: smtpSession.username];
	
	MCOSMTPOperation *checkOperation = [smtpSession checkAccountOperationWithFrom: [MCOAddress addressWithMailbox: @"joe@flyingdiver.com"]];
	[checkOperation start:^(NSError *error)
	 {
		 if(error)
			 handler(FALSE);
		 else
			 handler(TRUE);
	 }];
}


@end
