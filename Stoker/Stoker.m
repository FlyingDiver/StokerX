//
//  Stoker.m
//  StokerX
//
//  Created by Joe Keenan on 10/27/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "Stoker.h"
#import "JSON.h"
#import "GTMOAuth/GTMHTTPFetcher.h"

@implementation Stoker

@synthesize delegate, stokerVersion, jsonTimer, ipAddress, isLogging;
@synthesize httpOnlyMode, stokerAvailable, mySendExpect, lastTemp, lidOffHold, blowerControlSensor, lastTempTarget;
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
		self.shutdownCompletionBlock = handler;
		[self stopTelnetCapture];		
		return NO;
	}
	
	[jsonTimer invalidate];
	jsonTimer = nil;
	return YES;
}

- (void) startLogging
{	
	self.isLogging = TRUE;
	
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
		[self sensorSetup: results];
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
			
			NSLog(@"sensorSetup: blower %@ (%@) is %@", theBlower.deviceID, theBlower.deviceName, theBlower.state ? @"On" : @"Off");

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
			theSensor.tempTarget 	= [sensor objectForKey:@"ta"];
			theSensor.tempCurrent 	= [sensor objectForKey:@"tc"];
			
			// Look for a matching BlowerID for this sensor
			if ([blowerDict count] > 0)
			{
				for (StokerBlower *blower in blowerArray)
				{
					if ([blower.deviceID isEqual: [sensor objectForKey:@"blower"]])
					{
						theSensor.blower = blower;
						blower.sensor = theSensor;
					
						NSLog(@"sensorSetup: sensor %@ (%@), current = %@, target = %@, blower = %@ (%@)", 
							  theSensor.deviceID, theSensor.deviceName, theSensor.tempCurrent, theSensor.tempTarget, blower.deviceID, blower.deviceName);
					}
					else
						NSLog(@"sensorSetup: sensor %@ (%@), current = %@, target = %@", theSensor.deviceID, theSensor.deviceName, theSensor.tempCurrent, theSensor.tempTarget);						
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
	
	NSLog(@"startTelnetCapture telnetAddress = %@", telnetAddress);
	
	if (![socket connectToHost:telnetAddress onPort: telnetPort error:&err])
	{
		NSLog (@"Stoker: Couldn't connect to %@:%u (%@).", ipAddress, telnetPort, err);
		return;
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
	static double lastUpdate = 0;
	
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
		
		[self updateSensor: deviceID withTemp: [tempUser doubleValue] andTarget: [[[sensorDict objectForKey: deviceID] tempTarget] doubleValue]];
		 
		if (blower)
		{
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
//	NSLog(@"Stoker updateSensor: %@ withTemp %lf andTarget: %lf", sensorID, temp, target);
	
	NSNumber *currentTime = [NSNumber numberWithDouble: [[NSDate date] timeIntervalSinceReferenceDate]];
	
	StokerSensor *theSensor = [sensorDict objectForKey: sensorID];
	
	theSensor.tempCurrent = [NSNumber numberWithDouble: temp];
	theSensor.tempTarget  = [NSNumber numberWithDouble: target];			
	[theSensor.plotData addObject: [NSArray arrayWithObjects: currentTime, theSensor.tempCurrent, theSensor.tempTarget, nil]];	
		
	if (theSensor.control && lidDetectionEnabled)		// only check for lid off on control blower
	{
		[self checkLidOffForSensor: theSensor];
	}
}

- (void) updateBlower: (NSString *) blowerID withState: (Boolean) state
{
//	NSLog(@"Stoker updateBlower: %@ withState: %@", blowerID, state ? @"On" : @"Off");

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
//	NSLog (@"Stoker: socket:didConnectToHost: %@:%u", host, port);
	
	telnetActive = YES;
	if([self delegate] && [[self delegate] respondsToSelector:@selector(stoker:telnetActive:)]) {
		[[self delegate] stoker: self telnetActive: YES];
	}
	connectionReady = YES;	// can't use the controller until this is set
	
	// on first connection, we're looking for a "login:" prompt
	
	NSData *colon = [@":" dataUsingEncoding:NSASCIIStringEncoding];
	[socket readDataToData:colon withTimeout:-1 tag: 0];
}

- (void)socket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if (err)
	{
		NSLog (@"Stoker: socket:willDisconnectWithError: %@", err);    
	}
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	connectionReady = NO;
	
	if (telnetActive)
	{
		telnetActive = NO;	
	}
	
	if (shutdownCompletionBlock_) 
    {
        shutdownCompletionBlock_();
    }
	else
		NSLog (@"Stoker: socketDidDisconnect:withError: %@", err);
}

-(void) socket:(GCDAsyncSocket *)sock didReadData:(NSData*) sockData withTag:(long)tag
{		
	if (mySendExpect)
	{
		NSString *send = [mySendExpect nextSend];
		NSString *expect = [mySendExpect nextExpect];
				
//		NSLog(@"Stoker sending \"%@\", expecting \"%@\"", send, expect);
		
		[socket writeData: [send dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1 tag: 0];
		[socket readDataToData: [expect dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1 tag: 0];
				
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
	return [sensorArray count];
}

- (int) numberOfBlowers
{
	return [blowerArray count];
}

- (NSString *) typeForSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	
	if (theSensor.blower)
		return @"Control";
	else
		return @"Monitor";
}

- (NSString *) nameForSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];

	return theSensor.deviceName;
}

- (NSString *) idForSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];

	return theSensor.deviceID;
}

- (NSNumber *) tempForSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	
	return theSensor.tempCurrent;
}

