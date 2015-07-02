//
//  MiniTwitter.m
//
//  Created by Joe Keenan on 8/13/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "MiniTwitter.h"

@implementation MiniTwitter

static NSString *const kTwitterKeychainItemName = @"StokerX: Twitter";
static NSString *const kTwitterServiceName = @"Twitter";

@synthesize myAuth, twitterHandle, twitterUserName, directMessageSinceId, lastError, lastErrorCount;

- (void)dealloc 
{
	[myAuth release];
	[super dealloc];
}

- (void) awakeFromNib
{	
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
	
	if (self.isSignedIn)
	{
		[self getTwitterInfo];
	
		if ([[NSUserDefaults standardUserDefaults] stringForKey: @"DirectMessageSinceId"])
			directMessageSinceId = [[NSUserDefaults standardUserDefaults] stringForKey: @"DirectMessageSinceId"];
		else
			directMessageSinceId = @"0";
		
		// Twitter has a limit of 15 DM queries per 15 minutes (avg 60 sec), so  do them slower than that
		
		[NSTimer scheduledTimerWithTimeInterval: 75 target:self selector:@selector(getDirectMessages:) userInfo: nil repeats:YES];
	}
		
	[self updateUI];
}

- (GTMOAuthAuthentication *) authForTwitter 
{
	NSString *myConsumerKey = kOAuthConsumerKey;
	NSString *myConsumerSecret = kOAuthConsumerSecret;
		
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
	[self signOut];			// make sure we're not already signed in
	
	NSURL *requestURL =   [NSURL URLWithString: @"https://twitter.com/oauth/request_token"];
	NSURL *accessURL =    [NSURL URLWithString: @"https://twitter.com/oauth/access_token"];
	NSURL *authorizeURL = [NSURL URLWithString: @"https://twitter.com/oauth/authorize"];
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
			NSLog(@"MiniTwitter Authentication error: %@", str);
		}
	} 
	else 
	{			
		// Authentication successful.  Do another Twitter request to confirm and get the user info (not really needed at this time)
		
		self.myAuth = auth;
		[self getTwitterInfo];
	}
	
	[self updateUI];
}

- (void) getTwitterInfo
{
	NSString *query = [@"https://api.twitter.com/1.1/account/verify_credentials.json" stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString: query]];
	[myAuth authorizeRequest: request];
	GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];	
	[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error) 
	 {
		 if (error != nil) 
		 {
			 [self reportError: error fromQuery: query];
		 }
		 else 
		 {
			 NSDictionary *results = [[[[NSString alloc] initWithData: retrievedData encoding:NSUTF8StringEncoding] autorelease] JSONValue];
			 self.twitterUserName = [results objectForKey: @"name"];
			 self.twitterHandle   = [results objectForKey: @"screen_name"];
			 NSLog(@"MiniTwitter Verification Successful for %@ (@%@)", twitterUserName, twitterHandle);
		 }
		 [self updateUI];
	 }];
}

- (void)updateUI 
{	
	// update the menu items to reflect the authorized state
	
	if ([self isSignedIn]) 
	{				
		[authorizeTwitterMenuItem setTitle: [NSString stringWithFormat: @"Logout @%@ from Twitter", twitterHandle]];
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
		[authorizeTwitterMenuItem setTitle: @"Login to Twitter"];
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
	// remove the stored Twitter authentication from the keychain
	[GTMOAuthWindowController removeParamsFromKeychainForName:kTwitterKeychainItemName];
	
	// discard our retains authentication object
	self.myAuth = nil;
	
	[self updateUI];
}


- (void)signInNetworkLost:(NSNotification *)note 
{
	NSLog(@"MiniTwitter signInNetworkLost: %@, %@", [note name], [[note userInfo] objectForKey:kGTMOAuthFetchTypeKey]);

	// the network dropped for 30 seconds
	//
	// we could alert the user and wait for notification that the network has
	// has returned, or just cancel the sign-in sheet, as shown here
	
	GTMOAuthSignIn *signIn = [note object];
	GTMOAuthWindowController *controller = (GTMOAuthWindowController *) [signIn delegate];
	[controller cancelSigningIn];
}

#pragma mark -
#pragma mark Twitter Menu Handling Methods

- (void) signInOutClicked: (id) sender
{
	if (![self isSignedIn]) 
	{
		[self signInToTwitter];
	} 
	else 
	{
		[self signOut];
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
		NSLog(@"MiniTwitter enableTwitter: unknown state");
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
		
		NSString *encodedText = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) trimmedText, NULL,(CFStringRef) @"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
		NSString *body = [NSString stringWithFormat: @"status=%@", encodedText];
		[encodedText release];
		
		NSString *query = [@"https://api.twitter.com/1.1/statuses/update.json" stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:query]];
		
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody: [body dataUsingEncoding:NSUTF8StringEncoding]];
		[myAuth authorizeRequest: request];
		
		GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];
		[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error)
		 {
			 if (error != nil)
			 {
				 [self reportError: error fromQuery: query];
			 }
		 }];
		
	}
}

