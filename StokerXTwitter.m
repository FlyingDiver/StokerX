//
//  StokerTwitter.m
//  StokerX
//
//  Created by Joe Keenan on 8/13/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerXTwitter.h"

@implementation StokerXTwitter

@synthesize consumer, requestToken, accessToken;

- (void) awakeFromNib
{	
	// check for saved access token from previous authentication
	
	accessToken = [[OAToken alloc] initWithUserDefaultsUsingServiceProviderName: kOAuthTwitterDefaultsDomain prefix: kOAuthTwitterDefaultsPrefix];
	if (accessToken && ([accessToken.key length] > 0) && ([accessToken.secret length] > 0))
	{
//		NSLog(@"StokerXTwitter awakeFromNib: Obtained accessToken from saved defaults");

		twitterIsAvailable = YES;

		// set up the Twitter Engine
		
		twitterEngine = [[MGTwitterEngine alloc] initWithDelegate:self];
		[twitterEngine setUsesSecureConnection:NO];
		[twitterEngine setConsumerKey: kOAuthConsumerKey secret: kOAuthConsumerSecret];
		[twitterEngine setAccessToken: accessToken];
		[accessToken release];
		
		// set up the menus properly
		
		[authorizeTwitterMenuItem setTitle: @"Deauthorize Twitter"];
		[enableTwitterMenuItem setEnabled: YES];
		
		if ([[[NSUserDefaults standardUserDefaults] stringForKey: kSendTweetsKey] boolValue])
		{
			[enableTwitterMenuItem setState: NSOnState];
		}
		else
		{
			[enableTwitterMenuItem setState: NSOffState];
		}
	}
	else
	{
//		NSLog(@"StokerXTwitter awakeFromNib: No accessToken from saved defaults");
		[authorizeTwitterMenuItem setTitle: @"Authorize Twitter"];
		[enableTwitterMenuItem setEnabled: NO];
		[enableTwitterMenuItem setState: NSOffState];
	}
}

#pragma mark -
#pragma mark Twitter Menu Handling Methods

- (void) authorizeTwitter: (id) sender
{
	if (!twitterIsAvailable)
	{
		accessToken = [[OAToken alloc] initWithUserDefaultsUsingServiceProviderName: kOAuthTwitterDefaultsDomain prefix: kOAuthTwitterDefaultsPrefix];
		if (accessToken && ([accessToken.key length] > 0) && ([accessToken.secret length] > 0))
		{
//			NSLog(@"StokerXTwitter authorizeTwitter: Obtained accessToken from saved defaults");
			
			twitterIsAvailable = YES;
			
			// set up the Twitter Engine
			
			twitterEngine = [[MGTwitterEngine alloc] initWithDelegate:self];
			[twitterEngine setUsesSecureConnection:NO];
			[twitterEngine setConsumerKey: kOAuthConsumerKey secret: kOAuthConsumerSecret];
			[twitterEngine setAccessToken: accessToken];
			[accessToken release];
			
			// set up the menus properly
			
			[authorizeTwitterMenuItem setTitle: @"Deauthorize Twitter"];
			[enableTwitterMenuItem setEnabled: YES];
			
			if ([[[NSUserDefaults standardUserDefaults] stringForKey: kSendTweetsKey] boolValue])
			{
				[enableTwitterMenuItem setState: NSOnState];
			}
			else
			{
				[enableTwitterMenuItem setState: NSOffState];
			}
			return;
		}
		
		// No authorization token saved, so start the process
		
		NSLog(@"StokerXTwitter authorizeTwitter: Starting token request process");
		
		[self getRequestToken];
	}
	else		// Twitter already authorized, so we're supposed to deauthorize
	{
		NSLog(@"StokerXTwitter authorizeTwitter: deauthorizing");

		[accessToken release];
		accessToken = [[[OAToken alloc] init] autorelease];	// get a dummy one
		[accessToken storeInUserDefaultsWithServiceProviderName: kOAuthTwitterDefaultsDomain prefix: kOAuthTwitterDefaultsPrefix];
		accessToken = nil;
		
		if (twitterEngine)
		{
			[twitterEngine release];
			twitterEngine = nil;
		}
		twitterIsAvailable = NO;
		[authorizeTwitterMenuItem setTitle: @"Authorize Twitter"];
		[enableTwitterMenuItem setEnabled: NO];
		[enableTwitterMenuItem setState: NSOffState];
	}
		
}