- (NSNumber *) targetForSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	
	return theSensor.tempTarget;
}

- (NSString *) blowerForSensor: (int) sensorNo
{
	StokerSensor *theSensor = [sensorArray objectAtIndex: sensorNo];
	
	if (theSensor.blower)
	{
		StokerBlower *theBlower = (StokerBlower *) theSensor.blower;
		return theBlower.state ? @"On" : @"Off";
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
	StokerSensor *theBlower = [blowerArray objectAtIndex: blowerNo];
	return theBlower.deviceID;
}

- (NSUInteger) numberOfRecordsForPlot:(id <NSCopying, NSObject>)deviceID
{
//	NSLog(@"numberOfRecordsForPlot: %@ = %ld", deviceID, [[[deviceDict objectForKey: deviceID] plotData] count]);

	return [[[deviceDict objectForKey: deviceID] plotData] count];
}

- (NSNumber *) plotValueForPlot:(id <NSCopying, NSObject>) deviceID field: (NSUInteger)fieldEnum recordIndex: (NSUInteger)index
{
	NSNumber *value = [[[[deviceDict objectForKey: deviceID] plotData] objectAtIndex: index] objectAtIndex: fieldEnum];
	
//	NSLog(@"plotValueForPlot: %@ field: %ld recordIndex: %ld = %@", deviceID, fieldEnum, index, value);
	
	return  value;
	
//	return [[[deviceDict objectForKey: deviceID] plotData] objectAtIndex: fieldEnum];
}

- (double) totalBlowerRatio
{
	StokerBlower *theBlower = [blowerArray objectAtIndex: blowerControlSensor];
	
	return ((double) theBlower.onCount / (double) [theBlower.plotData count]);
}

- (double) recentBlowerRatio: (NSInteger) minutes
{
	StokerBlower *theBlower = [blowerArray objectAtIndex: blowerControlSensor];
	
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
		return ((float) onCount / (float) totalCount * 100.0);
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

- (NSString *) urlEncodeValue:(NSString *)str
{
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);	
	return [result autorelease];
}

#pragma mark -
#pragma mark Lid Detection Methods


- (void) enableLidDetection: (Boolean) enabled withDrop: (double) drop andWait: (double) wait
{	
	NSLog(@"Stoker enableLidDetection: %@ withDrop: %lf andWait: %lf", enabled ? @"On" : @"Off", drop, wait);

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

- (void) checkLidOffForSensor: (StokerSensor *) theSensor
{
	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

	if (!lastTemp)		// first time, get a last temp to use going forward
	{
		self.lastTemp = theSensor.tempCurrent;
		lastTempTime = currentTime;
	}
	
	NSTimeInterval interval = currentTime - lastTempTime;
	
	if (!lidOffHold &&  (interval > 15.0))				// not on hold, looking for a drop, check every 15 sec
	{
		double tempDrop = [lastTemp doubleValue] - [theSensor.tempCurrent doubleValue];
	
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
		self.lastTemp = theSensor.tempCurrent;
		
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


