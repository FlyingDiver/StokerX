//
//  EmailSender.h
//  StokerX
//
//  Created by Joe Keenan on 8/15/2011.
//  Copyright 2011 Joseph P. Keenan Jr. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface EmailSender: NSObject 

- (void)sendEmailMessage:(NSString *)message to: (NSString *) recipient;

@end
