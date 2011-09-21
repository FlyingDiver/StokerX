//
//  SendExpect.h
//  StokerX
//
//  Created by Joe Keenan on 11/6/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SendExpect : NSObject {

	NSArray 		*sequence;
	NSString		*name;
	NSUInteger		next;
	Boolean			completed;
	id				delegate;
}

- (SendExpect *) initWithSequence: (NSArray *) sequence;
- (NSString *)   nextSend;
- (NSString *)   nextExpect;

@property (nonatomic, retain) id			delegate;
@property (nonatomic, retain) NSString		*name;
@property (nonatomic, retain) NSArray 		*sequence;

@property (nonatomic, assign) NSUInteger	next;
@property (nonatomic, assign) Boolean		completed;

@end

@protocol SendExpectDelegate <NSObject>
@optional
- (void) sendExpectStarted: (SendExpect *) sequence;
- (void) sendExpectCompleted: (SendExpect *) sequence;
- (void) sendExpectFailed: (SendExpect *) sequence withError: (NSString *) error;
@end
