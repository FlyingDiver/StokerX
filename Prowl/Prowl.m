//
//  Prowl.m
//
//  Created by Joe Keenan on 8/26/2013.
//  Copyright 2013 Joseph P Keenan Jr. All rights reserved.
//

#import "Prowl.h"
#import "MiniTwitter.h"

static NSString *kStokerXProwlAPIKey  = @"StokerX: Prowl";
static NSString *kStokerXDefaultProwl = @"StokerXDefaultProwl";
static NSString *kProwlAuthCodeKey    = @"ProwlAuthCode";

@implementation Prowl
@synthesize prowlAPIKey;

- (void) awakeFromNib
{
	// convert from Preferences to keychain
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kProwlAuthCodeKey])
	{
		self.prowlAPIKey = [[NSUserDefaults standardUserDefaults] stringForKey: kProwlAuthCodeKey];
		[SSKeychain setPassword: self.prowlAPIKey forService: kStokerXProwlAPIKey account: kStokerXDefaultProwl];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey: kProwlAuthCodeKey];
		[self updateUI];
	}
	else if ([SSKeychain passwordForService:kStokerXProwlAPIKey account:kStokerXDefaultProwl])
	{
		self.prowlAPIKey = [SSKeychain passwordForService:kStokerXProwlAPIKey account:kStokerXDefaultProwl];
		[self updateUI];
	}
	
}
// This method kicks off the Prowl authentication process.

- (void) signInToProwl
{
	if ([SSKeychain passwordForService:kStokerXProwlAPIKey account:kStokerXDefaultProwl])
	{
		self.prowlAPIKey = [SSKeychain passwordForService:kStokerXProwlAPIKey account:kStokerXDefaultProwl];
		return;		// got a code, so don't bother trying to get one
	}
	
	NSString *query = [[NSString stringWithFormat:@"https://api.prowlapp.com/publicapi/retrieve/token?providerkey=%@", kProwlProviderKey]
						stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: query]];
	[request setHTTPMethod:@"GET"];
	
	GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest: request];
	[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error)
	 {
		 NSError *parseError;
		 NSDictionary *responseDict = [XMLReader dictionaryForXMLData: retrievedData error: &parseError];
		 
		 if (!responseDict)
		 {
			 NSLog(@"Prowl error - retrieved data =\n%@", retrievedData);
		 }
		 else
		 {
			 NSDictionary *prowlResponse = [responseDict objectForKey:@"prowl"];
			 
			 NSDictionary *errorInfo = [prowlResponse objectForKey:@"error"];
			 NSDictionary *successInfo = [prowlResponse objectForKey:@"success"];
			 if (errorInfo)
			 {
				 NSNumber *errorCode = [errorInfo objectForKey:@"code"];
				 NSString *errorText = [errorInfo objectForKey:@"text"];
				 NSLog(@"Prowl getToken error - errorCode = %@, errorText = %@", errorCode, errorText);
			 }
			 else if (successInfo)
			 {
				 NSString *token = [[prowlResponse objectForKey:@"retrieve"] objectForKey: @"token"];
				 NSString *authURL = [[prowlResponse objectForKey:@"retrieve"] objectForKey: @"url"];
				 
				 // get the auth token now
				[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: authURL]];

				 [NSTimer scheduledTimerWithTimeInterval: 5
												  target: self
												selector: @selector(checkForProwlAuthWithToken:)
												userInfo: token
												 repeats: NO];
			 }
		 }
	 }];
}

