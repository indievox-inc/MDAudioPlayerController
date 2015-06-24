//
//  AudioPlayer.m
//  MobileTheatre
//
//  Created by Matt Donnelly on 27/03/2010.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MDAudioPlayerController.h"
#import "MDAudioFile.h"
#import "MDAudioPlayerTableViewCell.h"
#import "MDAudio.h"

@interface MDAudioPlayerController ()
- (UIImage *)reflectedImage:(UIButton *)fromImage withHeight:(NSUInteger)height;
@end

@implementation MDAudioPlayerController

static const CGFloat kDefaultReflectionFraction = 0.65;
static const CGFloat kDefaultReflectionOpacity = 0.40;

@synthesize soundFiles;
@synthesize audioStreamer;
@synthesize gradientLayer;
@synthesize playButton;
@synthesize pauseButton;
@synthesize nextButton;
@synthesize previousButton;
@synthesize toggleButton;
@synthesize repeatButton;
@synthesize shuffleButton;
@synthesize currentTime;
@synthesize duration;
@synthesize indexLabel;
@synthesize titleLabel;
@synthesize artistLabel;
@synthesize albumLabel;
@synthesize progressSlider;
@synthesize songTableView;
@synthesize artworkView;
@synthesize reflectionView;
@synthesize containerView;
@synthesize overlayView;
@synthesize updateTimer;
@synthesize interrupted;
@synthesize repeatAll;
@synthesize repeatOne;
@synthesize shuffle;
@synthesize volumeView;
@synthesize coverImage;
@synthesize currentUserIsPlaying;

- (MDAudioPlayerController *)initWithSoundFiles:(NSMutableArray *)songs andSelectedIndex:(int)index {
  if (self = [super init])  {
    coverImage = [[UIImage alloc] init];
    self.soundFiles = songs;
    selectedIndex = index;
    
    NSError *error = nil;
    
    MDAudio *audio = [songs objectAtIndex:selectedIndex];
    NSString *escapedValue =
    [(NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                         nil,
                                                         (CFStringRef)audio.url.absoluteString,
                                                         NULL,
                                                         NULL,
                                                         kCFStringEncodingUTF8)
     autorelease];
	NSURL *url = [NSURL URLWithString:escapedValue];
    audioStreamer = [[AudioStreamer alloc] initWithURL:url];
    
    volumeView = [[MPVolumeView alloc] init];
    
    if (error)
      NSLog(@"%@", error);
  }
  
  return self;
}

- (void)dealloc {
  [audioStreamer release], audioStreamer = nil;
  [soundFiles release], soundFiles = nil;
  [gradientLayer release], gradientLayer = nil;
  [playButton release], playButton = nil;
  [pauseButton release], pauseButton = nil;
  [nextButton release], nextButton = nil;
  [previousButton release], previousButton = nil;
  [toggleButton release], toggleButton = nil;
  [repeatButton release], repeatButton = nil;
  [shuffleButton release], shuffleButton = nil;
  [currentTime release], currentTime = nil;
  [duration release], duration = nil;
  [indexLabel release], indexLabel = nil;
  [titleLabel release], titleLabel = nil;
  [artistLabel release], artistLabel = nil;
  [albumLabel release], albumLabel = nil;
  [volumeSlider release], volumeSlider = nil;
  [progressSlider release], progressSlider = nil;
  [songTableView release], songTableView = nil;
  [artworkView release], artworkView = nil;
  [reflectionView release], reflectionView = nil;
  [containerView release], containerView = nil;
  [overlayView release], overlayView = nil;
  [updateTimer invalidate], updateTimer = nil;
  [volumeView release], volumeView = nil;
  [coverImage release], coverImage = nil;
  [super dealloc];
}

