//
//  StokerBlower.h
//  StokerX
//
//  Created by Joe Keenan on 9/21/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StokerDevice.h"

@interface StokerBlower : StokerDevice 
{
	NSInteger			onCount;
	Boolean			state;
	StokerDevice		*sensor;
}


@property (nonatomic, assign) NSInteger			onCount;
@property (nonatomic, assign) Boolean			state;
@property (nonatomic, retain) StokerDevice		*sensor;

@end


