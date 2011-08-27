//
//  StokerTwitter.m
//  StokerX
//
//  Created by Joe Keenan on 8/13/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "StokerXTwitter.h"


@interface StokerXTwitter ()

- (void)signInToTwitter;
- (void)signOut;
- (BOOL)isSignedIn;

- (GTMOAuthAuthentication *) authForTwitter;

- (void)windowController:(GTMOAuthWindowController *)windowController
        finishedWithAuth:(GTMOAuthAuthentication *)auth
                   error:(NSError *)error;

- (void)updateUI;
- (void)setAuthentication:(GTMOAuthAuthentication *)auth;
- (void)signInFetchStateChanged:(NSNotification *)note;
- (void)signInNetworkLost:(NSNotification *)note;

- (void)doAnAuthenticatedAPIFetch;

@end


@implementation StokerXTwitter

static NSString *const kTwitterKeychainItemName = @"StokerX: Twitter";
static NSString *const kTwitterServiceName = @"Twitter";

- (void)dealloc 
{
	[mAuth release];
	[super dealloc];
}

- (void) awakeFromNib
{	
	NSLog(@"StokerXTwitter awakeFromNib");
	
	GTMOAuthAuthentication *auth;
    auth = [self authForTwitter];
	
	// save the authentication object, which holds the auth tokens
	[self setAuthentication:auth];
	
	// this is optional:
	//
	// we'll watch for the "hidden" fetches that occur to obtain tokens
	// during authentication, and start and stop our indeterminate progress
	// indicator during the fetches
	//
	// usually, these fetches are very brief
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
		   selector:@selector(signInFetchStateChanged:)
			   name:kGTMOAuthFetchStarted
			 object:nil];
	[nc addObserver:self
		   selector:@selector(signInFetchStateChanged:)
			   name:kGTMOAuthFetchStopped
			 object:nil];
	[nc addObserver:self
		   selector:@selector(signInNetworkLost:)
			   name:kGTMOAuthNetworkLost
			 object:nil];
	
	// check for saved access token from previous authentication

    if (auth) 
	{
		if ([GTMOAuthWindowController authorizeFromKeychainForName:kTwitterKeychainItemName
													authentication:auth]) 
		{
			NSLog(@"StokerXTwitter awakeFromNib: Obtained accessToken from KeyChain");
			
			// set up the menus properly
			
			[authorizeTwitterMenuItem setTitle: @"Deauthorize Twitter"];
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
			NSLog(@"StokerXTwitter awakeFromNib: No accessToken from saved defaults");
			[authorizeTwitterMenuItem setTitle: @"Authorize Twitter"];
			[enableTwitterMenuItem setEnabled: NO];
			[enableTwitterMenuItem setState: NSOffState];
		}
	}
	[self updateUI];
}

- (GTMOAuthAuthentication *)authForTwitter 
{
	NSLog(@"StokerXTwitter authForTwitter");

	NSString *myConsumerKey = kOAuthConsumerKey;
	NSString *myConsumerSecret = kOAuthConsumerSecret;
	
	if ([myConsumerKey length] == 0 || [myConsumerSecret length] == 0) 
	{
		NSLog(@"StokerXTwitter Needs A Twitter Consumer Key And Secret");
		return nil;
	}
	
	GTMOAuthAuthentication *auth = [[[GTMOAuthAuthentication alloc] initWithSignatureMethod:kGTMOAuthSignatureMethodHMAC_SHA1
                                                        consumerKey:myConsumerKey
                                                         privateKey:myConsumerSecret] autorelease];
	
	// setting the service name lets us inspect the auth object later to know what service it is for
	[auth setServiceProvider: kTwitterServiceName];
	
	return auth;
}

- (void)signInToTwitter 
{	
	NSLog(@"StokerXTwitter signInToTwitter");

	[self signOut];
	
	NSURL *requestURL =   [NSURL URLWithString: @"http://twitter.com/oauth/request_token"];
	NSURL *accessURL =    [NSURL URLWithString: @"http://twitter.com/oauth/access_token"];
	NSURL *authorizeURL = [NSURL URLWithString: @"http://twitter.com/oauth/authorize"];
	NSString *scope = @"https://api.twitter.com/";
	
	GTMOAuthAuthentication *auth = [self authForTwitter];
	if (!auth) return;
	
	// set the callback URL to which the site should redirect, and for which
	// the OAuth controller should look to determine when sign-in has
	// finished or been canceled
	//
	// This URL does not need to be for an actual web page
	
	[auth setCallback:@"http://www.flyingdiver.com/Stoker/OAuth-Twitter.php"];
	
	GTMOAuthWindowController *windowController;
	windowController = [[[GTMOAuthWindowController alloc] initWithScope:scope
                                                               language:nil
                                                        requestTokenURL:requestURL
                                                      authorizeTokenURL:authorizeURL
                                                         accessTokenURL:accessURL
                                                         authentication:auth
                                                         appServiceName:kTwitterKeychainItemName
                                                         resourceBundle:nil] autorelease];
	[windowController signInSheetModalForWindow: [NSApp mainWindow]
									   delegate:self
							   finishedSelector:@selector(windowController:finishedWithAuth:error:)];
	[self updateUI];
}

