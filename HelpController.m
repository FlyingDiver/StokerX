//
//  HelpController.m
//  StokerX
//
//  Created by Joe Keenan on 9/6/11.
//  Copyright 2011 Joseph P Keenan Jr. All rights reserved.
//

#import "HelpController.h"

@implementation HelpController

- (id) init
{	
	if (!(self = [super initWithWindowNibName:@"Help"]))
		return nil;
	
	return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
	if (self) 
	{		
		NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Help" ofType:@"rtf"];  
		if (filePath) 
		{  
			helpText = [[NSAttributedString alloc] initWithPath:filePath documentAttributes: nil];  
			if (helpText) 
			{  
				[[helpTextView textStorage]replaceCharactersInRange: NSMakeRange(0, [[helpTextView string] length])
											   withAttributedString: helpText];
				[helpText release];
			}
		}
    }

	[self.window setFrameAutosaveName:@"Help Window"];
	[self.window makeKeyAndOrderFront:nil];
}

@end
