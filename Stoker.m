//
//  Stoker.m
//  StokerX
//
//  Created by Joe Keenan on 10/27/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "Stoker.h"


@implementation Stoker

@synthesize delegate, stokerVersion, jsonTimer, jsonConnection, jsonRequest, jsonData, postConnection, ipAddress, httpPort, logging;
@synthesize useTelnet, stokerAvailable, telnetActive, mySendExpect, lastTemp, lidOffHold, blowerControlSensor, lastTempTarget;

- (void)dealloc
{	
	if (socket)
    {
        [socket disconnect];
        [socket release];
	}
    [super dealloc];
}

// convenience method for sending status updates to the delegate
- (void) sendStatusUpdate: (NSString *) status
{
	if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:statusUpdate:)]) {
		[[self delegate] stoker: self statusUpdate: status];
	}
}

- (void)connectToIPAddress: (NSString *) ip andPort: (NSString *) port
{	    
	self.ipAddress = ip;
	self.httpPort = port;
	
	// build the JSON data request once, and save it
	
	self.jsonRequest = [[[NSURLRequest alloc] initWithURL: [NSURL URLWithString: [NSString stringWithFormat: @"http://%@:%@/stoker.json?version=true", ipAddress, httpPort]]] autorelease];
	
	[self sendStatusUpdate: [NSString stringWithFormat: @"Attempting HTTP connection to %@:%@", ipAddress, httpPort]];

	// try the JSON request
	[self getStokerJSON: nil];
	
}
- (void) startLogging
{	
	self.logging = TRUE;
	
	if (useTelnet)
	{
		[self startTelnetCapture];
	}
	else 				// for JSON mode, the timer requests the data, and graphs are updated when data is received
	{
		self.jsonTimer = [NSTimer scheduledTimerWithTimeInterval: STOKER_QUERY_INTERVAL target:self selector:@selector(getStokerJSON:) userInfo: nil repeats:YES];
		
		[self getStokerJSON: nil];		// do it once now to get things started
	}
}		
	
- (void) stopLogging
{
	self.logging = FALSE;

	if (useTelnet)
	{
		[self stopTelnetCapture];
	}
    else
    {
        [jsonTimer invalidate];
        jsonTimer = nil;
		[self sendStatusUpdate: @"HTTP Logging stopped"];
    }
}


#pragma mark -
#pragma mark JSON Data Capture Methods

//  start a JSON (HTTP) data request from the Stoker.  Can be invoked directly or via a timer.

- (void) getStokerJSON:(NSTimer *) theTimer
{	
	NSString *requestString =  [NSString stringWithFormat: @"http://%@:%@/stoker.json?version=true", ipAddress, httpPort];
	
	NSURL *url = [NSURL URLWithString: requestString];		
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	GTMHTTPFetcher* jsonFetcher = [GTMHTTPFetcher fetcherWithRequest:request];	
	[jsonFetcher beginFetchWithDelegate:self didFinishSelector:@selector(jsonFetcher:finishedWithData:error:)];
}

- (void)jsonFetcher:(GTMHTTPFetcher *)fetcher finishedWithData:(NSData *)retrievedData error:(NSError *)error;
{
	if (error != nil) 
	{
		NSLog(@"getStokerJSON GTMHTTPFetcher error: %@", error);
		return;
	} 
	
	if (!stokerAvailable)       // don't know if we have a connection yet
    {
        stokerAvailable = TRUE;		// worked!
        [self sendStatusUpdate: @"HTTP Connection successful"];
    }
	
	NSDictionary *results = [[[[NSString alloc] initWithData: retrievedData encoding:NSUTF8StringEncoding] autorelease] JSONValue];

	if (!results)
	{
		NSLog(@"getStokerJSON JSON Parse error");
		return;		// bad JSON parse, skip this one
	}
	
	// now that we have at least set of data from the Stoker, get the data structures set up

	if (nil == sensorDict)
	{		
		self.stokerVersion = [[results objectForKey:@"stoker"] objectForKey:@"version"];
		[self sensorSetup: results];
	}

	// If logging active, read the sensor values from the response and send to the Delegate

	if (!logging)
		return;

	NSArray *sensors = [[results objectForKey:@"stoker"] objectForKey:@"sensors"];
	if (sensors != (NSArray *) [NSNull null])
	{
		for (NSDictionary *sensor in sensors)
		{
			if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:updateSensorTemp:forSensor:)]) {
				[[self delegate] stoker: self updateSensorTemp: [sensor objectForKey:@"tc"] forSensor: [sensor objectForKey:@"id"]];
			}
			
			if (([sensor objectForKey:@"blower"] != [NSNull null]) && lidDetectionEnabled)		// only check for lid off on control blower
			{
				[self checkLidOffSensor: [sensor objectForKey:@"id"] withTemp: [sensor objectForKey:@"tc"]];
			}
		}
	}	

	NSArray *blowers = [[results objectForKey:@"stoker"] objectForKey:@"blowers"];
	if (blowers != (NSArray *) [NSNull null])
	{
		for (NSDictionary *blower in blowers)
		{
			if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:updateBlowerState:forBlower:)]) {
				[[self delegate] stoker: self updateBlowerState: [[blower objectForKey:@"on"] intValue] forBlower: [blower objectForKey:@"id"]];
			}
		}
	}
}

