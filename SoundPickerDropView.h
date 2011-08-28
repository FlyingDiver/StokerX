//
//  SoundPickerDropView.h
//  OneMinuteEggTimer
//
//  Created by Karl Kraft on 12/2/07.
//  Copyright 2007 Karl Kraft. All rights reserved.
//



@class SoundPicker;


@interface SoundPickerDropView : NSView {
	NSString *path;
	NSImage *pathImage;
	NSString *dragPath;
	NSImage *tempDragImage;
	IBOutlet SoundPicker *picker;
}

- (void)setPath:(NSString *)s;

@end
