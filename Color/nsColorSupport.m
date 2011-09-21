//
//  cpColorSupport.m
//  StokerX
//
//  Created by Joe Keenan on 2/19/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "nsColorSupport.h"

@implementation NSUserDefaults(colorSupport)

- (void)setColor:(NSColor *)aColor forKey:(NSString *)aKey
{
    NSData *theData=[NSKeyedArchiver archivedDataWithRootObject:aColor];
    [self setObject:theData forKey:aKey];
}

- (NSColor *)colorForKey:(NSString *)aKey
{
    NSColor *theColor=nil;
    NSData *theData=[self dataForKey:aKey];
    if (theData != nil)
        theColor=(NSColor *)[NSKeyedUnarchiver unarchiveObjectWithData:theData];
    return theColor;
}

@end