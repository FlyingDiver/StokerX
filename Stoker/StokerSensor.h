//
//  StokerSensor.h
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StokerDevice.h"

@interface StokerSensor : StokerDevice {
}

@property (nonatomic, retain) 	NSNumber		*tempCurrent;
@property (nonatomic, retain) 	NSNumber		*tempTarget;
@property (nonatomic, assign) 	Boolean	  		control;
@property (nonatomic, retain)	StokerDevice 	*blower;

@end
