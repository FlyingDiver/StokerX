//
//  LVColorWellCell.h
//  
//
//  Created by Lakshmi Vyasarajan on 3/19/09.
//  Copyright 2009 Ringce. MIT License.
//
//	Version: 0.5 Beta
//
#import <Cocoa/Cocoa.h>

@interface LVColorWellCell : NSActionCell {
	
	@private
	id delegate;
	NSString * colorKey;
	int colorRow;	
}

@property (readwrite, copy) NSString * colorKey;
@property (readwrite, assign) id delegate;

@end

@protocol LVColorWellCellDelegate
- (void) colorCell: (LVColorWellCell *)colorCell setColor:(NSColor *)color forRow:(int)row;

- (NSColor *) colorCell: (LVColorWellCell *)colorCell colorForRow:(int)row;

@end