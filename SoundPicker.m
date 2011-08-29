//
//  SoundPicker.m
//  OneMinuteEggTimer
//
//  Created by Karl Kraft on 12/2/07.
//  Copyright 2007 Karl Kraft. All rights reserved.
//

#import "SoundPicker.h"


@implementation SoundPicker

@synthesize sound, prefsPrefix;

- (id) init
{
	NSLog(@"SoundPicker init");
	
	if (!(self = [super init]))
		return nil;
	
	return self;
}

- (void)windowDidLoad
{
	NSLog(@"SoundPicker windowDidLoad");	
}

+ (NSArray *)allowedSoundExtensions;
{
	return [NSArray arrayWithObjects:@"caf",@"aiff", @"aif", @"aifc",@"wav",@"wave",@"snd",@"au",@"mp3",@"ulw",@"m4p",@"m4a",nil];
	
}

+ (NSString *)pathForUserAddedSounds;
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDir = [[paths objectAtIndex:0] stringByAppendingPathComponent: [[NSProcessInfo processInfo] processName]];
	
	return [supportDir stringByAppendingPathComponent: @"Sounds"];
}


- (IBAction)volumeChanged:(id)anObject;
{
	NSLog(@"SoundPicker volumeChanged:");

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setFloat:[volumeControl floatValue] forKey:[NSString stringWithFormat:@"%@_Volume",prefsPrefix]];
	[sound setVolume:[volumeControl floatValue]];
	[sound stop];
	[sound play];
}

- (IBAction)increaseVolume:(id)sender;
{
	NSLog(@"SoundPicker increaseVolume:");

	float newVolume = [sound volume] + 0.1;
	if (newVolume > 1.0 ) newVolume = 1.0;
	[volumeControl setFloatValue:newVolume];
	[self volumeChanged:volumeControl];
}

- (IBAction)decreaseVolume:(id)sender;
{
	NSLog(@"SoundPicker decreaseVolume:");

	float newVolume = [sound volume] - 0.1;
	if (newVolume < 0.0 ) newVolume = 0.0;
	[volumeControl setFloatValue:newVolume];
	[self volumeChanged:volumeControl];
}

- (NSArray *)findSoundsIn:(NSString *)path;
{
	NSMutableArray *returnArray = [NSMutableArray array];
	
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
	for (NSString *s in files) {
		NSString *extension = [s pathExtension];
		if ([[SoundPicker allowedSoundExtensions] containsObject:extension]) {
			[returnArray addObject:[NSString stringWithFormat:@"%@/%@",path,s]];
		}
	}
	return returnArray;
}

NSInteger nameSorter(NSString *s1, NSString *s2,void *context) {
	return [[s1 lastPathComponent] compare:[s2 lastPathComponent]];
}

- (void)rebuildSoundPopup;
{
	NSString *currentPath = [[availableSoundsPopup selectedItem] representedObject];
	
	NSMenu *newMenu = [[NSMenu alloc] initWithTitle:@""];
		
	// Home directory sounds
	
	NSString *homeSoundPath = [NSString stringWithFormat:@"%@/Library/Sounds",NSHomeDirectory()];
	NSMutableArray *homeList = [[NSMutableArray alloc] initWithCapacity: 5];
	[homeList addObjectsFromArray:[self findSoundsIn:homeSoundPath]];
	[homeList sortUsingFunction:nameSorter context:nil];
	
	if ([homeList count] && [newMenu numberOfItems]) 
	{
		[newMenu addItem:[NSMenuItem separatorItem]];
	}
	
	for (NSString *s in homeList) 
	{
		NSMenuItem *newItem = [[[NSMenuItem alloc]  initWithTitle:[[s lastPathComponent] stringByDeletingPathExtension]
														   action:NULL
													keyEquivalent:@""] autorelease];
		[newItem setRepresentedObject:s];
		[newMenu addItem:newItem];
	}
	[homeList release];

	// then the system sounds
	
	NSMutableArray *systemList = [[NSMutableArray alloc] initWithCapacity: 20];
	
	[systemList addObjectsFromArray:[self findSoundsIn:@"/System/Library/Sounds"]];
	[systemList addObjectsFromArray:[self findSoundsIn:@"/Library/Sounds"]];
	[systemList sortUsingFunction:nameSorter context:nil];
	
	if ([systemList count] && [newMenu numberOfItems]) {
		[newMenu addItem:[NSMenuItem separatorItem]];
	}
	
	for (NSString *s in systemList) 
	{
		NSMenuItem *newItem = [[[NSMenuItem alloc]  initWithTitle:[[s lastPathComponent] stringByDeletingPathExtension]
														  action:NULL
												   keyEquivalent:@""] autorelease];
		[newItem setRepresentedObject:s];
		[newMenu addItem:newItem];
	}
	[systemList release];
	
	[availableSoundsPopup setMenu:newMenu];
	for (NSMenuItem *item in [newMenu itemArray]) 
	{		
		if ([currentPath isEqual:[item representedObject]]) {
			[availableSoundsPopup selectItem:item];
		}
	}
	[newMenu release];
	
//	NSLog(@"SoundPicker rebuildSoundPopup complete");
}


- (void)setSoundPath:(NSString *)newPath;
{
	NSLog(@"SoundPicker setSoundPath: %@", newPath);

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:newPath forKey:[NSString stringWithFormat:@"%@_Path",prefsPrefix]];

	NSSound *newSound = [[NSSound alloc] initWithContentsOfFile:newPath byReference:YES];
	
	[newSound setVolume:[sound volume]];
	[sound stop];
	sound = newSound;
	[self rebuildSoundPopup];
	for (NSMenuItem *item in [[availableSoundsPopup menu] itemArray]) {
		if ([newPath isEqual:[item representedObject]]) {
			[availableSoundsPopup selectItem:item];
		}
	}	
}
- (IBAction)soundPicked:(id)anObject;
{
	NSMenuItem *item = [availableSoundsPopup selectedItem];
	
	[sound stop];

	[self setSoundPath:[item representedObject]];
	
	[sound play];
}

- (void)refreshPopup:(NSNotification *)aNotice;
{
	NSLog(@"SoundPicker refreshPopup:");
	
	[self rebuildSoundPopup];
}

- (void)setDefaultSoundPath:(NSString *)defaultPath;
{
	NSLog(@"SoundPicker setDefaultSoundPath: %@, prefsPrefix = %@", defaultPath, prefsPrefix);

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *savedPath = [defaults stringForKey:[NSString stringWithFormat:@"%@_Path",prefsPrefix]];
	NSString *savedVolume = [defaults stringForKey:[NSString stringWithFormat:@"%@_Volume",prefsPrefix]];
	if (!savedVolume) savedVolume = @"0.8";

	if (savedPath) {
		NSLog(@"SoundPicker savedPath is %@",savedPath);
		[self setSoundPath:savedPath];
		[volumeControl setFloatValue:[savedVolume floatValue]];
		[sound setVolume:[savedVolume floatValue]];
	} else {
		[self setSoundPath:defaultPath];
		[volumeControl setFloatValue:[savedVolume floatValue]];
		[sound setVolume:[savedVolume floatValue]];
	}
}


- (void)awakeFromNib;
{
	NSLog(@"SoundPicker awakeFromNib");
}
 

@end
