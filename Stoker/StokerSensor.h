//
//  StokerSensor.h
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>

@class StokerBlower;
@interface StokerSensor : NSObject {
	
	NSString	* sensorName;
	NSString	* deviceID;
	NSString	* blowerID;	
	NSNumber	* tempCurrent;
	NSNumber	* tempTarget;
	NSNumber	* tempHigh;
	NSNumber	* tempLow;
	Boolean		alarm;
	Boolean		control;
	StokerBlower *blower;
}

@property (nonatomic, retain) 	NSString		* sensorName;
@property (nonatomic, retain) 	NSString		* deviceID;
@property (nonatomic, retain) 	NSNumber		* tempCurrent;
@property (nonatomic, retain) 	NSNumber		* tempTarget;
@property (nonatomic, retain) 	NSString		* blowerID;
@property (nonatomic, assign) 	Boolean	  		control;
@property (nonatomic, retain)	StokerBlower 	* blower;

@end
