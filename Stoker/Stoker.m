//
//  Stoker.m
//  StokerX
//
//  Created by Joe Keenan on 10/27/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "Stoker.h"
#import "JSON.h"
#import "GTMHTTPFetcher.h"

@implementation Stoker

@synthesize delegate, stokerVersion, jsonTimer, ipAddress, isLogging, wifiStoker;
@synthesize httpOnlyMode, stokerAvailable, mySendExpect, lastExpect;
@synthesize shutdownCompletionBlock = shutdownCompletionBlock_;
@synthesize connectCompletionBlock  = connectCompletionBlock_;

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

- (BOOL)connectWithCompletionHandler:(void (^)(void))handler 
{	
	self.connectCompletionBlock = handler;
	
	[self sendStatusUpdate: [NSString stringWithFormat: @"Attempting HTTP connection to %@", ipAddress]];
	
	[self getStokerJSON: nil];
	
	return YES;
}

- (BOOL)shutdownWithCompletionHandler:(void (^)(void))handler 
{
	if (telnetActive)		// don't quit with the Stoker in telnet mode
	{
		[self stopTelnetCapture];
	}

	if (telnetActive)		// delayed shutdown, so wait for it
	{
		self.shutdownCompletionBlock = handler;
		return NO;
	}
	if (httpOnlyMode)
	{
		self.shutdownCompletionBlock = nil;
		[jsonTimer invalidate];
		jsonTimer = nil;
	}
	return YES;
}

- (void) startLogging
{	
	self.isLogging = TRUE;
	self.wifiStoker = TRUE;
	
	if (httpOnlyMode)
	{
		[self sendStatusUpdate: @"HTTP Logging started"];
		
		self.jsonTimer = [NSTimer scheduledTimerWithTimeInterval: STOKER_QUERY_INTERVAL target:self selector:@selector(getStokerJSON:) userInfo: nil repeats:YES];
		
		[self getStokerJSON: nil];		// do it once now to get things started
	}
	else 				// for JSON mode, the timer requests the data, and graphs are updated when data is received
	{
		[self sendStatusUpdate: @"Resetting Stoker for Telnet Logging"];
		[self startTelnetCapture];
	}
}		
	
- (void) stopLogging
{
	self.isLogging = FALSE;

	if (httpOnlyMode)
	{
        [jsonTimer invalidate];
        jsonTimer = nil;
		[self sendStatusUpdate: @"HTTP Logging stopped"];
	}
    else
    {
		[self sendStatusUpdate: @"Resetting Stoker to stop Logging"];
		[self stopTelnetCapture];
    }
}

#pragma mark -
#pragma mark JSON Data Capture Methods

//  start a JSON (HTTP) data request from the Stoker.  Can be invoked directly or via a timer.

- (void) getStokerJSON:(NSTimer *) theTimer
{	
	NSString *requestString =  [NSString stringWithFormat: @"http://%@/stoker.json?version=true", ipAddress];
	
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
		[self performSelector:@selector(getStokerJSON:) withObject:self afterDelay: 5.0 ];	// try again almost immediately
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
		[self performSelector:@selector(getStokerJSON:) withObject:self afterDelay: 5.0 ]; // try again almost immediately
		return;	
	}
	
	// now that we have at least set of data from the Stoker, get the data structures set up

	if (nil == sensorDict)
	{		
		[self sensorSetup: results];
	}

	// does the completion block work?
	if (self.connectCompletionBlock)
	{
		self.connectCompletionBlock();
		self.connectCompletionBlock = nil;
	}

	// If logging active, read the sensor values from the response and send to the Delegate

	if (!isLogging)
		return;

	NSArray *sensors = [[results objectForKey:@"stoker"] objectForKey:@"sensors"];
	if (sensors != (NSArray *) [NSNull null])
	{
		for (NSDictionary *sensor in sensors)
		{
			[self updateSensor: [sensor objectForKey:@"id"] withTemp: [[sensor objectForKey:@"tc"] doubleValue] andTarget: [[sensor objectForKey:@"ta"] doubleValue]];
		}
	}	

	NSArray *blowers = [[results objectForKey:@"stoker"] objectForKey:@"blowers"];
	if (blowers != (NSArray *) [NSNull null])
	{
		for (NSDictionary *blower in blowers)
		{			
			[self updateBlower: [blower objectForKey:@"id"] withState: [[blower objectForKey:@"on"] intValue]];
		}
	}
	
	if([self delegate] && [[self delegate] respondsToSelector:@selector(stokerSensorUpdate:)]) 
	{
		[[self delegate] stokerSensorUpdate: self];
	}
}

