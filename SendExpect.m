//
//  SendExpect.m
//  StokerX
//
//  Created by Joe Keenan on 11/6/10.
//  Copyright 2010 Joseph P. Keenan Jr. All rights reserved.
//

#import "SendExpect.h"


@implementation SendExpect

@synthesize delegate;
@synthesize name;
@synthesize sequence;
@synthesize next;
@synthesize completed;

- (SendExpect *) initWithSequence: (NSArray *) theSequence
{
	if (!(self = [super init]))
		return nil;	
	
	self.sequence = theSequence;
	self.next = 0;
	self.completed = NO;
	self.name = nil;
	
	return self;
}

- (NSString *) nextSend
{
	NSString *send = [[sequence objectAtIndex: next] objectForKey: @"send"];

	if (next == 0)
	{
		if([[self delegate] respondsToSelector:@selector(sendExpectStarted:)]) {
			[[self delegate] sendExpectStarted: self];
		}
	}
	return send;
}

- (NSString *) nextExpect;
{
	NSString *expect = [[sequence objectAtIndex: next] objectForKey: @"expect"];

	next++;			// next pair
	
	if (next >= [sequence count])	// all done
	{
		completed = YES;
		if([[self delegate] respondsToSelector:@selector(sendExpectCompleted:)]) {
			[[self delegate] sendExpectCompleted: self];
		}
	}
	
	return expect;
}


@end