- (void) checkForProwlAuthWithToken: (NSTimer*) theTimer
{
	NSString *token = [theTimer userInfo];
	NSString *query = [[NSString stringWithFormat:@"https://api.prowlapp.com/publicapi/retrieve/apikey?providerkey=%@&token=%@", kProwlProviderKey, token]
					   stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: query]];
	[request setHTTPMethod:@"GET"];

	GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest: request];
	[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error)
	 {
		 NSError *parseError;
		 NSDictionary *responseDict = [XMLReader dictionaryForXMLData: retrievedData error: &parseError];
		 
		 if (!responseDict)
		 {
			 NSLog(@"Prowl checkForProwlAuthWithToken: error - retrieved data =\n%@", retrievedData);
		 }
		 else
		 {
			 NSDictionary *prowlResponse = [responseDict objectForKey:@"prowl"];
			 
			 NSDictionary *errorInfo = [prowlResponse objectForKey:@"error"];
			 NSDictionary *successInfo = [prowlResponse objectForKey:@"success"];
			 if (errorInfo)
			 {
				 if ([[errorInfo objectForKey:@"code"] isEqualToString: @"409"])
				 {
					 // not authorized error, try again
					 [NSTimer scheduledTimerWithTimeInterval: 5
													  target: self
													selector: @selector(checkForProwlAuthWithToken:)
													userInfo: token
													 repeats: NO];
				 }
				 else
					 NSLog(@"Prowl checkForProwlAuthWithToken: error - errorCode = %@, errorText = %@", [errorInfo objectForKey:@"code"], [errorInfo objectForKey:@"text"]);
			 }
			 else if (successInfo)
			 {
				 self.prowlAPIKey = [[prowlResponse objectForKey:@"retrieve"] objectForKey: @"apikey"];
				 [SSKeychain setPassword: self.prowlAPIKey forService: kStokerXProwlAPIKey account: kStokerXDefaultProwl];
				 [self updateUI];
			}
		 }
	 }];
}



- (void) sendPushMessage: (NSString *) message
{
	// Don't send message if they're not enabled
	
	if (![[[NSUserDefaults standardUserDefaults] stringForKey: kSendPushMessagesKey] boolValue])
		return;
	
	if (self.prowlAPIKey)
	{
		NSString *trimmedText = [message precomposedStringWithCanonicalMapping];
		NSString *encodedText = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) trimmedText, NULL,(CFStringRef) @"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
		NSString *body = [NSString stringWithFormat: @"apikey=%@&application=%@&event=%@", self.prowlAPIKey, @"StokerX", encodedText];
		[encodedText release];
		
		NSString *query = [@"https://api.prowlapp.com/publicapi/add" stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:query]];
		
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody: [body dataUsingEncoding:NSUTF8StringEncoding]];
		
		GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];
		[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error)
		 {
			 NSError *parseError;
			 NSDictionary *responseDict = [XMLReader dictionaryForXMLData: retrievedData error: &parseError];
			 
			 if (!responseDict)
			 {
				 NSLog(@"Prowl sendPushMessage: error - retrieved data =\n%@", retrievedData);
			 }
			 else
			 {
				 NSDictionary *prowlResponse = [responseDict objectForKey:@"prowl"];
				 
				 NSDictionary *errorInfo = [prowlResponse objectForKey:@"error"];
				 if (errorInfo)
				 {
					 NSLog(@"Prowl sendPushMessage: error - errorCode = %@, errorText = %@", [errorInfo objectForKey:@"code"], [errorInfo objectForKey:@"text"]);
				 }
			 }
		 }];
	}
}


- (void)updateUI 
{	
	// update the menu items to reflect the authorized state
	
	if (self.prowlAPIKey) 
	{				
		[authorizeProwlMenuItem setTitle: @"Discard Prowl Authentication"];
		[enableProwlMenuItem setEnabled: YES];
		
		if ([[[NSUserDefaults standardUserDefaults] stringForKey: kSendPushMessagesKey] boolValue])
		{
			[enableProwlMenuItem setState: NSOnState];
		}
		else
		{
			[enableProwlMenuItem setState: NSOffState];
		}
	} 
	else 
	{				
		[authorizeProwlMenuItem setTitle: @"Authenticate for Prowl"];
		[enableProwlMenuItem setEnabled: NO];
		[enableProwlMenuItem setState: NSOffState];
	}
}


#pragma mark -
#pragma mark Prowl Menu Handling Methods

- (void) signInOutClicked: (id) sender
{
	if (!self.prowlAPIKey) 
	{
		[self signInToProwl];
	} 
	else 
	{
		[SSKeychain setPassword: nil forService: kStokerXProwlAPIKey account: kStokerXDefaultProwl];
	}
	[self updateUI];
}


- (void) enableProwl: (id) sender
{
	if ([enableProwlMenuItem state] == NSOffState)
	{
		[enableProwlMenuItem setState: NSOnState];
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: kSendPushMessagesKey];
	}
	else if  ([enableProwlMenuItem state] == NSOnState)
	{
		[enableProwlMenuItem setState: NSOffState];
		[[NSUserDefaults standardUserDefaults] setBool: NO forKey: kSendPushMessagesKey];	
	}
	else
		NSLog(@"Prowl enableProwl: unknown state");
	
	[self updateUI];
}


@end