- (void)sensorSetup: (NSDictionary *) jsonResults
{		    
	self.stokerVersion = [[jsonResults objectForKey:@"stoker"] objectForKey:@"version"];

	blowerArray = [[NSMutableArray alloc] init];	
	blowerDict  = [[NSMutableDictionary dictionaryWithCapacity:3] retain];
    
	sensorArray = [[NSMutableArray alloc] init];	
	sensorDict = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
	
	deviceDict = [[NSMutableDictionary alloc] initWithCapacity: 10];
	
	NSArray *blowers = [[jsonResults objectForKey:@"stoker"] objectForKey:@"blowers"];	
    
	if (blowers != (NSArray *) [NSNull null])
	{
		for (NSDictionary *blower in blowers)
		{			
			StokerBlower *theBlower	= [[StokerBlower alloc] initWithName: [blower objectForKey:@"name"] andID: [blower objectForKey:@"id"]];
			theBlower.state      	= [[blower objectForKey:@"on"] intValue];
			
			[blowerDict setObject: theBlower forKey: theBlower.deviceID];
			[deviceDict setObject: theBlower forKey: theBlower.deviceID];
			[blowerArray addObject: theBlower];
			[theBlower release];
		}
	}
	
	NSArray *sensors = [[jsonResults objectForKey:@"stoker"] objectForKey:@"sensors"];
	
	if (sensors != (NSArray *) [NSNull null])
	{
		for (NSDictionary *sensor in sensors)
		{			
			StokerSensor *theSensor	= [[StokerSensor alloc] initWithName: [sensor objectForKey:@"name"] andID: [sensor objectForKey:@"id"]];
			theSensor.tempTarget 	= [NSNumber numberWithInt: round([[sensor objectForKey:@"ta"] doubleValue])];
			theSensor.tempCurrent 	= [NSNumber numberWithInt: round([[sensor objectForKey:@"tc"] doubleValue])];
			
			// Look for a matching BlowerID for this sensor
			if ([blowerDict count] > 0)
			{
				for (StokerBlower *blower in blowerArray)
				{
					if ([blower.deviceID isEqual: [sensor objectForKey:@"blower"]])
					{
						theSensor.blower = blower;
						blower.sensor = theSensor;
					
					}
				}
			}
			
			[sensorDict setObject: theSensor forKey: theSensor.deviceID];
			[deviceDict setObject: theSensor forKey: theSensor.deviceID];
			[theSensor release];
		}
	}
	
	// also need to set up the sensor array, ordering control (pit) sensors first, then food sensors
	
	for (NSString *sensorKey in sensorDict)	// look for control sensors first
	{
		StokerSensor *theSensor = [sensorDict objectForKey: sensorKey]; 
		if (theSensor.blower != nil)
		{
			blowerControlSensor = theSensor.deviceID;	
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
	NSString *telnetAddress;
	int telnetPort = 23;

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
		
	// Create socket.
	socketQueue = dispatch_get_main_queue();
	socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue: socketQueue];
	
	NSRange colon = [ipAddress rangeOfString: @":"];
	if (colon.location == NSNotFound)
	{
		telnetAddress = ipAddress;
	}
	else
	{
		telnetAddress = [ipAddress substringToIndex: colon.location];
	}
		
	if (![socket connectToHost:telnetAddress onPort: telnetPort error:&err])
	{
		NSLog (@"Stoker: Couldn't connect to %@:%u (%@).", ipAddress, telnetPort, err);
		return;
	}
}

- (void) stopTelnetCapture 
{
	[self sendStatusUpdate: @"Stopping telnet connection"];

	if (wifiStoker)
	{
		NSLog(@"wifiStoker, using shortcut");
		[socket setDelegate:nil];
		[socket disconnect];
		[socket release];
		
		// if this was a shutdown, finish it up
		if (self.shutdownCompletionBlock)
		{
			self.shutdownCompletionBlock();
			self.shutdownCompletionBlock = nil;
		}
		
		connectionReady = NO;
		telnetActive = NO;
		
		[self sendStatusUpdate: @"Telnet connection terminated"];
		
		return;
	}
	
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
	static double lastUpdate = 0;
		
	if ([stokerOutput rangeOfString:@":"].location != NSNotFound)		// must have : after device ID or it's garbage
	{ 			  
		NSString *deviceID = nil;
		NSString *currentTemp = nil;
		NSString *currentTarget = nil;
		NSString *blower = nil;
		
		NSScanner *scanner = [NSScanner scannerWithString:stokerOutput];
		
		// first string (up to colon) is the Device ID
		
		[scanner scanUpToString:@":" intoString: &deviceID];
		
		if ([deviceID length] != 16)	// bad deviceID
			return;

		[scanner scanUpToString: @" " intoString: nil];					// skip past the colon
		
		for (int i = 0; i < 7; i++)										// skip past the v0-v6 debug variables
		{
			[scanner scanUpToString: @" " intoString: nil];
		}
		 
		[scanner scanUpToString:@" " intoString:nil];					// skip past the tempC, get the user temp
		[scanner scanUpToString:@" " intoString: &currentTemp];
		
		if ([stokerOutput rangeOfString:@"PID"].location == NSNotFound)	// No PID, no blower, no target temp
		{
			[self updateSensor: deviceID
					  withTemp: [currentTemp doubleValue]
					 andTarget: [[[sensorDict objectForKey: deviceID] tempTarget] doubleValue]];
		}
		else															// if there's a PID string, then there's blower data
		{
			[scanner scanUpToString:@"tgt:" intoString: nil];			// skip past the tgt:
			[scanner scanString:@"tgt:" intoString: nil];
			[scanner scanUpToString:@" " intoString:  &currentTarget];	// get the current target temp (in Celsius!)

			[scanner scanUpToString:@"blwr:" intoString: nil];			// skip past the blwr:
			[scanner scanString:@"blwr:" intoString: nil];
			[scanner scanUpToString:@" " intoString: &blower];			// get the value

			[self updateSensor: deviceID
					  withTemp: [currentTemp doubleValue]
					 andTarget: (([currentTarget doubleValue]*(9.0/5.0)) + 32.0)];	// target value in telnet output is Celsius

			StokerDevice *theBlower = [[sensorDict objectForKey: deviceID] blower];
			
			Boolean state =	([blower compare: @"on" options: NSCaseInsensitiveSearch range: NSMakeRange(0,2)] == NSOrderedSame) ? TRUE : FALSE;
			[self updateBlower: theBlower.deviceID withState: state];
		}
	}

	double currentTime = [[NSDate date] timeIntervalSinceReferenceDate];
	
	if ((currentTime - lastUpdate) > 5.0)	// limit update rate
	{
		lastUpdate = currentTime;
		
		if([self delegate] && [[self delegate] respondsToSelector:@selector(stokerSensorUpdate:)]) 
		{
			[[self delegate] stokerSensorUpdate: self];
		}    
	}
}


- (void) updateSensor: (NSString *) sensorID withTemp: (double) temp andTarget: (double) target
{	
	NSNumber *currentTime = [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]];
	
	StokerSensor *theSensor = [sensorDict objectForKey: sensorID];
	
	theSensor.tempCurrent = [NSNumber numberWithDouble: round(temp)];
	theSensor.tempTarget  = [NSNumber numberWithDouble: round(target)];
	[theSensor.plotData addObject: [NSArray arrayWithObjects: currentTime, theSensor.tempCurrent, theSensor.tempTarget, nil]];	
}