void interruptionListenerCallback (void *userData, UInt32 interruptionState) {
  MDAudioPlayerController *vc = (MDAudioPlayerController *)userData;
  
  if (interruptionState == kAudioSessionBeginInterruption) {
    NSLog(@"interruptionState == kAudioSessionBeginInterruption");
    vc.currentUserIsPlaying = vc.audioStreamer.isPlaying;
    NSLog(@"currentUserIsPlaying %@", vc.currentUserIsPlaying ? @"Yes" : @"No");
    vc.interrupted = YES;
  }
  else if (interruptionState == kAudioSessionEndInterruption) {
    NSLog(@"interruptionState == kAudioSessionEndInterruption");
    NSLog(@"currentUserIsPlaying %@", vc.currentUserIsPlaying ? @"Yes" : @"No");
    if (vc.currentUserIsPlaying) {
      NSLog(@"Play");
      [vc pause];
      [vc play];
    }
    vc.interrupted = NO;
  }
}

- (void)updateCurrentTimeForStreamer:(AudioStreamer *)streamer {
  NSString *current = [NSString stringWithFormat:@"%d:%02d", (int)streamer.progress / 60, (int)streamer.progress % 60, nil];
  NSString *dur = [NSString stringWithFormat:@"-%d:%02d", (int)((int)(streamer.duration - streamer.progress)) / 60, (int)((int)(streamer.duration - streamer.progress)) % 60, nil];
  duration.text = dur;
  currentTime.text = current;
  progressSlider.value = streamer.progress;
}

- (void)updateCurrentTime {
  [self updateCurrentTimeForStreamer:self.audioStreamer];
}

- (void)updateViewForStreamerState:(AudioStreamer *)streamer {
  
  [self updateCurrentTimeForStreamer:audioStreamer];
  
  if (audioStreamer.isPlaying) {
    [playButton removeFromSuperview];
    [self.view addSubview:pauseButton];
    [updateTimer invalidate];
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:.01 target:self selector:@selector(updateCurrentTime) userInfo:audioStreamer repeats:YES];
  }
  else {
    [pauseButton removeFromSuperview];
    [self.view addSubview:playButton];
    [updateTimer invalidate];
    updateTimer = nil;
  }
  
  if (![songTableView superview])  {
    if (!artworkView.imageView) {
      [artworkView setImage:self.coverImage forState:UIControlStateNormal];
    }
    reflectionView.image = [self reflectedImage:artworkView withHeight:artworkView.bounds.size.height * kDefaultReflectionFraction];
  }
  
  if (repeatOne || repeatAll || shuffle)
    nextButton.enabled = YES;
  else	
    nextButton.enabled = [self canGoToNextTrack];
  previousButton.enabled = [self canGoToPreviousTrack];
}

- (void)updateViewForStreamerInfo:(AudioStreamer *)streamer {
  duration.text = [NSString stringWithFormat:@"%d:%02d", (int)streamer.progress / 60, (int)streamer.progress % 60, nil];
  indexLabel.text = [NSString stringWithFormat:@"%d of %d", (selectedIndex + 1), [soundFiles count]];
  progressSlider.maximumValue = streamer.duration;
  
  [self updateCurrentTime];
  
  if ([[NSUserDefaults standardUserDefaults] floatForKey:@"PlayerVolume"])
    volumeSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:@"PlayerVolume"];
}

- (void)dismissAudioPlayer {
  [audioStreamer stop];
  [self.parentViewController dismissModalViewControllerAnimated:YES];
  [self.navigationController popViewControllerAnimated:YES];
}

- (void)setAudioStreamer:(AudioStreamer *)anAudioStreamer {
  if (audioStreamer != anAudioStreamer) {
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(playbackStateChanged:)
     name:ASStatusChangedNotification
     object:audioStreamer];
    
    [audioStreamer release];
    audioStreamer = [anAudioStreamer retain];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(playbackStateChanged:)
     name:ASStatusChangedNotification
     object:anAudioStreamer];
  }
}

