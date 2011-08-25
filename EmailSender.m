//
//  EmailSender.m
//  StokerX
//
//  Created by Joe Keenan on 8/15/2011.
//  Copyright 2011 Joseph P. Keenan Jr. All rights reserved.
//

#import <CoreServices/CoreServices.h>
#import "PreferencesController.h"
#import "EmailSender.h"
#import "Mail.h"

@implementation EmailSender

- (id)eventDidFail:(const AppleEvent *)event withError:(NSError *)error
{
	NSLog(@"Stoker EmailSender Error: %@", [error localizedDescription]);

    return nil;
}




- (void)sendEmailMessage: (NSString *) messageBody 
{

	NSString *emailAddress = [[NSUserDefaults standardUserDefaults] stringForKey: kEmailAddressKey];
	
	MailApplication *mail = [SBApplication applicationWithBundleIdentifier:@"com.apple.Mail"];
    mail.delegate = (id) self;
	
	MailOutgoingMessage *emailMessage = [[[mail classForScriptingClass:@"outgoing message"] alloc] initWithProperties:
                                                [NSDictionary dictionaryWithObjectsAndKeys:
                                                    @"StokerX Notification", @"subject",
                                                    messageBody, @"content",
                                                    nil]];
				
	[[mail outgoingMessages] addObject: emailMessage];

	emailMessage.sender = emailAddress;
	emailMessage.visible = NO;
    
    if ( [mail lastError] != nil )
	{
		[emailMessage release];
		return;
	}
	
	MailToRecipient *theRecipient = [[[mail classForScriptingClass:@"to recipient"] alloc] initWithProperties:
                                        [NSDictionary dictionaryWithObjectsAndKeys:
                                            emailAddress, @"address",
                                            nil]];
	[emailMessage.toRecipients addObject: theRecipient];
    [theRecipient release];
    
    if ( [mail lastError] != nil )
	{
		[emailMessage release];
		return;
	}
	
	[emailMessage send];
    [emailMessage release];
}

@end