- (void) updateBlower: (NSString *) blowerID withState: (Boolean) state
{
	NSNumber *currentTime = [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]];
	
	StokerBlower *theBlower = [blowerDict objectForKey: blowerID];
	theBlower.state = state;
	[theBlower.plotData addObject: [NSArray arrayWithObjects: currentTime, [NSNumber numberWithBool: theBlower.state], nil]];				
	if (theBlower.state)
	{
		theBlower.onCount = theBlower.onCount + 1;
	}
}


#pragma mark -
#pragma mark AsyncSocketDelegate methods


-(void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
{	
	telnetActive = YES;
	if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:telnetActive:)]) {
		[[self delegate] stoker: self telnetActive: YES];
	}
	connectionReady = YES;	// can't use the controller until this is set
	
	// on first connection, we're looking for a "login:" prompt
	
	self.lastExpect = @":";
	NSData *colon = [self.lastExpect dataUsingEncoding:NSASCIIStringEncoding];
	[socket readDataToData:colon withTimeout: 10 tag: 0];
}

- (void)socket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if (err)
	{
		NSLog (@"Stoker: socket:willDisconnectWithError: %@", err);    
	}
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
				 elapsed:(NSTimeInterval)elapsed
			   bytesDone:(NSUInteger)length
{
	NSLog(@"Stoker: socket:shouldTimeoutReadWithTag:elapsed: %d bytesDone: %d", (int) elapsed, (int) length);
	
	if (mySendExpect)
	{
		NSString *send = [mySendExpect nextSend];
		self.lastExpect = [mySendExpect nextExpect];
		
		[socket writeData: [send dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1 tag: 0];
		[socket readDataToData: [self.lastExpect dataUsingEncoding:NSASCIIStringEncoding] withTimeout: 10 tag: 0];
		
		if (mySendExpect.completed)	// all done
		{
			[mySendExpect release];
			mySendExpect = nil;
		}
	}
	return 10;
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	connectionReady = NO;
	telnetActive = NO;
	
	if (self.isLogging)
	{
		NSLog (@"Stoker: socketDidDisconnect:withError: %@", err);
		
		[self sendStatusUpdate: @"Stoker connection lost, attempting to reconnect"];
		[self startTelnetCapture];
	}
	else
	{
		NSLog (@"Stoker: telnet session closed");
	}
}


-(void) socket:(GCDAsyncSocket *)sock didReadData:(NSData*) sockData withTag:(long)tag
{		
	NSString *stokerReply = [[NSString alloc] initWithData: sockData encoding:NSASCIIStringEncoding];
//	NSLog (@"socket:didReadData: %@", stokerReply);
	if ([stokerReply rangeOfString:@"Welcome to slush"].location != NSNotFound)		// Gen 1 Stoker
	{
		NSLog (@"Slush Found!");
		wifiStoker = FALSE;
		
	}

	
	if (mySendExpect)
	{
		NSString *send = [mySendExpect nextSend];
		self.lastExpect = [mySendExpect nextExpect];
						
		[socket writeData: [send dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1 tag: 0];
		[socket readDataToData: [self.lastExpect dataUsingEncoding:NSASCIIStringEncoding] withTimeout: 10 tag: 0];
				
		if (mySendExpect.completed)	// all done
		{			
			[mySendExpect release];
			mySendExpect = nil;
		}
		return;
	}
	
	[self parseTelnetOutput: stokerReply];
	
	[stokerReply release];
	
	// from now on, we're looking for "\n"  (full lines of output)

	self.lastExpect = @"\n";
	NSData *newline = [self.lastExpect dataUsingEncoding:NSASCIIStringEncoding];
	[socket readDataToData:newline withTimeout: 10 tag: 0];
}


#pragma mark -
#pragma mark Data Access Methods

- (int) numberOfSensors
{
	return [sensorArray count];
}

- (int) numberOfBlowers
{
	return [blowerArray count];
}

- (NSString *) typeForSensor: (int) sensorNo
{	
	if ([(StokerSensor *)[sensorArray objectAtIndex: sensorNo]  blower])
		return @"Control";
	else
		return @"Monitor";
}

- (NSString *) nameForSensor: (int) sensorNo
{
	return [(StokerSensor *)[sensorArray objectAtIndex: sensorNo] deviceName];
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
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	
	if (theSensor.blower)
	{
		return [(StokerBlower *) [theSensor blower] state] ? @"On" : @"Off";
	}
	else
		return nil;
}

- (NSString *) nameForBlower: (int) blowerNo
{
	return [(StokerBlower *)[blowerArray objectAtIndex: blowerNo] deviceName];
}

- (NSString *) idForBlower: (int) blowerNo
{
	return [(StokerBlower *)[blowerArray objectAtIndex: blowerNo] deviceID];
}

- (NSUInteger) numberOfRecordsForPlot:(id <NSCopying, NSObject>)deviceID
{
	return [[[deviceDict objectForKey: deviceID] plotData] count];
}

- (NSNumber *) plotValueForPlot:(id <NSCopying, NSObject>) deviceID field: (NSUInteger)fieldEnum recordIndex: (NSUInteger)index
{
	return [[[[deviceDict objectForKey: deviceID] plotData] objectAtIndex: index] objectAtIndex: fieldEnum];
}

- (double) totalBlowerRatio
{
	StokerBlower *theBlower = (StokerBlower *) [[deviceDict objectForKey: blowerControlSensor] blower];

	if (!theBlower)
		return 0.0;
	
	return ((double) theBlower.onCount / (double) [theBlower.plotData count]);
}

- (double) recentBlowerRatio: (NSInteger) minutes
{
	StokerBlower *theBlower = (StokerBlower *) [[deviceDict objectForKey: blowerControlSensor] blower];
	
	if (!theBlower)
		return 0.0;

	int onCount = 0, totalCount = 0;
	NSArray *record;
	
	int index = [theBlower.plotData count] - 1;
	
	double interval = minutes * 60.0;		// in seconds 
	double current = [[NSDate date] timeIntervalSinceReferenceDate];
	
	double earliest = current - interval;
	
	while (index >= 0) 
	{
		record = [theBlower.plotData objectAtIndex: index];
		
		double timestamp = [[record objectAtIndex:0] doubleValue];
		
		if (timestamp < earliest)	// earlier than sample period
			break;
		
		totalCount++;
				
		if ([[record objectAtIndex:1] intValue] != 0)
			onCount++;
		
		index--;
	}
	
	if (totalCount > 0)
	{
		return ((float) onCount / (float) totalCount);
	}
	else
	{
		return 0.0;
		
	}
}


#pragma mark -
#pragma mark Stoker Update Methods

- (void) setName: (NSString *) name forSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	theSensor.deviceName = name;	
	
	NSString *requestString =  [NSString stringWithFormat: @"http://%@/stoker.Post_Handler", ipAddress];
	NSString *post = [NSString stringWithFormat:@"na%@=%@", theSensor.deviceID, [self urlEncodeValue: theSensor.deviceName]];

	GTMHTTPFetcher* jsonFetcher = [GTMHTTPFetcher fetcherWithRequest: [NSMutableURLRequest requestWithURL: [NSURL URLWithString: requestString]]];	
	jsonFetcher.postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];	
	[jsonFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error) 
	 {
		 if (error != nil) 
		 {
			 NSLog(@"Stoker setName:forSensor: GTMHTTPFetcher error: %@", error);
		 } 
	 }];
}