- (void)showSongFiles {
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationDuration:1];
  
  [UIView setAnimationTransition:([self.songTableView superview] ?
                                  UIViewAnimationTransitionFlipFromLeft : UIViewAnimationTransitionFlipFromRight)
                         forView:self.toggleButton cache:YES];
  if ([songTableView superview])
    [self.toggleButton setImage:[UIImage imageNamed:@"AudioPlayerAlbumInfo.png"] forState:UIControlStateNormal];
  else
    [self.toggleButton setImage:self.artworkView.imageView.image forState:UIControlStateNormal];
  
  [UIView commitAnimations];
  
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationDuration:1];
  
  [UIView setAnimationTransition:([self.songTableView superview] ?
                                  UIViewAnimationTransitionFlipFromLeft : UIViewAnimationTransitionFlipFromRight)
                         forView:self.containerView cache:YES];
  if ([songTableView superview]) {
    [self.songTableView removeFromSuperview];
    [self.artworkView setImage:self.coverImage forState:UIControlStateNormal];
    [self.containerView addSubview:self.artworkView];
    [self.containerView addSubview:reflectionView];
    [gradientLayer removeFromSuperlayer];
  }
  else {
    [self.artworkView setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerTableBackground" ofType:@"png"]] forState:UIControlStateNormal];
    [self.reflectionView removeFromSuperview];
    [self.overlayView removeFromSuperview];
    [self.containerView addSubview:songTableView];
    [self.artworkView removeFromSuperview];
    
    [[self.containerView layer] insertSublayer:gradientLayer atIndex:0];
  }
  
  [UIView commitAnimations];
}

