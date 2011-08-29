//
//  StokerTwitter.m
//  StokerX
//
//  Created by Joe Keenan on 8/13/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerXTwitter.h"

@implementation StokerXTwitter

static NSString *const kTwitterKeychainItemName = @"StokerX: Twitter";
static NSString *const kTwitterServiceName = @"Twitter";

@synthesize myAuth;

- (void)dealloc 
{
	[myAuth release];
	[super dealloc];
}

- (void) awakeFromNib
{	
//	Enabling this causes Fetcher logs to be written to the desktop!
//	[GTMHTTPFetcher setLoggingEnabled:YES];

	// Just in case the authentication background processes fail
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(signInNetworkLost:)
												 name: kGTMOAuthNetworkLost
											   object: nil];
	
	// save the authentication object, which holds the auth tokens
	
	GTMOAuthAuthentication *auth = [self authForTwitter];	
	self.myAuth = auth;
	
	[GTMOAuthWindowController authorizeFromKeychainForName: kTwitterKeychainItemName
											authentication: auth];
	[self updateUI];
}

- (GTMOAuthAuthentication *) authForTwitter 
{
//	NSLog(@"StokerXTwitter authForTwitter");

	NSString *myConsumerKey = kOAuthConsumerKey;
	NSString *myConsumerSecret = kOAuthConsumerSecret;
	
	if ([myConsumerKey length] == 0 || [myConsumerSecret length] == 0) 
	{
		NSLog(@"StokerXTwitter Needs A Twitter Consumer Key And Secret");
		return nil;
	}
	
	GTMOAuthAuthentication *auth = [[[GTMOAuthAuthentication alloc] initWithSignatureMethod: kGTMOAuthSignatureMethodHMAC_SHA1
																				consumerKey: myConsumerKey
																				 privateKey: myConsumerSecret] autorelease];
	
	// setting the service name lets us inspect the auth object later to know what service it is for
	[auth setServiceProvider: kTwitterServiceName];
	
	return auth;
}

// This method kicks off the Twitter authentication process.  Everything else happens in the GTM-OAuth clases until the callback.

- (void) signInToTwitter 
{	
	NSLog(@"StokerXTwitter signInToTwitter");

	[self signOut];
	
	NSURL *requestURL =   [NSURL URLWithString: @"http://twitter.com/oauth/request_token"];
	NSURL *accessURL =    [NSURL URLWithString: @"http://twitter.com/oauth/access_token"];
	NSURL *authorizeURL = [NSURL URLWithString: @"http://twitter.com/oauth/authorize"];
	NSString *scope = @"https://api.twitter.com/";
	
	GTMOAuthAuthentication *auth = [self authForTwitter];
	if (!auth) 
		return;
	
	// set the callback URL to which the site should redirect, and for which
	// the OAuth controller should look to determine when sign-in has
	// finished or been canceled
	//
	// This URL does not need to be for an actual web page
	
	[auth setCallback:@"http://www.flyingdiver.com/Stoker/OAuth-Twitter.php"];
	
	GTMOAuthWindowController *windowController =
	[[[GTMOAuthWindowController alloc] initWithScope: scope
                                            language: nil
                                     requestTokenURL: requestURL
                                   authorizeTokenURL: authorizeURL
                                      accessTokenURL: accessURL
                                      authentication: auth
                                      appServiceName: kTwitterKeychainItemName
                                      resourceBundle: nil] autorelease];
	[windowController signInSheetModalForWindow: [NSApp mainWindow]
									   delegate:self
							   finishedSelector:@selector(windowController:finishedWithAuth:error:)];
	[self updateUI];
}

// This is the final callback from signInToTwitter.

- (void) windowController: (GTMOAuthWindowController *)windowController
         finishedWithAuth: (GTMOAuthAuthentication *)auth
                    error: (NSError *)error 
{
	if (error) 
	{
		// Authentication failed (perhaps the user denied access, or closed the window before granting access)

		self.myAuth = nil;

		NSData *responseData = [[error userInfo] objectForKey: @"data"];	// kGTMHTTPFetcherStatusDataKey
		if ([responseData length] > 0) 
		{
			// show the body of the server's authentication failure response
			NSString *str = [[[NSString alloc] initWithData: responseData
												   encoding: NSUTF8StringEncoding] autorelease];
			NSLog(@"StokerXTwitter Authentication error: %@", str);
		}
	} 
	else 
	{			
		// Authentication successful.  Do another Twitter request to confirm and get the user info (not really needed at this time)
		
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


- (BOOL)isSignedIn {
	BOOL isSignedIn = [myAuth canAuthorize];
	return isSignedIn;
}

- (void)signOut 
{	
	NSLog(@"StokerXTwitter signOut");

	// remove the stored Twitter authentication from the keychain
	[GTMOAuthWindowController removeParamsFromKeychainForName:kTwitterKeychainItemName];
	
	// discard our retains authentication object
	self.myAuth = nil;
	
	[self updateUI];
}


- (void)signInNetworkLost:(NSNotification *)note 
{
	NSLog(@"StokerXTwitter signInNetworkLost: %@, %@", [note name], [[note userInfo] objectForKey:kGTMOAuthFetchTypeKey]);

	// the network dropped for 30 seconds
	//
	// we could alert the user and wait for notification that the network has
	// has returned, or just cancel the sign-in sheet, as shown here
	
	GTMOAuthSignIn *signIn = [note object];
	GTMOAuthWindowController *controller = [signIn delegate];
	[controller cancelSigningIn];
}

#pragma mark -
#pragma mark Twitter Menu Handling Methods

- (void) signInOutClicked: (id) sender
{
	if (![self isSignedIn]) 
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

- (BOOL)validateMenuItem:(NSMenuItem *) item 
{
    if ([item action] == @selector(enableTwitter:))
	{
		if ([self isSignedIn])
			return YES;
		else
			return NO;
	}
	else
		return YES;
}
		


- (void) sendTweet: (NSString *) tweet
{	
	if ([self isSignedIn])
	{		
		NSString *trimmedText = [tweet precomposedStringWithCanonicalMapping];
		
		if ([trimmedText length] > MAX_MESSAGE_LENGTH) {
			trimmedText = [trimmedText substringToIndex:MAX_MESSAGE_LENGTH];
		}
		
		NSString *body = [NSString stringWithFormat: @"status=%@", trimmedText];
		
		NSString *urlStr = @"http://api.twitter.com/1/statuses/update.json";
		NSURL *url = [NSURL URLWithString:urlStr];
		
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPMethod:@"POST"]; 
		[request setHTTPBody: [body dataUsingEncoding:NSUTF8StringEncoding]];
		[myAuth authorizeRequest: request];
		
		GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];	
		[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error) 
		 {
			 if (error != nil) 
			 {
				 NSLog(@"StokerXTwitter sendTweet error: %@", error);
			 } 
		 }];
		
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
}

@end
