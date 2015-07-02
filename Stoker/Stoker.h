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
#import "StokerSensor.h"
#import "StokerBlower.h"

#define STOKER_QUERY_INTERVAL	10.0
#define BLOWER_STEP				60.0

@class GTMHTTPFetcher;
@interface Stoker : NSObject <GCDAsyncSocketDelegate> {
@private
	id						delegate;
	NSString				*stokerVersion;
	NSString				*ipAddress;
	NSTimer					*jsonTimer;
	Boolean					isLogging;
	Boolean					wifiStoker;
	Boolean					httpOnlyMode;
	Boolean					stokerAvailable;
	
	NSString				*blowerControlSensor;		// the sensor that controls the blower, for lid-off control
	
	void (^shutdownCompletionBlock_)(void);
	void (^connectCompletionBlock_)(void);
	
	GCDAsyncSocket 			*socket;
	dispatch_queue_t		socketQueue;
	SendExpect				*mySendExpect;				// send-expect sequence for telnet interface
	NSString				*lastExpect;
	
	NSMutableDictionary		*sensorDict;				// dictionary of all sensor objects, keyed by DeviceID
	NSMutableArray			*sensorArray;				// array of sensor objects, in graphing order
	NSMutableDictionary		*blowerDict;				// dictionary of all blower objects, keyed by DeviceID
	NSMutableArray			*blowerArray;				// array of sensor objects, in graphing order
	NSMutableDictionary		*deviceDict;				// combined dictionary to make plot lookup easier
	
	Boolean					connectionReady, telnetActive;
}

@property (nonatomic, retain) id				delegate;
@property (nonatomic, copy)   NSString			*stokerVersion;
@property (nonatomic, copy)   NSString			*ipAddress;
@property (nonatomic, retain) NSTimer       	*jsonTimer;
@property (nonatomic, assign) Boolean			isLogging;
@property (nonatomic, assign) Boolean			wifiStoker;
@property (nonatomic, assign) Boolean			httpOnlyMode;
@property (nonatomic, assign) Boolean			stokerAvailable;
@property (nonatomic, retain) SendExpect		*mySendExpect;
@property (nonatomic, copy)   NSString			*lastExpect;

@property (copy) void (^shutdownCompletionBlock)(void);
@property (copy) void (^connectCompletionBlock)(void);

- (void) getStokerJSON: (NSTimer *) theTimer;

- (void) startLogging;
- (void) stopLogging;

- (BOOL) connectWithCompletionHandler:(void (^)(void))handler;
- (BOOL) shutdownWithCompletionHandler:(void (^)(void))handler;

- (void) startTelnetCapture;
- (void) stopTelnetCapture;
- (void) parseTelnetOutput: (NSString *) stokerOutput;

- (void)jsonFetcher:(GTMHTTPFetcher *)fetcher finishedWithData:(NSData *)retrievedData error:(NSError *)error;

- (void) sensorSetup: (NSDictionary *) results;

- (int) numberOfSensors;
- (int) numberOfBlowers;

- (double) totalBlowerRatio;
- (double) recentBlowerRatio: (NSInteger) minutes;

- (NSString *) typeForSensor: (int) sensorNo;
- (NSString *) nameForSensor: (int) sensorNo;
- (NSString *) idForSensor: (int) sensorNo;
- (NSNumber *) tempForSensor: (int) sensorNo;
- (NSNumber *) targetForSensor: (int) sensorNo;
- (NSString *) blowerForSensor: (int) sensorNo;

- (NSString *) nameForBlower: (int) blowerNo;
- (NSString *) idForBlower:   (int) blowerNo;

- (void) setName:   (NSString *) name   forSensor: (int) sensorNo;
- (void) setTarget: (NSNumber *) target forSensor: (int) sensorNo;
- (void) setTarget: (NSNumber *) target forSensorID: (NSString *) sensorID;
- (NSString *)urlEncodeValue:(NSString *)str;

- (void) sendStatusUpdate: (NSString *) status;

- (void) updateSensor: (NSString *) sensorID withTemp: (double) temp andTarget: (double) target;
- (void) updateBlower: (NSString *) blowerID withState: (Boolean) state;

- (NSUInteger) numberOfRecordsForPlot:(id <NSCopying, NSObject>)deviceID;
- (NSNumber *) plotValueForPlot:(id <NSCopying, NSObject>) deviceID field: (NSUInteger)fieldEnum recordIndex: (NSUInteger)index;


@end

@protocol StokerDelegate <NSObject>
@optional

//	Sent when the Stoker has completed it's setup (connected to Stoker and read sensor info)
- (void) stokerHasCompletedSetup: (Stoker *) stk;

- (void) stokerSensorUpdate: (Stoker *) stk;

// Sent when there is some status change worthy of display :)
- (void) stoker: (Stoker *) stk statusUpdate: (NSString *) theStatus;

// Sent when the telnet connection changes status
- (void) stoker: (Stoker *) stk telnetActive: (Boolean) active;

// Sent when logging starts/stops
- (void) stoker: (Stoker *) stk isLogging: (Boolean) active;

// Sent when the HTTP/JSON connection has an error
- (void) stoker: (Stoker *) stk httpError: (NSString *) theError;

// Sent when the stoker has updated Sensor data
- (void) stokerSensorUpdate: (Stoker *) stk;

@end