- (void) setTarget: (NSNumber *) target forSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	theSensor.tempTarget = target;
			
	NSString *requestString =  [NSString stringWithFormat: @"http://%@/stoker.Post_Handler", ipAddress];
	NSString *post = [NSString stringWithFormat:@"ta%@=%@", theSensor.deviceID, [self urlEncodeValue: [theSensor.tempTarget stringValue]]];
	
	GTMHTTPFetcher* jsonFetcher = [GTMHTTPFetcher fetcherWithRequest: [NSMutableURLRequest requestWithURL: [NSURL URLWithString: requestString]]];	
	jsonFetcher.postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	[jsonFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error) 
	 {
		 if (error != nil) 
		 {
			 NSLog(@"Stoker setTarget:forSensor: GTMHTTPFetcher error: %@", error);
		 } 
	 }];
}

- (void) setTarget: (NSNumber *) target forSensorID: (NSString *) sensorID
{
	StokerSensor *theSensor = [deviceDict objectForKey: sensorID];
	theSensor.tempTarget = target;
	
	NSString *requestString =  [NSString stringWithFormat: @"http://%@/stoker.Post_Handler", ipAddress];
	NSString *post = [NSString stringWithFormat:@"ta%@=%@", theSensor.deviceID, [self urlEncodeValue: [theSensor.tempTarget stringValue]]];
	
	GTMHTTPFetcher* jsonFetcher = [GTMHTTPFetcher fetcherWithRequest: [NSMutableURLRequest requestWithURL: [NSURL URLWithString: requestString]]];	
	jsonFetcher.postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	[jsonFetcher beginFetchWithCompletionHandler:^(NSData *retrievedData, NSError *error) 
	 {
		 if (error != nil) 
		 {
			 NSLog(@"Stoker setTarget:forSensorID: GTMHTTPFetcher error: %@", error);
		 } 
	 }];
}

- (NSString *) urlEncodeValue:(NSString *)str
{
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);	
	return [result autorelease];
}


#pragma mark -
#pragma mark SendExpect Delegate Methods

- (void) sendExpectStarted: (SendExpect *) sequence
{
}

- (void) sendExpectCompleted: (SendExpect *) sequence
{
	// if this was a shutdown, finish it up
	if (self.shutdownCompletionBlock)
	{
		self.shutdownCompletionBlock();
		self.shutdownCompletionBlock = nil;
	}
	else if ([[sequence name] isEqualToString: @"Telnet Output Stop"])
	{
		[self sendStatusUpdate: @"Telnet connection terminated"];

	}
}

- (void) sendExpectFailed: (SendExpect *) sequence withError: (NSString *) error
{
	NSLog(@"sendExpectFailed: %@ withError: %@", sequence.name, error);
	
}

@end


