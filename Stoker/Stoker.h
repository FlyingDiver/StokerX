//
//  Stoker.h
//  StokerX
//
//  Created by Joe Keenan on 10/27/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "SendExpect.h"

#define STOKER_QUERY_INTERVAL	10.0
#define BLOWER_STEP				60.0

@class GTMHTTPFetcher;
@interface Stoker : NSObject <GCDAsyncSocketDelegate> {
@private
	GCDAsyncSocket 			*socket;
	dispatch_queue_t		socketQueue;
	SendExpect				*mySendExpect;				// send-expect sequence for telnet interface
	NSMutableDictionary		*sensorDict;				// dictionary of all sensor objects, keyed by DeviceID
	NSMutableArray			*sensorArray;				// array of sensor objects, in graphing order
	NSMutableDictionary		*blowerDict;				// dictionary of all blower objects, keyed by DeviceID
	NSMutableArray			*blowerArray;				// array of sensor objects, in graphing order
	
	double					lidOffWait;
	double					lidOffDrop;
	NSTimeInterval			lastTempTime;				// time of last sample for lid off detection
	
	Boolean					connectionReady, lidDetectionEnabled, telnetActive;
}

@property (nonatomic, retain) id				delegate;
@property (nonatomic, retain) NSString			*stokerVersion;
@property (nonatomic, retain) NSURLConnection	*jsonConnection;
@property (nonatomic, retain) NSURLRequest 		*jsonRequest;
@property (nonatomic, retain) NSMutableData		*jsonData;
@property (nonatomic, retain) NSURLConnection	*postConnection;
@property (nonatomic, retain) NSTimer       	*jsonTimer;
@property (nonatomic, retain) NSString			*ipAddress;
@property (nonatomic, assign) Boolean			isLogging;
@property (nonatomic, assign) Boolean			useTelnet;
@property (nonatomic, assign) Boolean			stokerAvailable;
@property (nonatomic, retain) SendExpect		*mySendExpect;
@property (nonatomic, retain) NSNumber			*lastTemp;					// last remembered temp for lid off detection
@property (nonatomic, assign) Boolean			lidOffHold;

@property (nonatomic, assign) NSInteger			blowerControlSensor;		// the sensor that controls the blower, for lid-off control
@property (nonatomic, retain) NSNumber			*lastTempTarget;			// the temp to restore after lid-off
@property (copy) void (^completionBlock)(void);

- (void)connectToIPAddress: (NSString *) ip;
- (void) getStokerJSON: (NSTimer *) theTimer;

- (void) startLogging;
- (void) stopLogging;
- (BOOL) shutdownWithCompletionHandler:(void (^)(void))handler;

- (void) startTelnetCapture;
- (void) stopTelnetCapture;
- (void) parseTelnetOutput: (NSString *) stokerOutput;

- (void)jsonFetcher:(GTMHTTPFetcher *)fetcher finishedWithData:(NSData *)retrievedData error:(NSError *)error;

- (void) sensorSetup: (NSDictionary *) results;

- (int) numberOfSensors;
- (int) numberOfBlowers;

- (NSString *) typeForSensor: (int) sensorNo;
- (NSString *) nameForSensor: (int) sensorNo;
- (NSString *) idForSensor: (int) sensorNo;
- (NSNumber *) tempForSensor: (int) sensorNo;
- (NSNumber *) targetForSensor: (int) sensorNo;
- (NSString *) blowerForSensor: (int) sensorNo;

- (NSString *) nameForBlower: (int) blowerNo;
- (NSString *) idForBlower:   (int) blowerNo;

- (void) enableLidDetection: (Boolean) enabled withDrop: (double) drop andWait: (double) wait;
- (void) checkLidOffSensor: (NSString *) sensor withTemp: (NSNumber *) currTemp;

- (void) setName:   (NSString *) name   forSensor: (int) sensorNo;
- (void) setTarget: (NSNumber *) target forSensor: (int) sensorNo;
- (NSString *)urlEncodeValue:(NSString *)str;

- (void) sendStatusUpdate: (NSString *) status;

@end

@protocol StokerDelegate <NSObject>
@optional

//	Sent when the Stoker has completed it's setup (connected to Stoker and read sensor info)
- (void) stokerHasCompletedSetup: (Stoker *) stk;

// Sent when there is some status change worthy of display :)
- (void) stoker: (Stoker *) stk statusUpdate: (NSString *) theStatus;

// Sent when the telnet connection changes status
- (void) stoker: (Stoker *) stk telnetActive: (Boolean) active;

// Sent when logging starts/stops
- (void) stoker: (Stoker *) stk isLogging: (Boolean) active;

// Sent when the HTTP/JSON connection has an error
- (void) stoker: (Stoker *) stk httpError: (NSString *) theError;

// Sent when the stoker has updated Blower data
- (void) stoker: (Stoker *) stk updateBlowerState: (Boolean) active forBlower: (NSString *) blowerID;

// Sent when the stoker has updated Sensor temperature
- (void) stoker: (Stoker *) stk updateSensorTemp: (NSNumber *) Temp forSensor: (NSString *) sensorID;

@end