- (void)sensorSetup: (NSDictionary *) jsonResults
{		    
	blowerArray = [[NSMutableArray alloc] init];	
	blowerDict  = [[NSMutableDictionary dictionaryWithCapacity:3] retain];
    
	sensorArray = [[NSMutableArray alloc] init];	
	sensorDict = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
	
	NSArray *blowers = [[jsonResults objectForKey:@"stoker"] objectForKey:@"blowers"];	
    
	if (blowers != (NSArray *) [NSNull null])
	{
		for (NSDictionary *blower in blowers)
		{			
			StokerBlower *theBlower = [[StokerBlower alloc] init];
			theBlower.blowerName 	= [blower objectForKey:@"name"];
			theBlower.deviceID   	= [blower objectForKey:@"id"];
			theBlower.state      	= [[blower objectForKey:@"on"] intValue];
			theBlower.sensor		= nil;
			
			[blowerDict setObject: theBlower forKey: theBlower.deviceID];
			[blowerArray addObject: theBlower];
			[theBlower release];
		}
	}
	
	NSArray *sensors = [[jsonResults objectForKey:@"stoker"] objectForKey:@"sensors"];
	
	if (sensors != (NSArray *) [NSNull null])
	{
		for (NSDictionary *sensor in sensors)
		{			
			StokerSensor *theSensor	= [[StokerSensor alloc] init];
			theSensor.sensorName	= [sensor objectForKey:@"name"];
			theSensor.deviceID 		= [sensor objectForKey:@"id"];
			theSensor.blowerID 		= [sensor objectForKey:@"blower"];
			theSensor.tempTarget 	= [sensor objectForKey:@"ta"];
			theSensor.tempCurrent 	= [sensor objectForKey:@"tc"];
			
			// Look for a matching BlowerID for this sensor
			if ([blowerDict count] > 0)
			{
				for (NSString *blowerKey in blowerDict)
				{
					StokerBlower *blower = [blowerDict objectForKey: blowerKey];
					if ([theSensor.blowerID isEqual: blower.deviceID])
					{
						theSensor.blower = blower;
						blower.sensor = theSensor;
					}
				}
			}
			[sensorDict setObject: theSensor forKey: theSensor.deviceID];
			[theSensor release];
		}
	}
	
	// also need to set up the sensor array, ordering control (pit) sensors first, then food sensors
	
	for (NSString *sensorKey in sensorDict)	// look for control sensors first
	{
		StokerSensor *theSensor = [sensorDict objectForKey: sensorKey]; 
		if (theSensor.blower != nil)
		{
			blowerControlSensor = [sensorArray count];		// the index for the one being added is the current count
			[sensorArray addObject:theSensor];
		}
	}
	
	for (NSString *sensorKey in sensorDict)	// now add the others
	{
		StokerSensor *theSensor = [sensorDict objectForKey: sensorKey];
		if (theSensor.blower == nil)
		{
			[sensorArray addObject:theSensor];
		}
	}
	
	if([self delegate] && [[self delegate] respondsToSelector:@selector(stokerHasCompletedSetup:)]) 
	{
		[[self delegate] stokerHasCompletedSetup: self];
	}           
}


#pragma mark -
#pragma mark Telnet Data Capture Methods