- (void) getDirectMessages:(NSTimer *) theTimer
{
	NSString *query = [[NSString stringWithFormat: @"https://api.twitter.com/1.1/direct_messages.json?since_id=%@", self.directMessageSinceId]
					   stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString: query]];
	
	[myAuth authorizeRequest: request];
	
	GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];
	[myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error)
	 {
		 if (error != nil)
		 {
			 [self reportError: error fromQuery: query];
		 }
		 else
		 {
			 NSArray *results = [[[[NSString alloc] initWithData: retrievedData encoding:NSUTF8StringEncoding] autorelease] JSONValue];
			 for (int msgNum = [results count] - 1; msgNum >= 0; msgNum--)
			 {
				 self.directMessageSinceId = [[results objectAtIndex: msgNum] objectForKey: @"id_str"];
				 [[NSUserDefaults standardUserDefaults] setObject: self.directMessageSinceId forKey: @"DirectMessageSinceId"];
				 				 				 
				 NSNumber *senderID = [[results objectAtIndex: msgNum] objectForKey: @"sender_id"];
				 NSString *message = [[results objectAtIndex: msgNum] objectForKey: @"text"];
				 
				 // Process message, and acknowledge it to sender
				 [[NSNotificationCenter defaultCenter] postNotificationName: MiniTwitter_DirectMessage object: message];
				 
				 NSString *replyMessage = [NSString stringWithFormat: @"Message received: \"%@\".", message];
				 NSString *encodedText = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) replyMessage, NULL,(CFStringRef) @"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
				 NSString *body = [NSString stringWithFormat: @"text=%@&user_id=%@", encodedText, senderID];
				 [encodedText release];
				 
				 NSString *query = [@"https://api.twitter.com/1.1/direct_messages/new.json" stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
				 NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:query]];
				 
				 [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
				 [request setHTTPMethod:@"POST"];
				 [request setHTTPBody: [body dataUsingEncoding:NSUTF8StringEncoding]];
				 [myAuth authorizeRequest: request];
				 
				 GTMHTTPFetcher* myFetcher = [GTMHTTPFetcher fetcherWithRequest:request];
				 [myFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error)
				  {
					  if (error != nil)
					  {
						  [self reportError: error fromQuery: query];
					  }
				  }];
				 
				 return;
			 }
		 }
	 }];
}

- (void) reportError: (NSError *) error fromQuery: (NSString *) query
{
	if ((error.code == self.lastError.code) && ([error.domain isEqualTo: self.lastError.domain]) && ([error.userInfo isEqualTo: self.lastError.userInfo]))
	{
		self.lastErrorCount++;
	}
	else
	{
		if (self.lastErrorCount > 0)
		{
			NSLog(@"MiniTwitter API error: last error repeated %d times", lastErrorCount);
			self.lastErrorCount = 0;
		}
		self.lastError = error;
		NSDictionary *results = [[[[NSString alloc] initWithData: [error.userInfo objectForKey: @"data"] encoding:NSUTF8StringEncoding] autorelease] JSONValue];
		NSDictionary *errorDict = [[results objectForKey: @"errors"] objectAtIndex: 0];
		NSLog(@"MiniTwitter API error: code = %ld, domain = %@\n\tAPI call = %@\n\tAPI Error code = %@, API Error Message = \"%@\"\n",
			  (long)error.code, error.domain, query, [errorDict objectForKey: @"code"], [errorDict objectForKey: @"message"]);
	}

}
@end
