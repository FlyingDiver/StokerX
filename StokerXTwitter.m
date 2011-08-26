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
		
		[authorizeTwitterMenuItem setTitle: @"Deauthorize"];
		[enableTwitterMenuItem setEnabled: YES];
		
		if ([[[NSUserDefaults standardUserDefaults] stringForKey: kSendTweets] boolValue])
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
		[authorizeTwitterMenuItem setTitle: @"Authorize"];
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
			
			[authorizeTwitterMenuItem setTitle: @"Deauthorize"];
			[enableTwitterMenuItem setEnabled: YES];
			
			if ([[[NSUserDefaults standardUserDefaults] stringForKey: kSendTweets] boolValue])
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
		[authorizeTwitterMenuItem setTitle: @"Authorize"];
		[enableTwitterMenuItem setEnabled: NO];
		[enableTwitterMenuItem setState: NSOffState];
	}
		
}

- (void) enableTwitter: (id) sender
{
	if ([enableTwitterMenuItem state] == NSOffState)
	{
		[enableTwitterMenuItem setState: NSOnState];
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: kSendTweets];	
	}
	else if  ([enableTwitterMenuItem state] == NSOnState)
	{
		[enableTwitterMenuItem setState: NSOffState];
		[[NSUserDefaults standardUserDefaults] setBool: NO forKey: kSendTweets];	
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
	

	OAMutableURLRequest* requestURL = [[[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:kOAuthTwitterAuthorizeURL] consumer:nil token:self.requestToken realm:nil signatureProvider:nil] autorelease];	
	[requestURL setParameters:[NSArray arrayWithObject:[[[OARequestParameter alloc] initWithName:@"oauth_token" value: self.requestToken.key] autorelease]]];	

	[[webview mainFrame] loadRequest: requestURL];
	if (![[NSApp mainWindow] isVisible])
		[[NSApp mainWindow] makeKeyAndOrderFront:self];
	[NSApp beginSheet: webSheet modalForWindow: [NSApp mainWindow] modalDelegate:self didEndSelector: @selector(webSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}


- (void)failRequestToken:(OAServiceTicket *)ticket data:(NSData *)data
{
	NSLog(@"failRequestToken: '%@'", data);
}

- (void)getAccessToken
{
	NSLog(@"StokerXTwitter getAccessToken, key = %@, secret = %@", requestToken.key, requestToken.secret);

    OAMutableURLRequest *request = [[[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:kOAuthTwitterAccessTokenURL] 
																	consumer: self.consumer
																	   token: self.requestToken  
																	   realm: nil 
														   signatureProvider: nil] autorelease];
	if (!request)
		return;
	
    [request setHTTPMethod:@"POST"];

	NSLog(@"StokerXTwitter OAMutableURLRequest = %@", request.signature);

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
	
	[authorizeTwitterMenuItem setTitle: @"Deauthorize"];
	[enableTwitterMenuItem setEnabled: YES];
	
	if ([[[NSUserDefaults standardUserDefaults] stringForKey: kSendTweets] boolValue])
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

#pragma mark -
#pragma mark WebView Sheet Methods

- (IBAction)cancelWebSheet:(id)sender;
{
	[webSheet endEditingFor:nil];
    [NSApp endSheet:webSheet returnCode:[sender tag]];
}


- (void)webSheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
{	
	NSLog(@"webSheetDidEnd:returnCode: %d", returnCode);
    [sheet orderOut:self];	
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
{	
	NSLog(@"webView:didFinishLoadForFrame:");
	NSLog(@"URL: %@", [NSURL URLWithString:[sender mainFrameURL]]);	
}

- (void)webView: (WebView *)webView decidePolicyForNavigationAction: (NSDictionary *)actionInformation request: (NSURLRequest *)request frame: (WebFrame *)frame
				decisionListener: (id<WebPolicyDecisionListener>)listener 
{
	NSString *urlString = [[actionInformation objectForKey:@"WebActionOriginalURLKey"] absoluteString];

	NSLog(@"webView:decidePolicyForNavigationAction: \rurl=%@", urlString);
	
	if ([urlString rangeOfString:@"oauth_verifier"].location != NSNotFound)
	{		
		NSString *oauthToken = nil;
		NSString *oauthVerifier = nil;
		
		NSScanner *scanner = [NSScanner scannerWithString: urlString];
		
		[scanner scanUpToString:@"oauth_token=" intoString: nil];
		[scanner scanString: @"oauth_token=" intoString:nil];
		[scanner scanUpToString:@"&" intoString: &oauthToken];
		
		[scanner scanUpToString:@"oauth_verifier=" intoString: nil];
		[scanner scanString: @"oauth_verifier=" intoString:nil];
		oauthVerifier = [urlString substringFromIndex:[scanner scanLocation]];
		
		NSLog(@"oauthToken = '%@'",oauthToken);
		NSLog(@"oauthVerifier = '%@'", oauthVerifier);
		self.requestToken.secret = oauthVerifier;
		
		[listener ignore];
		[NSApp endSheet:webSheet returnCode: 0];
		[self getAccessToken];
	}
	else
		[listener use];
}




@end