- (void) startTelnetCapture 
{		
	NSLog(@"Stoker: startTelnetCapture");

	NSError *err;
	connectionReady = NO;
		
	NSArray *sequence = [NSArray arrayWithObjects: 
						   [NSDictionary dictionaryWithObjectsAndKeys: @"root\r",   @"send", @":", @"expect", nil], 
						   [NSDictionary dictionaryWithObjectsAndKeys: @"tini\r",   @"send", @">", @"expect", nil],
						   [NSDictionary dictionaryWithObjectsAndKeys: @"bbq -k\r", @"send", @">", @"expect", nil],
						   [NSDictionary dictionaryWithObjectsAndKeys: @"gc\r",     @"send", @">", @"expect", nil],
						   [NSDictionary dictionaryWithObjectsAndKeys: @"bbq -t\r", @"send", @">", @"expect", nil],
						nil];

	self.mySendExpect = [[[SendExpect alloc] initWithSequence: sequence] autorelease];
	self.mySendExpect.name = @"Telnet Output Start";
	self.mySendExpect.delegate = self;
	
	int port = 23;	// telnet port
	
	// Create socket.
	socket = [[AsyncSocket alloc] initWithDelegate:self];
	
	// Set up stdin for non-blocking.
	if (fcntl (STDIN_FILENO, F_SETFL, O_NONBLOCK) == -1)
	{
		NSLog (@"Stoker: Can't make STDIN non-blocking.");
		exit(1);
	}
	
	if (![socket connectToHost:ipAddress onPort:port error:&err])
	{
		NSLog (@"Stoker: Couldn't connect to %@:%u (%@).", ipAddress, port, err);
		return;
	}

	telnetActive = YES;
	if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:telnetActive:)]) {
		[[self delegate] stoker: self telnetActive: YES];
	}
}

- (void) stopTelnetCapture 
{
	[self sendStatusUpdate: @"Stopping telnet connection"];

	NSArray *sequence = [NSArray arrayWithObjects: 
						  [NSDictionary dictionaryWithObjectsAndKeys: @"bbq -k\r", @"send", @">", @"expect", nil],
						  [NSDictionary dictionaryWithObjectsAndKeys: @"gc\r",     @"send", @">", @"expect", nil],
						  [NSDictionary dictionaryWithObjectsAndKeys: @"bbq\r",    @"send", @">", @"expect", nil],
						  [NSDictionary dictionaryWithObjectsAndKeys: @"exit\r",   @"send", @" ", @"expect", nil],
					   nil];
	
	self.mySendExpect = [[[SendExpect alloc] initWithSequence: sequence] autorelease];
	self.mySendExpect.name = @"Telnet Output Stop";
	self.mySendExpect.delegate = self;
}


- (void) parseTelnetOutput: (NSString *) stokerOutput 
{		
	if ([stokerOutput rangeOfString:@":"].location != NSNotFound)		// must have : after device ID or it's garbage
	{ 			  
		NSString *deviceID = nil;
		NSString *tempUser = nil;
		NSString *blower = nil;
		
		NSScanner *scanner = [NSScanner scannerWithString:stokerOutput];
		
		// first string (up to colon) is the Device ID
		
		[scanner scanUpToString:@":" intoString:&deviceID];
		
		if ([deviceID length] != 16)	// bad deviceID
			return;

		[scanner scanUpToString:@" " intoString:nil];					// skip past the colon
		
		for (int i = 0; i < 7; i++)										// skip past the v0-v6 debug variables
		{
			[scanner scanUpToString:@" " intoString:nil];
		}
		
		[scanner scanUpToString:@" " intoString:nil];					// skip past the tempC, get the user temp
		[scanner scanUpToString:@" " intoString:&tempUser];
		
		if ([stokerOutput rangeOfString:@"PID"].location != NSNotFound)	// if there's a PID string, then there's blower data
		{
			[scanner scanUpToString:@"tgt:" intoString:nil];			// skip past the tgt:
			[scanner scanString:@"tgt:" intoString:nil];
			[scanner scanUpToString:@" " intoString:nil];				// skip the value

			[scanner scanUpToString:@"blwr:" intoString:nil];			// skip past the blwr:
			[scanner scanString:@"blwr:" intoString:nil];
			[scanner scanUpToString:@" " intoString:&blower];			// get the value
		}		
		
        if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:updateSensorTemp:forSensor:)]) {
            [[self delegate] stoker: self updateSensorTemp: [NSNumber numberWithDouble: [tempUser doubleValue]] forSensor: deviceID];
        }
		
		StokerSensor *theSensor;
		StokerBlower *theBlower;
		
		if ((theSensor = [sensorDict objectForKey: deviceID]))
		{
			theSensor.tempCurrent = [NSNumber numberWithDouble: [tempUser doubleValue]];
			
			if (blower)
			{
				theBlower = [blowerDict objectForKey: [theSensor blowerID]];

				if ([blower compare: @"on" options: NSCaseInsensitiveSearch range: NSMakeRange(0,2)] == NSOrderedSame)
				{
					theBlower.state = TRUE;
				}
				else
				{
					theBlower.state = FALSE;
				}
                
                if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:updateBlowerState:forBlower:)]) {
                    [[self delegate] stoker: self updateBlowerState: theBlower.state forBlower: theBlower.deviceID];
                }           

				if (lidDetectionEnabled)
				{
					[self checkLidOffSensor: theSensor.deviceID withTemp: theSensor.tempCurrent];		// this sensor has the blower, so it's the right one for lid detection	
				}
				
			}
		}
	}
}


