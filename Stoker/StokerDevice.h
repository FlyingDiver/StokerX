//
//  StokerDevice.h
//  StokerX
//
//  Created by Joe Keenan on 9/24/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StokerDevice : NSObject
{
	NSString		*deviceName;
	NSString		*deviceID;
	NSMutableArray 	*plotData;
}

@property (nonatomic, copy)   NSString			*deviceName;
@property (nonatomic, copy)   NSString			*deviceID;
@property (nonatomic, retain) NSMutableArray 	*plotData;

- (id)initWithName: (NSString *) name andID: (NSString *) device;

@end