- (void)windowController:(GTMOAuthWindowController *)windowController
        finishedWithAuth:(GTMOAuthAuthentication *)auth
                   error:(NSError *)error 
{
	NSLog(@"StokerXTwitter windowController:finishedWithAuth:error:");

	if (error != nil) 
	{
		// Authentication failed (perhaps the user denied access, or closed the window before granting access)
		
		NSLog(@"Authentication error: %@", error);
		NSData *responseData = [[error userInfo] objectForKey:@"data"]; // kGTMHTTPFetcherStatusDataKey
		if ([responseData length] > 0) 
		{
			// show the body of the server's authentication failure response
			NSString *str = [[[NSString alloc] initWithData:responseData
												   encoding:NSUTF8StringEncoding] autorelease];
			NSLog(@"%@", str);
		}
		[self setAuthentication:nil];
	} 
	else 
	{
		NSLog(@"Authentication succeeded");
				
		// Authentication succeeded
		//
		// At this point, we either use the authentication object to explicitly authorize requests, like
		//
		//   [auth authorizeRequest:myNSURLMutableRequest]
		//
		// or store the authentication object into a Google API service object like
		//
		//   [[self contactService] setAuthorizer:auth];
		
		[self setAuthentication:auth];
		
		// Just to prove we're signed in, we'll attempt an authenticated update for the signed-in user
		
		[self doAnAuthenticatedAPIFetch];

		[self sendTweet:@"GTMOAuth Authentication succeeded"];
	}
	
	[self updateUI];
}

- (void)updateUI 
{	
	// update the text showing the signed-in state and the button title
	
	if ([self isSignedIn]) 
	{
		NSLog(@"StokerXTwitter updateUI - Signed In");
		
		// set up the menus properly
		
		[authorizeTwitterMenuItem setTitle: @"Deauthorize Twitter"];
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
		NSLog(@"StokerXTwitter updateUI - Not Signed In");
				
		[authorizeTwitterMenuItem setTitle: @"Authorize Twitter"];
		[enableTwitterMenuItem setEnabled: NO];
		[enableTwitterMenuItem setState: NSOffState];
	}
}


- (void)setAuthentication:(GTMOAuthAuthentication *)auth 
{
	[mAuth autorelease];
	mAuth = [auth retain];
}

- (void) signInOutClicked: (id) sender
{
	if (![self isSignedIn]) 
	{
		NSLog(@"StokerXTwitter signInOutClicked: Signing In");
		[self signInToTwitter];
	} 
	else 
	{
		NSLog(@"StokerXTwitter signInOutClicked: Signing Out");
		// sign out
		[self signOut];
	}
}

- (BOOL)isSignedIn {
	BOOL isSignedIn = [mAuth canAuthorize];
	return isSignedIn;
}

- (void)signOut 
{	
	// remove the stored Twitter authentication from the keychain
	[GTMOAuthWindowController removeParamsFromKeychainForName:kTwitterKeychainItemName];
	
	// discard our retains authentication object
	[self setAuthentication:nil];
	
	[self updateUI];
}

#pragma mark -

- (void)signInFetchStateChanged:(NSNotification *)note 
{
	NSLog(@"StokerXTwitter signInFetchStateChanged: %@, %@", [note name], [[note userInfo] objectForKey:kGTMOAuthFetchTypeKey]);

	// this just lets the user know something is happening during the sign-in sequence's "invisible" fetches to obtain tokens

	if ([[note name] isEqual:kGTMOAuthFetchStarted]) 
	{
//		[mSpinner startAnimation:self];
	} 
	else 
	{
//		[mSpinner stopAnimation:self];
	}
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
		[request setHTTPMethod:@"POST"]; 
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPBody: [body dataUsingEncoding:NSUTF8StringEncoding]];
		[mAuth authorizeRequest: request];

		GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];				
		
		[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error) 
		{
			if (error != nil) 
			{
				NSLog(@"StokerXTwitter fetch error: %@", error);
			} 
			else 
			{
				NSLog(@"StokerXTwitter sendTweet: Successful - %@", tweet);
			}
		}];

	}
	else
	{
		NSLog(@"StokerXTwitter sendTweet: Failed - not authenticated");
	}
}

- (void)doAnAuthenticatedAPIFetch 
{
	NSURL *url = [NSURL URLWithString: @"http://api.twitter.com/1/statuses/home_timeline.json"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
//	[mAuth authorizeRequest:request];
				
	GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];
	[myFetcher setAuthorizer: mAuth];
	
	[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error) 
	 {
		 if (error != nil) 
		 {
			 NSLog(@"API fetch error: %@", error);
		 } 
		 else 
		 {
			 NSArray *results = [[[[NSString alloc] initWithData: retrievedData encoding: NSUTF8StringEncoding] autorelease] JSONValue];
			 NSLog(@"StokerXTwitter doAnAuthenticatedAPIFetch sucessful for user: %@", [[[results objectAtIndex: 0] objectForKey:@"user"] objectForKey:@"name"]);
		 }
	 }];

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
		


@end