#pragma mark -
#pragma mark AsyncSocketDelegate methods


-(void) onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
{
//	NSLog (@"Stoker: onSocket:didConnectToHost: %@:%u.", host, port);
	
	connectionReady = YES;	// can't use the controller until this is set
	
	// on first connection, we're looking for a "login:" prompt
	
	NSData *colon = [@":" dataUsingEncoding:NSASCIIStringEncoding];
	[socket readDataToData:colon withTimeout:-1 tag: 0];
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if (err)
	{
		NSLog (@"Stoker: onSocket:willDisconnectWithError: %@", err);    
	}
}

-(void) onSocketDidDisconnect:(AsyncSocket *)sock
{
//	NSLog (@"Stoker: onSocketDidDisconnect:");

	connectionReady = NO;
	
	if (telnetActive)
	{
		telnetActive = NO;	
		if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:telnetActive:)]) {
			[[self delegate] stoker: self telnetActive: NO];
		}
	}		
}

-(void) onSocket:(AsyncSocket *)sock didReadData:(NSData*) sockData withTag:(long)tag
{
//	NSLog (@"Stoker: onSocket: didReadData:");

	NSData *data;
		
	if (mySendExpect)
	{
		NSString *send = [mySendExpect nextSend];
				
		data  =  [send dataUsingEncoding:NSASCIIStringEncoding];
		[socket writeData: data withTimeout:-1 tag: 1];
				
		NSString *expect = [mySendExpect nextExpect];
	
		data = [expect dataUsingEncoding:NSASCIIStringEncoding];
		[socket readDataToData: data withTimeout:-1 tag: 0];
				
		if (mySendExpect.completed)	// all done
		{			
			[mySendExpect release];
			mySendExpect = nil;
		}
		return;
	}

	NSString *stokerReply = [[NSString alloc] initWithData: sockData encoding:NSASCIIStringEncoding];
	
	[self parseTelnetOutput: stokerReply];
	
	[stokerReply release];
	
	// from now on, we're looking for "\n"  (full lines of output)

	NSData *newline = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];
	[socket readDataToData:newline withTimeout:-1 tag: 0];
}


#pragma mark -
#pragma mark Data Access Methods

- (int) numberOfSensors
{
	return [sensorDict count];
}

- (int) numberOfBlowers
{
	return [blowerDict count];
}

- (NSString *) typeForSensor: (int) sensorNo
{
	if ([(StokerSensor *)[sensorArray objectAtIndex: sensorNo] blowerID] != (NSString *) [NSNull null])
		return @"Control";
	else
		return @"Monitor";
	
}

- (NSString *) nameForSensor: (int) sensorNo
{
	return [(StokerSensor *)[sensorArray objectAtIndex: sensorNo] sensorName];
}

- (NSString *) idForSensor: (int) sensorNo
{
	return [(StokerSensor *)[sensorArray objectAtIndex: sensorNo] deviceID];
}

- (NSNumber *) tempForSensor: (int) sensorNo
{
	return [(StokerSensor *)[sensorArray objectAtIndex: sensorNo] tempCurrent];
}

- (NSNumber *) targetForSensor: (int) sensorNo
{
	return [(StokerSensor *)[sensorArray objectAtIndex: sensorNo] tempTarget];
}

- (NSString *) blowerForSensor: (int) sensorNo
{
	if ([(StokerSensor *)[sensorArray objectAtIndex: sensorNo] blower] != nil)
		return [[(StokerSensor *)[sensorArray objectAtIndex: sensorNo] blower] state] ? @"On" : @"Off";
	else
		return nil;
}

- (NSString *) nameForBlower: (int) blowerNo
{
	return [(StokerBlower *)[blowerArray objectAtIndex: blowerNo] blowerName];
}

- (NSString *) idForBlower: (int) blowerNo
{
	return [(StokerBlower *)[blowerArray objectAtIndex: blowerNo] deviceID];
}

#pragma mark -
#pragma mark Stoker Update Methods

- (void) setName: (NSString *) name forSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	
	theSensor.sensorName = name;

	NSLog(@"Stoker: setName: %@ forSensor: %@ (%@)", name, [theSensor deviceID],[theSensor sensorName]);
	
	NSString *post = [NSString stringWithFormat:@"na%@=%@", theSensor.deviceID, [self urlEncodeValue: [theSensor sensorName]]];
	
	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
	[request setURL:[NSURL URLWithString: [NSString stringWithFormat: @"http://%@:%@/stoker.Post_Handler", ipAddress, httpPort]]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	
	postConnection = [[NSURLConnection alloc] initWithRequest: request delegate:self];
}