- (void)showOverlayView {	
  if (overlayView == nil)  {		
    overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 76)];
    overlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    overlayView.opaque = NO;
    
    CGFloat screenWidth = self.view.bounds.size.width;
    self.progressSlider = [[[UISlider alloc] initWithFrame:CGRectMake(54, 20, screenWidth - 108, 23)] autorelease];
    [progressSlider setThumbImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerScrubberKnob" ofType:@"png"]]
                         forState:UIControlStateNormal];
    [progressSlider setMinimumTrackImage:[[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerScrubberLeft" ofType:@"png"]] stretchableImageWithLeftCapWidth:5 topCapHeight:3]
                                forState:UIControlStateNormal];
    [progressSlider setMaximumTrackImage:[[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerScrubberRight" ofType:@"png"]] stretchableImageWithLeftCapWidth:5 topCapHeight:3]
                                forState:UIControlStateNormal];
    [progressSlider addTarget:self action:@selector(progressSliderMoved:) forControlEvents:UIControlEventValueChanged];
    progressSlider.maximumValue = audioStreamer.duration;
    progressSlider.minimumValue = 0.0;	
    [overlayView addSubview:progressSlider];
    
    self.indexLabel = [[[UILabel alloc] initWithFrame:CGRectMake(128, 2, screenWidth - 256, 21)] autorelease];
    indexLabel.font = [UIFont boldSystemFontOfSize:12];
    indexLabel.shadowOffset = CGSizeMake(0, -1);
    indexLabel.shadowColor = [UIColor blackColor];
    indexLabel.backgroundColor = [UIColor clearColor];
    indexLabel.textColor = [UIColor whiteColor];
    indexLabel.textAlignment = NSTextAlignmentCenter;
    [overlayView addSubview:indexLabel];
    
    self.duration = [[[UILabel alloc] initWithFrame:CGRectMake(screenWidth - 48, 21, 48, 21)] autorelease];
    duration.font = [UIFont boldSystemFontOfSize:14];
    duration.shadowOffset = CGSizeMake(0, -1);
    duration.shadowColor = [UIColor blackColor];
    duration.backgroundColor = [UIColor clearColor];
    duration.textColor = [UIColor whiteColor];
    [overlayView addSubview:duration];
    
    self.currentTime = [[[UILabel alloc] initWithFrame:CGRectMake(0, 21, 48, 21)] autorelease];
    currentTime.font = [UIFont boldSystemFontOfSize:14];
    currentTime.shadowOffset = CGSizeMake(0, -1);
    currentTime.shadowColor = [UIColor blackColor];
    currentTime.backgroundColor = [UIColor clearColor];
    currentTime.textColor = [UIColor whiteColor];
    currentTime.textAlignment = NSTextAlignmentRight;
    [overlayView addSubview:currentTime];
    
    duration.adjustsFontSizeToFitWidth = YES;
    currentTime.adjustsFontSizeToFitWidth = YES;
    
    self.repeatButton = [[[UIButton alloc] initWithFrame:CGRectMake(10, 45, 32, 28)] autorelease];
    [repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerRepeatOff" ofType:@"png"]] 
                  forState:UIControlStateNormal];
    [repeatButton addTarget:self action:@selector(toggleRepeat) forControlEvents:UIControlEventTouchUpInside];
    [overlayView addSubview:repeatButton];
    
    self.shuffleButton = [[[UIButton alloc] initWithFrame:CGRectMake(screenWidth - 40, 45, 32, 28)] autorelease];
    [shuffleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerShuffleOff" ofType:@"png"]] 
                   forState:UIControlStateNormal];
    [shuffleButton addTarget:self action:@selector(toggleShuffle) forControlEvents:UIControlEventTouchUpInside];
    [overlayView addSubview:shuffleButton];
  }
  
  [self updateViewForStreamerInfo:audioStreamer];
  [self updateViewForStreamerState:audioStreamer];
  
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationDuration:0.4];
  [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
  
  if (![overlayView superview]) {
    [containerView addSubview:overlayView];
  } else {
    [overlayView removeFromSuperview];
  }
  
  [UIView commitAnimations];
}

- (void)toggleShuffle {
  if (shuffle) {
    shuffle = NO;
    [shuffleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerShuffleOff" ofType:@"png"]] forState:UIControlStateNormal];
  }
  else {
    shuffle = YES;
    [shuffleButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerShuffleOn" ofType:@"png"]] forState:UIControlStateNormal];
  }
  
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (void)toggleRepeat {
  if (repeatOne) {
    [repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerRepeatOff" ofType:@"png"]] 
                  forState:UIControlStateNormal];
    repeatOne = NO;
    repeatAll = NO;
  }
  else if (repeatAll) {
    [repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerRepeatOneOn" ofType:@"png"]] 
                  forState:UIControlStateNormal];
    repeatOne = YES;
    repeatAll = NO;
  }
  else {
    [repeatButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerRepeatOn" ofType:@"png"]] 
                  forState:UIControlStateNormal];
    repeatOne = NO;
    repeatAll = YES;
  }
  
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (BOOL)canGoToNextTrack {
  if (selectedIndex + 1 == [self.soundFiles count]) 
    return NO;
  else
    return YES;
}

- (BOOL)canGoToPreviousTrack {
  if (selectedIndex == 0)
    return NO;
  else
    return YES;
}

- (void)stop {
  [self.audioStreamer stop];
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (void)pause {
  [self.audioStreamer pause];
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (void)play {
  
  [self.audioStreamer start];
  
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (void)previous {
  NSUInteger newIndex = selectedIndex - 1;
  selectedIndex = newIndex;
  
  NSError *error = nil;
  AudioStreamer *streamer = [[AudioStreamer alloc] initWithURL:[(MDAudio *)[soundFiles objectAtIndex:selectedIndex] url]];
  
  if (error)
    NSLog(@"%@", error);
  
  //  player.volume = volumeSlider.value;
  //  [player setNumberOfLoops:0];
  
  self.audioStreamer = streamer;
  [streamer release];
  [self.audioStreamer start];
  
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];	
}

- (void)next {
  NSUInteger newIndex;
  
  if (shuffle)
  {
    newIndex = rand() % [soundFiles count];
  }
  else if (repeatOne)
  {
    newIndex = selectedIndex;
  }
  else if (repeatAll)
  {
    if (selectedIndex + 1 == [self.soundFiles count])
      newIndex = 0;
    else
      newIndex = selectedIndex + 1;
  }
  else
  {
    newIndex = selectedIndex + 1;
  }
  
  selectedIndex = newIndex;
  
  NSError *error = nil;
  AudioStreamer *streamer = [[AudioStreamer alloc] initWithURL:[(MDAudio *)[soundFiles objectAtIndex:selectedIndex] url]];
  
  if (error)
    NSLog(@"%@", error);
  
  self.audioStreamer = streamer;
  [streamer release];
  [self.audioStreamer start];
  
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (void)volumeSliderMoved:(UISlider *)sender {
  //  player.volume = [sender value];
  [[NSUserDefaults standardUserDefaults] setFloat:[sender value] forKey:@"PlayerVolume"];
}

- (IBAction)progressSliderMoved:(UISlider *)sender {
  //  audioStreamer.progress = sender.value;
  [self updateCurrentTimeForStreamer:audioStreamer];
}

//
// playbackStateChanged:
//
// Invoked when the AudioStreamer
// reports that its playback status has changed.
//
- (void)playbackStateChanged:(NSNotification *)aNotification {
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (void)updateTitleViewToCenter {
  [self.titleLabel sizeToFit];
  [self.artistLabel sizeToFit];
  [self.albumLabel sizeToFit];
  
  self.titleLabel.width = 200.f;
  self.artistLabel.width = 200.f;
  self.albumLabel.width = 200.f;
  
  CGFloat positionHeight = 3.f;
  UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.navigationController.navigationBar.bounds.size.width / 2, self.navigationController.navigationBar.bounds.size.height)];
  self.titleLabel.center = CGPointMake(titleView.center.x, titleView.center.y - self.titleLabel.bounds.size.height + positionHeight);
  [titleView addSubview:titleLabel];
  
  self.artistLabel.center = CGPointMake(titleView.center.x, titleView.center.y);
  [titleView addSubview:artistLabel];
  
  self.albumLabel.center = CGPointMake(titleView.center.x, titleView.center.y + self.albumLabel.bounds.size.height - positionHeight);
  [titleView addSubview:albumLabel];
  
  
  //  // Handle title, aritist, album label position
  //  if (!self.artistLabel.text.length) {
  //    self.titleLabel.center = CGPointMake(titleView.center.x, titleView.center.y);
  //  }
  
  self.navigationItem.titleView = titleView;
  [titleView release];
}

#pragma mark -
#pragma mark UIViewController

- (void)loadView {
  [super loadView];
  
  self.view.backgroundColor = [UIColor blackColor];
  
  [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
  
  [updateTimer invalidate];
  updateTimer = nil;
  
  
  self.toggleButton = [[[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)] autorelease];
  [toggleButton setImage:[UIImage imageNamed:@"AudioPlayerAlbumInfo.png"] forState:UIControlStateNormal];
  [toggleButton addTarget:self action:@selector(showSongFiles) forControlEvents:UIControlEventTouchUpInside];
  
  UIBarButtonItem *songsListBarButton = [[UIBarButtonItem alloc] initWithCustomView:toggleButton];
  
  self.navigationItem.rightBarButtonItem = songsListBarButton;
  [songsListBarButton release];
  songsListBarButton = nil;
  
  AudioSessionInitialize(NULL, NULL, interruptionListenerCallback, self);
  AudioSessionSetActive(true);
  UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
  AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);	
  
  MDAudio *selectedSong = [self.soundFiles objectAtIndex:selectedIndex];
  
  self.titleLabel = [[[UILabel alloc] init] autorelease];
  titleLabel.text = [selectedSong title];
  titleLabel.font = [UIFont boldSystemFontOfSize:12];
  titleLabel.backgroundColor = [UIColor clearColor];
  titleLabel.textColor = [UIColor whiteColor];
  titleLabel.shadowColor = [UIColor blackColor];
  titleLabel.shadowOffset = CGSizeMake(0, -1);
  titleLabel.textAlignment = UITextAlignmentCenter;
  titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
  
  self.artistLabel = [[[UILabel alloc] init] autorelease];
  artistLabel.text = [selectedSong artist];
  artistLabel.font = [UIFont boldSystemFontOfSize:12];
  artistLabel.backgroundColor = [UIColor clearColor];
  artistLabel.textColor = [UIColor lightGrayColor];
  artistLabel.shadowColor = [UIColor blackColor];
  artistLabel.shadowOffset = CGSizeMake(0, -1);
  artistLabel.textAlignment = UITextAlignmentCenter;
  artistLabel.lineBreakMode = UILineBreakModeTailTruncation;
  
  self.albumLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0, 27, 195, 12)] autorelease];
  albumLabel.text = [selectedSong album];
  albumLabel.backgroundColor = [UIColor clearColor];
  albumLabel.font = [UIFont boldSystemFontOfSize:12];
  albumLabel.textColor = [UIColor lightGrayColor];
  albumLabel.shadowColor = [UIColor blackColor];
  albumLabel.shadowOffset = CGSizeMake(0, -1);
  albumLabel.textAlignment = UITextAlignmentCenter;
  albumLabel.lineBreakMode = UILineBreakModeTailTruncation;
  
  duration.adjustsFontSizeToFitWidth = YES;
  currentTime.adjustsFontSizeToFitWidth = YES;
  progressSlider.minimumValue = 0.0;	
  
  self.containerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 0)] autorelease];
  [self.view addSubview:containerView];
  
  CGFloat screenWidth = self.view.bounds.size.width;
  self.artworkView = [[[UIButton alloc] initWithFrame:CGRectMake(0, 0, screenWidth, screenWidth)] autorelease];
  // Set cover image
  self.coverImage = [[soundFiles objectAtIndex:selectedIndex] coverImage];
  [artworkView setImage:coverImage forState:UIControlStateNormal];
  [artworkView addTarget:self action:@selector(showOverlayView) forControlEvents:UIControlEventTouchUpInside];
  artworkView.showsTouchWhenHighlighted = NO;
  artworkView.adjustsImageWhenHighlighted = NO;
  artworkView.backgroundColor = [UIColor clearColor];
  [containerView addSubview:artworkView];
  
  self.reflectionView = [[[UIImageView alloc] initWithFrame:CGRectMake(0, screenWidth, screenWidth, 96)] autorelease];
  reflectionView.image = [self reflectedImage:artworkView withHeight:artworkView.bounds.size.height * kDefaultReflectionFraction];
  reflectionView.alpha = kDefaultReflectionFraction;
  [self.containerView addSubview:reflectionView];
  
  if (IVISRetina4()) {
    self.songTableView = [[[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 456)] autorelease];
  } else {
    self.songTableView = [[[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 368)] autorelease];
  }
  
  self.songTableView.delegate = self;
  self.songTableView.dataSource = self;
  self.songTableView.separatorColor = [UIColor colorWithRed:0.986 green:0.933 blue:0.994 alpha:0.10];
  self.songTableView.backgroundColor = [UIColor clearColor];
  self.songTableView.contentInset = UIEdgeInsetsMake(0, 0, 37, 0); 
  self.songTableView.showsVerticalScrollIndicator = NO;
  
  gradientLayer = [[CAGradientLayer alloc] init];
  gradientLayer.frame = CGRectMake(0.0, self.containerView.bounds.size.height - 96, self.containerView.bounds.size.width, 48);
  gradientLayer.colors = [NSArray arrayWithObjects:(id)[UIColor clearColor].CGColor, (id)[UIColor colorWithWhite:0.0 alpha:0.5].CGColor, (id)[UIColor blackColor].CGColor, (id)[UIColor blackColor].CGColor, nil];
  gradientLayer.zPosition = INT_MAX;
  
  /*! HACKY WAY OF REMOVING EXTRA SEPERATORS */
  
  UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 10)];
  v.backgroundColor = [UIColor clearColor];
  [self.songTableView setTableFooterView:v];
  [v release];
  v = nil;
  
  CGFloat adjustY = 160;
  CGFloat adjustButtonY = 150;
  CGFloat adjustVolmeViewY = 90;
  
  UIImageView *buttonBackground = [[UIImageView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - adjustY, self.view.bounds.size.width, 96)];
  buttonBackground.image = [[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerBarBackground" ofType:@"png"]] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
  [self.view addSubview:buttonBackground];
  [buttonBackground release];
  buttonBackground  = nil;

  CGFloat spacer = (screenWidth - 40 * 3) / 4;
  self.playButton = [[[UIButton alloc] initWithFrame:CGRectMake(spacer * 2 + 40, self.view.frame.size.height - adjustButtonY, 40, 40)] autorelease];
  [playButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerPlay" ofType:@"png"]] forState:UIControlStateNormal];
  [playButton addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
  playButton.showsTouchWhenHighlighted = YES;
  [self.view addSubview:playButton];
  
  self.pauseButton = [[[UIButton alloc] initWithFrame:CGRectMake(spacer * 2 + 40, self.view.frame.size.height - adjustButtonY, 40, 40)] autorelease];
  [pauseButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerPause" ofType:@"png"]] forState:UIControlStateNormal];
  [pauseButton addTarget:self action:@selector(pause) forControlEvents:UIControlEventTouchUpInside];
  pauseButton.showsTouchWhenHighlighted = YES;
  
  self.nextButton = [[[UIButton alloc] initWithFrame:CGRectMake(spacer * 3 + 40 * 2, self.view.frame.size.height - adjustButtonY, 40, 40)] autorelease];
  [nextButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerNextTrack" ofType:@"png"]] 
              forState:UIControlStateNormal];
  [nextButton addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
  nextButton.showsTouchWhenHighlighted = YES;
  nextButton.enabled = [self canGoToNextTrack];
  [self.view addSubview:nextButton];
  
  self.previousButton = [[[UIButton alloc] initWithFrame:CGRectMake(spacer, self.view.frame.size.height - adjustButtonY, 40, 40)] autorelease];
  [previousButton setImage:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AudioPlayerPrevTrack" ofType:@"png"]]
                  forState:UIControlStateNormal];
  [previousButton addTarget:self action:@selector(previous) forControlEvents:UIControlEventTouchUpInside];
  previousButton.showsTouchWhenHighlighted = YES;
  previousButton.enabled = [self canGoToPreviousTrack];
  [self.view addSubview:previousButton];
  
  volumeView.frame = CGRectMake(0, 0, screenWidth * 0.84, 20);
  volumeView.center = CGPointMake(self.view.bounds.size.width / 2, self.view.frame.size.height - adjustVolmeViewY);

  [volumeView sizeToFit];
  [self.view addSubview:volumeView];
  
  [self updateViewForStreamerInfo:audioStreamer];
  [self updateViewForStreamerState:audioStreamer];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self showOverlayView];
}

- (void)viewDidUnload {
  self.reflectionView = nil;
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView  {
  return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section  {	
  return [soundFiles count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath  {    
  static NSString *CellIdentifier = @"Cell";
  
  MDAudioPlayerTableViewCell *cell = (MDAudioPlayerTableViewCell *)[aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[MDAudioPlayerTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
  }
  
  cell.title = [[soundFiles objectAtIndex:indexPath.row] title];
  cell.number = [NSString stringWithFormat:@"%d.", (indexPath.row + 1)];
  cell.duration = [[soundFiles objectAtIndex:indexPath.row] durationInMinutes];
  
  cell.isEven = indexPath.row % 2;
  cell.backgroundColor = [UIColor blackColor];
  
  if (selectedIndex == indexPath.row)
    cell.isSelectedIndex = YES;
  else
    cell.isSelectedIndex = NO;
  
  return cell;
}


- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
  [aTableView deselectRowAtIndexPath:indexPath animated:YES];
  
  selectedIndex = indexPath.row;
  
  for (MDAudioPlayerTableViewCell *cell in [aTableView visibleCells]) {
    cell.isSelectedIndex = NO;
  }
  
  MDAudioPlayerTableViewCell *cell = (MDAudioPlayerTableViewCell *)[aTableView cellForRowAtIndexPath:indexPath];
  cell.isSelectedIndex = YES;
  
  NSError *error = nil;
  
  AudioStreamer *streamer = [[AudioStreamer alloc] initWithURL:[(MDAudio *)[soundFiles objectAtIndex:selectedIndex] url]];
  
  if (error)
    NSLog(@"%@", error);
  
  self.audioStreamer = streamer;
  [streamer release];
  
  [self.audioStreamer start];
  
  [self updateViewForStreamerInfo:self.audioStreamer];
  [self updateViewForStreamerState:self.audioStreamer];
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)indexPath  {
  return NO;
}


- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return 44;
}


#pragma mark - Image Reflection

CGImageRef CreateGradientImage(int pixelsWide, int pixelsHigh) {
  CGImageRef theCGImage = NULL;
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  
  CGContextRef gradientBitmapContext = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh,
                                                             8, 0, colorSpace, kCGImageAlphaNone);
  
  CGFloat colors[] = {0.0, 1.0, 1.0, 1.0};
  
  CGGradientRef grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
  CGColorSpaceRelease(colorSpace);
  
  CGPoint gradientStartPoint = CGPointZero;
  CGPoint gradientEndPoint = CGPointMake(0, pixelsHigh);
  
  CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint,
                              gradientEndPoint, kCGGradientDrawsAfterEndLocation);
  CGGradientRelease(grayScaleGradient);
  
  theCGImage = CGBitmapContextCreateImage(gradientBitmapContext);
  CGContextRelease(gradientBitmapContext);
  
  return theCGImage;
}

CGContextRef MyCreateBitmapContext(int pixelsWide, int pixelsHigh) {
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  
  // create the bitmap context
  CGContextRef bitmapContext = CGBitmapContextCreate (NULL, pixelsWide, pixelsHigh, 8,
                                                      0, colorSpace,
                                                      // this will give us an optimal BGRA format for the device:
                                                      (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
  CGColorSpaceRelease(colorSpace);
  
  return bitmapContext;
}

- (UIImage *)reflectedImage:(UIButton *)fromImage withHeight:(NSUInteger)height {
  if (height == 0)
    return nil;
  
  // create a bitmap graphics context the size of the image
  CGContextRef mainViewContentContext = MyCreateBitmapContext(fromImage.bounds.size.width, height);
  
  CGImageRef gradientMaskImage = CreateGradientImage(1, height);
  
  CGContextClipToMask(mainViewContentContext, CGRectMake(0.0, 0.0, fromImage.bounds.size.width, height), gradientMaskImage);
  CGImageRelease(gradientMaskImage);
  
  CGContextTranslateCTM(mainViewContentContext, 0.0, height);
  CGContextScaleCTM(mainViewContentContext, 1.0, -1.0);
  
  CGContextDrawImage(mainViewContentContext, fromImage.bounds, fromImage.imageView.image.CGImage);
  
  CGImageRef reflectionImage = CGBitmapContextCreateImage(mainViewContentContext);
  CGContextRelease(mainViewContentContext);
  
  UIImage *theImage = [UIImage imageWithCGImage:reflectionImage];
  
  CGImageRelease(reflectionImage);
  
  return theImage;
}

@end
