//
//  SoundPicker.h
//  OneMinuteEggTimer
//
//  Created by Karl Kraft on 12/2/07.
//  Copyright 2007 Karl Kraft. All rights reserved.
//


@class SoundPickerDropView;

@interface SoundPicker : NSObject {

	IBOutlet NSPopUpButton *availableSoundsPopup;
	IBOutlet NSSlider *volumeControl;
}

@property (nonatomic, retain) NSString *prefsPrefix;
@property (nonatomic, retain) NSSound *sound;

+ (NSArray *)allowedSoundExtensions;
+ (NSString *)pathForUserAddedSounds;

- (IBAction)increaseVolume:(id)sender;
- (IBAction)decreaseVolume:(id)sender;
- (IBAction)volumeChanged:(id)anObject;
- (IBAction)soundPicked:(id)anObject;

- (void)setSoundPath:(NSString *)path;
- (void)setDefaultSoundPath:(NSString *)defaultPath;

@end