- (void) setTarget: (NSNumber *) target forSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];

	theSensor.tempTarget = target;
			
	NSLog(@"Stoker: setTarget: %@ forSensor: %@ (%@)", target, theSensor.deviceID, [theSensor sensorName]);

	NSString *post = [NSString stringWithFormat:@"ta%@=%@", theSensor.deviceID, [self urlEncodeValue: [target stringValue]]];
	
	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
	[request setURL:[NSURL URLWithString: [NSString stringWithFormat: @"http://%@:%@/stoker.Post_Handler", ipAddress, httpPort]]];
	[request setHTTPMethod:@"POST"];
	[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPBody:postData];
	
	postConnection = [[NSURLConnection alloc] initWithRequest: request delegate:self];
}

- (NSString *)urlEncodeValue:(NSString *)str
{
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);
	return [result autorelease];
}


#pragma mark -
#pragma mark Lid Detection Methods


- (void) enableLidDetection: (Boolean) enabled withDrop: (double) drop andWait: (double) wait
{	
	if (enabled)
	{
		lidDetectionEnabled = TRUE;
		lidOffDrop = drop;
		lidOffWait = wait;
	}
	else {
		lidDetectionEnabled = FALSE;
	}
}

- (void) checkLidOffSensor:(NSString *) sensorID withTemp: (NSNumber *) currTemp
{
	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

	if (!lastTemp)		// first time, get a last temp to use going forward
	{
		self.lastTemp = currTemp;
		lastTempTime = currentTime;
	}
	
	NSTimeInterval interval = currentTime - lastTempTime;
	
	if (!lidOffHold &&  (interval > 15.0))				// not on hold, looking for a drop, check every 15 sec
	{
		double tempDrop = [lastTemp doubleValue] - [currTemp doubleValue];
	
		if (tempDrop > lidOffDrop)
		{
 			NSLog(@"checkLidOffSensor:withTemp: holding - change = %f, interval = %f ", tempDrop, interval);
			[self sendStatusUpdate: @"Holding Stoker (Lid Off)"];
			lidOffHold = TRUE;
			
			// set the Stoker's target way down to keep the blower off, but don't reset the internal data so we can restore
			
			StokerSensor *theSensor = [sensorArray objectAtIndex: blowerControlSensor];

			self.lastTempTarget = [theSensor tempTarget];
			[self setTarget: [NSNumber numberWithFloat: 100.0] forSensor: blowerControlSensor];
			theSensor.tempTarget = lastTempTarget;
					
		}		

		lastTempTime = currentTime;
	}
	else if (lidOffHold && (interval > lidOffWait))		// on hold, waiting for timer
	{
		NSLog(@"checkLidOffSensor:withTemp: hold timer elapsed, restarting");
		[self sendStatusUpdate: @"Enabling Stoker (Lid Off)"];

		lastTempTime = currentTime;
		self.lastTemp = currTemp;
		
		lidOffHold = FALSE;
		
		// restore the Stoker's temp target
		
		[self setTarget: lastTempTarget forSensor: blowerControlSensor];

	}
}

#pragma mark -
#pragma mark SendExpect Delegate Methods

- (void) sendExpectStarted: (SendExpect *) sequence
{
//	NSLog(@"sendExpectStarted: %@", sequence.name);
}

- (void) sendExpectCompleted: (SendExpect *) sequence
{
//	NSLog(@"sendExpectCompleted: %@", sequence.name);
}

- (void) sendExpectFailed: (SendExpect *) sequence withError: (NSString *) error
{
	NSLog(@"sendExpectFailed: %@ withError: %@", sequence.name, error);
	
}

@end

#pragma mark -
#pragma mark Convenience Classes

@implementation StokerBlower

- (NSString *) description
{
	return [NSString stringWithFormat: @"StokerBlower: name = %@, id = %@, state = %d", blowerName, deviceID, state];
}

@synthesize blowerName;
@synthesize deviceID;
@synthesize state;
@synthesize sensor;

@end

@implementation StokerSensor

@synthesize sensorName;
@synthesize deviceID;
@synthesize tempCurrent;
@synthesize tempTarget;
@synthesize blowerID;
@synthesize control;
@synthesize blower;

- (NSString *) description
{
	return [NSString stringWithFormat: @"StokerSensor: name = %@, id = %@, tc = %@, ta = %@, blower = %@", sensorName, deviceID, tempCurrent, tempTarget, blowerID];
}
@end