- (void) enableTwitter: (id) sender
{
	if ([enableTwitterMenuItem state] == NSOffState)
	{
		[enableTwitterMenuItem setState: NSOnState];
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: kSendTweetsKey];	
	}
	else if  ([enableTwitterMenuItem state] == NSOnState)
	{
		[enableTwitterMenuItem setState: NSOffState];
		[[NSUserDefaults standardUserDefaults] setBool: NO forKey: kSendTweetsKey];	
	}
	else
		NSLog(@"StokerXTwitter enableTwitter: unknown state");
}

- (void) sendTweet: (NSString *) tweet
{
	if (twitterIsAvailable)
		[twitterEngine sendUpdate: tweet];
}

- (BOOL)validateMenuItem:(NSMenuItem *) item 
{
    if ([item action] == @selector(enableTwitter:))
	{
		if (twitterIsAvailable)
			return YES;
		else
			return NO;
	}
	else
		return YES;
}
		
#pragma mark -
#pragma mark OAuth Request Methods

- (void)getRequestToken
{	
	NSLog(@"StokerXTwitter getRequestToken");

	consumer = [[OAConsumer alloc] initWithKey: kOAuthConsumerKey secret:kOAuthConsumerSecret];		
    OAMutableURLRequest *request = [[[OAMutableURLRequest alloc] initWithURL: [NSURL URLWithString:kOAuthTwitterRequestTokenURL]
																	consumer: self.consumer
																	   token: nil 
																	   realm: nil 
														   signatureProvider: nil] autorelease];
	if (!request)
		return;
 
	[request setHTTPMethod:@"POST"];
	
    OADataFetcher *fetcher = [[[OADataFetcher alloc] init] autorelease];	
    [fetcher fetchDataWithRequest:request delegate:self didFinishSelector:@selector(setRequestToken:withData:) didFailSelector:@selector(failRequestToken:data:)];
}


- (void)setRequestToken:(OAServiceTicket *)ticket withData:(NSData *)data
{
	NSLog(@"StokerXTwitter setRequestToken: ticket.didSucceed = %d", ticket.didSucceed);

	if ((!ticket.didSucceed) || (!data))
		return;
	
	NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!dataString)
		return;
	
	self.requestToken = [[[OAToken alloc] initWithHTTPResponseBody:dataString] autorelease];
	
	[dataString release];
	dataString = nil;
	
    NSString *urlString = [NSString stringWithFormat: @"%@?oauth_token=%@", kOAuthTwitterAuthorizeURL, self.requestToken.key];
    NSURL *requestURL = [NSURL URLWithString: urlString];
		
    [[NSWorkspace sharedWorkspace] openURL: requestURL];

	NSAlert *alert = [NSAlert alertWithMessageText: @"Enter PIN number from Twitter"										 
									 defaultButton: @"OK"									
								   alternateButton: @"Cancel"									
									   otherButton: nil							 
						 informativeTextWithFormat:@""];
		
	NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
	[input setStringValue: @""];
	[alert setAccessoryView: input];
	NSInteger button = [alert runModal];

	if (button == NSAlertDefaultReturn) 
	{
		[input validateEditing];
		
		NSLog(@"StokerXTwitter setRequestToken: User entered PIN %@, proceeding", [input stringValue]);

		self.requestToken.secret = [input stringValue];
		[self getAccessToken];
	} 
	else if (button == NSAlertAlternateReturn) 
	{
		NSLog(@"StokerXTwitter setRequestToken: User cancelled");
	} 
	else 
	{
		NSLog(@"StokerXTwitter setRequestToken: Invalid input dialog button %ld", (long) button);
	}
	[input release];
}


- (void)failRequestToken:(OAServiceTicket *)ticket data:(NSData *)data
{
	NSLog(@"failRequestToken: '%@'", data);
}

- (void)getAccessToken
{
	NSLog(@"StokerXTwitter getAccessToken");

    OAMutableURLRequest *request = [[[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:kOAuthTwitterAccessTokenURL] 
																	consumer: self.consumer
																	   token: self.requestToken  
																	   realm: nil 
														   signatureProvider: nil] autorelease];
	if (!request)
		return;
	
    [request setHTTPMethod:@"POST"];

	NSLog(@"StokerXTwitter OAMutableURLRequest = %@", request);

    OADataFetcher *fetcher = [[[OADataFetcher alloc] init] autorelease];	
    [fetcher fetchDataWithRequest:request delegate:self didFinishSelector:@selector(setAccessToken:withData:) didFailSelector:@selector(failAccessToken:data:)];
}

