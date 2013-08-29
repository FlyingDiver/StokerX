//
//  Prowl.m
//
//  Created by Joe Keenan on 8/26/2013.
//  Copyright 2013 Joseph P Keenan Jr. All rights reserved.
//

#import "Prowl.h"
#import "MiniTwitter.h"

@implementation Prowl

@synthesize prowlAPIKey;

- (void) awakeFromNib
{	
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kProwlAuthCodeKey])
	{
		self.prowlAPIKey = [[NSUserDefaults standardUserDefaults] stringForKey: kProwlAuthCodeKey];
		NSLog(@"Prowl awakeFromNib using saved prowlAPIKey = %@", self.prowlAPIKey);
		[self updateUI];
	}
	
}
// This method kicks off the Prowl authentication process.

- (void) signInToProwl
{
	if ([[NSUserDefaults standardUserDefaults] stringForKey: kProwlAuthCodeKey])
	{
		self.prowlAPIKey = [[NSUserDefaults standardUserDefaults] stringForKey: kProwlAuthCodeKey];
		NSLog(@"Prowl signInToProwl using saved prowlAPIKey = %@", self.prowlAPIKey);
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
				 int remaining = [[successInfo objectForKey:@"remaining"] intValue];
				 NSString *token = [[prowlResponse objectForKey:@"retrieve"] objectForKey: @"token"];
				 NSString *authURL = [[prowlResponse objectForKey:@"retrieve"] objectForKey: @"url"];
				 NSLog(@"Prowl getToken success - token = %@, URL = %@, remaining = %d", token, authURL, remaining);
				 
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
				 [[NSUserDefaults standardUserDefaults] setObject: self.prowlAPIKey forKey: kProwlAuthCodeKey];
				 [self updateUI];

//				 NSLog(@"Prowl checkForProwlAuthWithToken: success - apiKey = %@, remaining = %d", self.prowlAPIKey, [[successInfo objectForKey:@"remaining"] intValue]);
			}
		 }
	 }];
}



- (void) sendPushMessage: (NSString *) message
{	
	if (self.prowlAPIKey)
	{
		NSString *trimmedText = [message precomposedStringWithCanonicalMapping];
		NSString *encodedText = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) trimmedText, NULL,(CFStringRef) @"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
		NSString *body = [NSString stringWithFormat: @"apikey=%@&application=%@&event=%@", self.prowlAPIKey, @"StokerX", encodedText];
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
		[[NSUserDefaults standardUserDefaults] setObject: nil forKey: kProwlAuthCodeKey];
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
