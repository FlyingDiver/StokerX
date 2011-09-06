//
//  HelpController.h
//  StokerX
//
//  Created by Joe Keenan on 9/6/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HelpController : NSWindowController
{
	IBOutlet NSTextView				*helpTextView;
	NSAttributedString				*helpText;

}
@end