- (void) setAccessToken:(OAServiceTicket *)ticket withData:(NSData *)data
{
	NSLog(@"StokerXTwitter setAccessToken: ticket.didSucceed = %d", ticket.didSucceed);

	if ((!ticket.didSucceed) || (!data))
		return;
	
	NSString *dataString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	if (!dataString)
		return;
	
	// Get the token and save it
	
	accessToken = [[[OAToken alloc] initWithHTTPResponseBody:dataString] autorelease];
	[accessToken storeInUserDefaultsWithServiceProviderName: kOAuthTwitterDefaultsDomain prefix: kOAuthTwitterDefaultsPrefix];

	// set up the Twitter Engine
	
	twitterEngine = [[MGTwitterEngine alloc] initWithDelegate:self];
	[twitterEngine setUsesSecureConnection:NO];
	[twitterEngine setConsumerKey: kOAuthConsumerKey secret: kOAuthConsumerSecret];
	[twitterEngine setAccessToken: accessToken];
	
	twitterIsAvailable = YES;
			
	// set up the menus properly
	
	[authorizeTwitterMenuItem setTitle: @"Deauthorize Twitter"];
	[enableTwitterMenuItem setEnabled: YES];
	
	if ([[[NSUserDefaults standardUserDefaults] stringForKey: kSendTweetsKey] boolValue])
	{
		[enableTwitterMenuItem setState: NSOnState];
	}
	else
	{
		[enableTwitterMenuItem setState: NSOffState];
	}
	
	// when we receive an access token we also get to know the username
	NSString *username = [self usernameFromHTTPResponseBody:dataString];
	[[NSUserDefaults standardUserDefaults] setValue: username forKey:@"TwitterUsername"];	

	NSLog(@"StokerXTwitter setAccessToken: Obtained accessToken from OAuth process, username = %@", username);
}

- (void)failAccessToken:(OAServiceTicket *)ticket data:(NSData *)data
{
	NSLog(@"failAccessToken: '%@'", data);
}


- (NSString *) usernameFromHTTPResponseBody:(NSString *)body
{
	if (!body)
		return nil;
	
	NSArray *tuples = [body componentsSeparatedByString:@"&"];
	if ((!tuples) || (tuples.count < 1))
		return nil;
	
	for (NSString *tuple in tuples) {
		NSArray *keyValueArray = [tuple componentsSeparatedByString:@"="];
		if ((keyValueArray) && (keyValueArray.count == 2)) {
			NSString *key = [keyValueArray objectAtIndex:0];
			NSString *value = [keyValueArray objectAtIndex:1];
			if ([key isEqualToString:@"screen_name"]) {
				return value;
			}
		}
	}
	
	return nil;
}




#pragma mark -
#pragma mark MGTwitterEngine Delegate Methods

// These delegate methods are called after a connection has been established

- (void)requestSucceeded:(NSString *)connectionIdentifier
{
 //   NSLog(@"StokerTwitter: Request succeeded for connection, Identifier = %@", connectionIdentifier);
}

- (void)requestFailed:(NSString *)connectionIdentifier withError:(NSError *)error
{
    NSLog(@"StokerTwitter: Request failed for connection, error = %@\r%@", 
          [error localizedDescription], 
          [error userInfo]);
}

// These delegate methods are called after all results are parsed from the connection. 

- (void)statusesReceived:(NSArray *)statuses forRequest:(NSString *)connectionIdentifier
{
//    NSLog(@"StokerTwitter: Got statuses for %@", connectionIdentifier);
}

- (void)miscInfoReceived:(NSArray *)miscInfo forRequest:(NSString *)connectionIdentifier
{
//	NSLog(@"StokerTwitter: Got misc info for %@:\r%@", connectionIdentifier, miscInfo);
//    NSLog(@"StokerTwitter: Got misc info for %@", connectionIdentifier);
}

- (void)connectionStarted:(NSString *)connectionIdentifier
{
//    NSLog(@"StokerTwitter: Connection started %@, connections = %lu", connectionIdentifier, [twitterEngine numberOfConnections]);
}

- (void)connectionFinished:(NSString *)connectionIdentifier
{
//    NSLog(@"StokerTwitter: Connection finished %@, connections = %lu", connectionIdentifier, [twitterEngine numberOfConnections]);
}

- (void)accessTokenReceived:(OAToken *)aToken forRequest:(NSString *)connectionIdentifier
{
//	NSLog(@"MGTwitterEngine Delegate: Access token received! %@",aToken);
}

@end
