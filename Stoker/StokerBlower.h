//
//  StokerBlower.h
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>

@class StokerSensor;
@interface StokerBlower : NSObject {
	
	NSString		*blowerName;
	NSString		*deviceID;
	Boolean			state;
    NSInteger		onCycleCount;
	StokerSensor 	*sensor;
}

@property (nonatomic, retain)	NSString		* blowerName;
@property (nonatomic, retain)	NSString		* deviceID;
@property (nonatomic, assign)	Boolean			state;
@property (nonatomic, retain)	StokerSensor 	* sensor;

@end


