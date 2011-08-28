//
//  SoundPickerDropView.m
//  OneMinuteEggTimer
//
//  Created by Karl Kraft on 12/2/07.
//  Copyright 2007 Karl Kraft. All rights reserved.
//

#import "SoundPickerDropView.h"

#import "SoundPicker.h"


@implementation SoundPickerDropView

NSImage *baseImage;

NSImage *topLeftCornerImage;
NSImage *topEdgeImage;
NSImage *topRightCornerImage;
NSImage *leftEdgeImage;
NSImage *centerImage;
NSImage *rightEdgeImage;
NSImage *bottomLeftCornerImage;
NSImage *bottomEdgeImage;
NSImage *bottomRightCornerImage;

+ (void)initialize;
{
	
	if (baseImage) return;

	NSRect tileRect = NSMakeRect(0,0,8,8);

	baseImage = [NSImage imageNamed:@"SoundPickerBackground"];

	topLeftCornerImage = [[NSImage alloc] initWithSize:tileRect.size];
	[topLeftCornerImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(0.0,16.0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[topLeftCornerImage unlockFocus];
	
	topEdgeImage = [[NSImage alloc] initWithSize:tileRect.size];
	[topEdgeImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(8.0,16.0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[topEdgeImage unlockFocus];
	
	topRightCornerImage = [[NSImage alloc] initWithSize:tileRect.size];
	[topRightCornerImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(16.0,16.0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[topRightCornerImage unlockFocus];
	
	leftEdgeImage = [[NSImage alloc] initWithSize:tileRect.size];
	[leftEdgeImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(0,8.0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[leftEdgeImage unlockFocus];
	
	centerImage = [[NSImage alloc] initWithSize:tileRect.size];
	[centerImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(8.0,8.0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[centerImage unlockFocus];
	
	rightEdgeImage = [[NSImage alloc] initWithSize:tileRect.size];
	[rightEdgeImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(16.0,8.0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[rightEdgeImage unlockFocus];
	
	bottomLeftCornerImage = [[NSImage alloc] initWithSize:tileRect.size];
	[bottomLeftCornerImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(0,0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[bottomLeftCornerImage unlockFocus];
	
	bottomEdgeImage = [[NSImage alloc] initWithSize:tileRect.size];
	[bottomEdgeImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(8.0,0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[bottomEdgeImage unlockFocus];
	
	bottomRightCornerImage = [[NSImage alloc] initWithSize:tileRect.size];
	[bottomRightCornerImage lockFocus];
	[baseImage drawInRect:tileRect fromRect:NSMakeRect(16.0,0,8.0,8.0) operation:NSCompositeCopy fraction:1.0];
	[bottomRightCornerImage unlockFocus];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)rect;
{
	
	NSDrawNinePartImage([self bounds],
											topLeftCornerImage, topEdgeImage, topRightCornerImage,
											leftEdgeImage, centerImage, rightEdgeImage, 
											bottomLeftCornerImage, bottomEdgeImage, bottomRightCornerImage, NSCompositeSourceOver, 1.0, NO);

	NSRect usableRect = NSInsetRect([self bounds], 8.0, 8.0);
	NSRect srcRect = NSMakeRect(0,0,0,0);
	srcRect.size = [pathImage size];
	if (usableRect.size.width > usableRect.size.height) {
		CGFloat newWidth =  usableRect.size.height;
		usableRect.origin.x = usableRect.origin.x+(usableRect.size.width - newWidth)/2.0;
		usableRect.size.width = newWidth;
	} else if (usableRect.size.height > usableRect.size.width) {
		CGFloat newHeight =  usableRect.size.width;
		usableRect.origin.y = usableRect.origin.y+(usableRect.size.height - newHeight)/2.0;
		usableRect.size.height = newHeight;
	
	}
	if (tempDragImage) {
		[tempDragImage drawInRect:usableRect fromRect:srcRect operation:NSCompositeSourceOver fraction:0.5];
	} else {
		[pathImage drawInRect:usableRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
}


- (void)setPath:(NSString *)s;
{
	path =[s copy];
	pathImage = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[self setNeedsDisplay:YES];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
	if ([files count] != 1) return NSDragOperationNone;
	dragPath = [files objectAtIndex:0];
	NSString *extension = [dragPath pathExtension];
	if ([[SoundPicker allowedSoundExtensions] containsObject:extension]) {
		tempDragImage = [[NSWorkspace sharedWorkspace] iconForFile:dragPath];
		[self setNeedsDisplay:YES];
		return NSDragOperationCopy;
	} else  {
		return NSDragOperationNone;
	}
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
	dragPath = nil;
	tempDragImage = nil;
	[self setNeedsDisplay:YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
	
	NSInteger tag=0;
	
	[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceCopyOperation
																							 source:[dragPath stringByDeletingLastPathComponent]
																					destination:[SoundPicker pathForUserAddedSounds] 
																								files:[NSArray arrayWithObject:[dragPath lastPathComponent]]
																									tag:&tag];
	
	if (tag!=0) return NO;

	[picker setSoundPath:[NSString stringWithFormat:@"%@/%@",[SoundPicker pathForUserAddedSounds],[dragPath lastPathComponent]]];
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
	tempDragImage = nil;
	[self setNeedsDisplay:YES];
}



- (void)awakeFromNib;
{
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,nil]];
	
}
@end
