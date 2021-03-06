//
//  MWVideoPageView.m
//  MWPhotoBrowser
//
//  Created by Ivan on 14/03/15.
//
//

#import "MWVideoPageView.h"
#import "DACircularProgressView.h"
#import "MWPhotoBrowserPrivate.h"
#import <MediaPlayer/MediaPlayer.h>

@interface MWControlsView : UIControl
@property (nonatomic, strong) UILabel *beforeLabel;
@property (nonatomic, strong) UILabel *afterLabel;
@property (nonatomic, strong) UIButton *playbackButton;
@property (nonatomic, strong) UISlider *seekSlider;
@property (nonatomic, strong) NSTimer *seekUpdateTimer;
@property (nonatomic, weak) MPMoviePlayerController *player;

- (instancetype)initWithPlayer:(MPMoviePlayerController *)player;
- (instancetype)initWithFrame:(CGRect)frame player:(MPMoviePlayerController *)player NS_DESIGNATED_INITIALIZER;
@end

@implementation MWControlsView

- (instancetype)initWithPlayer:(MPMoviePlayerController *)player
{
    return [self initWithFrame:CGRectMake(0, 0, [UIApplication sharedApplication].keyWindow.frame.size.width, 50) player:player];
}

- (instancetype)initWithFrame:(CGRect)frame player:(MPMoviePlayerController *)player
{
    if (self = [super initWithFrame:frame]) {
        [self setupWithPlayer:player];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.seekUpdateTimer invalidate];
}

- (void)setupWithPlayer:(MPMoviePlayerController *)player
{
    
    self.player = player;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:MPMoviePlayerPlaybackStateDidChangeNotification object:player];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDuration) name:MPMovieDurationAvailableNotification object:player];
    
    UIButton *playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    playButton.tintColor = [UIColor whiteColor];
    [playButton setImage:[[UIImage imageNamed:@"play"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [playButton addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:playButton];
    self.playbackButton = playButton;
    
    UILabel *beforeLabel = [[UILabel alloc] init];
    beforeLabel.backgroundColor = [UIColor clearColor];
    beforeLabel.textColor = [UIColor whiteColor];
    beforeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    beforeLabel.text = @"00:00";
    [self addSubview:beforeLabel];
    self.beforeLabel = beforeLabel;
    
    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = 0;
    slider.maximumValue = 1;
    slider.value = 0;
    slider.continuous = YES;
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    [slider addTarget:self action:@selector(updateSeek:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:slider];
    self.seekSlider = slider;
    
    UILabel *afterLabel = [[UILabel alloc] init];
    afterLabel.backgroundColor = [UIColor clearColor];
    afterLabel.textColor = [UIColor whiteColor];
    afterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    afterLabel.text = @"00:00";
    [self addSubview:afterLabel];
    self.afterLabel = afterLabel;
    
    UIButton *fullscreenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    fullscreenButton.tintColor = [UIColor whiteColor];
    [fullscreenButton setImage:[[UIImage imageNamed:@"fullscreen"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    fullscreenButton.translatesAutoresizingMaskIntoConstraints = NO;
    [fullscreenButton addTarget:self action:@selector(fullscreen:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:fullscreenButton];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(playButton, beforeLabel, fullscreenButton, afterLabel, slider);
    
    for (UIView *view in self.subviews) {
        [self addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        if (![view isEqual:slider]) {
            [view setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        }
        else {
            [view setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        }
    }
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[playButton]-10-[beforeLabel]-10-[slider]-10-[afterLabel]-10-[fullscreenButton]-10-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    
    
    [self updateDuration];
    [self updateToggleButton];
    
    [self layoutIfNeeded];
}


- (void)updateSeek:(UISlider *)slider
{
    CGFloat frac = slider.value;
    NSTimeInterval time = (self.player.duration-1)*frac;
    self.player.currentPlaybackTime = time;
    [self updateSeekWithSlider:NO];
}

- (void)updateSeek
{
    [self updateSeekWithSlider:YES];
}

- (void)togglePlayback:(id)sender
{
    if (self.player.playbackState == MPMoviePlaybackStatePaused) {
        [self.player play];
    }
    else {
        [self.player pause];
    }
    [self updateToggleButton];
}

- (void)fullscreen:(id)sender
{
    [self.player setFullscreen:YES animated:YES];
}

- (void)updateToggleButton
{
    NSString *name = self.player.playbackState == MPMoviePlaybackStatePaused ? @"play" : @"pause";
    [self.playbackButton setImage:[[UIImage imageNamed:name] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
}

- (void)updateDuration
{
    [self updateSeekWithSlider:YES];
}

- (void)updateSeekWithSlider:(BOOL)withSlider
{
    self.beforeLabel.text = [self formatPlaybackTime:ceil(self.player.currentPlaybackTime)];
    self.afterLabel.text = [self formatPlaybackTime:floor(self.player.duration-self.player.currentPlaybackTime)];
    if (withSlider) {
        CGFloat frac = self.player.duration > 1 ? (self.player.currentPlaybackTime/(self.player.duration-1)) : 0;
        [self.seekSlider setValue:frac animated:NO];
    }
}

- (NSString *)formatPlaybackTime:(NSTimeInterval)time
{
    if (isnan(time) || isinf(time)) time = 0;
    return [NSString stringWithFormat:@"%02.0f:%02d", time/60., (int)time % 60];
}

- (void)playbackStateChanged:(NSNotification *)note
{
    [self updateToggleButton];
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        if (!self.seekUpdateTimer) {
            self.seekUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateSeek) userInfo:nil repeats:YES];
        }
    }
    else {
        [self.seekUpdateTimer invalidate], self.seekUpdateTimer = nil;
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    for (UIView *subview in self.subviews) {
        UIView *hit = [subview hitTest:[subview convertPoint:point fromView:self] withEvent:event];
        if (hit) {
            return hit;
        }
    }
    return nil;
}

@end

@interface MWVideoPageView () <MWTapDetectingViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, weak) MWPhotoBrowser *photoBrowser;
@property (nonatomic, strong) UIImageView *photoImageView;
@property (nonatomic, strong) DACircularProgressView *loadingIndicator;
@property (nonatomic, strong) UIImageView *loadingError;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) MPMoviePlayerController *moviePlayer;
@property (nonatomic, strong) UITapGestureRecognizer *movieTap;
@property (nonatomic, strong) UIPinchGestureRecognizer *moviePinch;
@property (nonatomic, strong) UIPinchGestureRecognizer *fullscreenPinch;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) BOOL hasVideoSize;
@end

@implementation MWVideoPageView
@synthesize mediaItem = _mediaItem;
@synthesize captionView = _captionView;
@synthesize index = _index;

- (id)initWithBrowser:(MWPhotoBrowser *)browser
{
    if ((self = [super init])) {
        
        // Setup
        _index = NSUIntegerMax;
        _photoBrowser = browser;
        
        // Image view
        _photoImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _photoImageView.contentMode = UIViewContentModeScaleAspectFit;
        _photoImageView.backgroundColor = [UIColor blueColor];
        _photoImageView.userInteractionEnabled = NO;
        [self addSubview:_photoImageView];
        
        UIView *dim = [[UIView alloc] initWithFrame:self.bounds];
        dim.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        dim.userInteractionEnabled = NO;
        [self addSubview:dim];
        
        _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _playButton.frame = CGRectMake(0, 0, 150, 150);
        _playButton.tintColor = [UIColor colorWithWhite:1 alpha:0.5];
        [_playButton setImage:[[UIImage imageNamed:@"play_big"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        [_playButton setImage:[UIImage imageNamed:@"play_big"] forState:UIControlStateHighlighted];
        _playButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        [_playButton addTarget:self action:@selector(playVideo:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_playButton];
              
        
        
        // Loading indicator
        _loadingIndicator = [[DACircularProgressView alloc] initWithFrame:CGRectMake(140.0f, 30.0f, 40.0f, 40.0f)];
        _loadingIndicator.userInteractionEnabled = NO;
        _loadingIndicator.thicknessRatio = 0.1;
        _loadingIndicator.roundedCorners = NO;
        _loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
        [self addSubview:_loadingIndicator];
        
        
        
        
        
        
        
        // Listen progress notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setProgressFromNotification:)
                                                     name:MWPHOTO_PROGRESS_NOTIFICATION
                                                   object:nil];
        
        
        
        
        
        
        // Setup
        self.tapDelegate = self;
        self.backgroundColor = [UIColor redColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.moviePlayer) {
        [self.moviePlayer stop];
    }
    
    if (self.fullscreenPinch) {
        [self detachFullscreenGestureRecognizer];
        self.fullscreenPinch = nil;
    }
}

- (void)prepareForReuse
{
    [self hideImageFailure];
    self.mediaItem = nil;
    self.captionView = nil;
    _photoImageView.image = nil;
    _index = NSUIntegerMax;
    self.hasVideoSize = NO;
    self.movieTap = nil;
    self.moviePinch = nil;
    if (self.fullscreenPinch) {
        [self detachFullscreenGestureRecognizer];
        self.fullscreenPinch = nil;
    }
    [self.captionView removeCustomConstrols];
    if (self.moviePlayer) {
        [self.moviePlayer stop];
        [self.moviePlayer.view removeFromSuperview];
        self.moviePlayer = nil;
        
        _photoImageView.hidden = self.playButton.hidden = NO;
    }
}

- (void)updateLayoutForCurrentBounds
{
    
}

- (void)pausePlayback
{
    [self.moviePlayer pause];
}

#pragma mark - Image

- (void)setMediaItem:(MWMediaItem *)mediaItem {
    // Cancel any loading on old photo
    if (_mediaItem && mediaItem == nil) {
        if ([_mediaItem respondsToSelector:@selector(cancelAnyLoading)]) {
            [_mediaItem cancelAnyLoading];
        }
    }
    _mediaItem = mediaItem;
    UIImage *img = [_mediaItem retrieveImage];
    if (img) {
        [self displayContent];
    } else {
        // Will be loading so show loading
        [self showLoadingIndicator];
    }
}


// Get and display image
- (void)displayContent
{
    if (_mediaItem && _photoImageView.image == nil) {
        
        // Get image from browser as it handles ordering of fetching
        UIImage *img = [_mediaItem retrieveImage];
        if (img) {
            
            // Hide indicator
            [self hideLoadingIndicator];
            
            // Set image
            _photoImageView.image = img;
            
            _photoImageView.frame = [self frameForViewWithContentSize:img.size];
            
        } else {
            
            // Failed no image
            [self displayContentFailure];
            
        }
        [self setNeedsLayout];
    }
}

- (CGRect)frameFittingInBounds:(CGRect)origFrame
{
    CGFloat hMargin = (self.bounds.size.width - origFrame.size.width)/2.;
    CGFloat vMargin = (self.bounds.size.height - origFrame.size.height)/2.;
    origFrame.origin = CGPointMake(hMargin, vMargin);
    return CGRectIntegral(origFrame);
}

- (CGRect)frameForViewWithContentSize:(CGSize)size
{
    CGRect fullSizeRect = CGRectZero;
    fullSizeRect.size = size;
    
    CGFloat hScale = self.bounds.size.width/fullSizeRect.size.width;
    CGFloat vScale = self.bounds.size.height/fullSizeRect.size.height;
    
    CGFloat scale = 1;
    
    if (hScale >= 1 && vScale >= 1) {
        return [self frameFittingInBounds:fullSizeRect];
    }
    else {
        scale = MIN(hScale, vScale);
        CGRect newFrame = fullSizeRect;
        newFrame.size.width *= scale;
        newFrame.size.height *= scale;
        return [self frameFittingInBounds:newFrame];
    }
}



- (void)displayContentFailure
{
    [self hideLoadingIndicator];
    _photoImageView.image = nil;
    if (!_loadingError) {
        _loadingError = [UIImageView new];
        _loadingError.image = [UIImage imageNamed:@"MWPhotoBrowser.bundle/images/ImageError.png"];
        _loadingError.userInteractionEnabled = NO;
        _loadingError.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
        [_loadingError sizeToFit];
        [self addSubview:_loadingError];
    }
    _loadingError.frame = CGRectMake(floorf((self.bounds.size.width - _loadingError.frame.size.width) / 2.),
                                     floorf((self.bounds.size.height - _loadingError.frame.size.height) / 2),
                                     _loadingError.frame.size.width,
                                     _loadingError.frame.size.height);    
}

- (void)hideImageFailure {
    if (_loadingError) {
        [_loadingError removeFromSuperview];
        _loadingError = nil;
    }
}

#pragma mark - Loading Progress

- (void)setProgressFromNotification:(NSNotification *)notification {
    NSDictionary *dict = [notification object];
    MWMediaItem *mediaItemWithProgress = [dict objectForKey:@"mediaItem"];
    if (mediaItemWithProgress == self.mediaItem) {
        float progress = [[dict valueForKey:@"progress"] floatValue];
        _loadingIndicator.progress = MAX(MIN(1, progress), 0);
    }
}

- (void)hideLoadingIndicator {
    _loadingIndicator.hidden = YES;
}

- (void)showLoadingIndicator {
    _loadingIndicator.progress = 0;
    _loadingIndicator.hidden = NO;
    [self hideImageFailure];
}


- (void)layoutSubviews {
    
    // Position indicators (centre does not seem to work!)
    if (!_loadingIndicator.hidden)
        _loadingIndicator.frame = CGRectMake(floorf((self.bounds.size.width - _loadingIndicator.frame.size.width) / 2.),
                                             floorf((self.bounds.size.height - _loadingIndicator.frame.size.height) / 2),
                                             _loadingIndicator.frame.size.width,
                                             _loadingIndicator.frame.size.height);
    if (_loadingError)
        _loadingError.frame = CGRectMake(floorf((self.bounds.size.width - _loadingError.frame.size.width) / 2.),
                                         floorf((self.bounds.size.height - _loadingError.frame.size.height) / 2),
                                         _loadingError.frame.size.width,
                                         _loadingError.frame.size.height);
    
    _photoImageView.frame = [self frameForViewWithContentSize:_photoImageView.image.size];

    if (self.moviePlayer) {
        [self layoutVideoFrame];
    }
    
    // Super
    [super layoutSubviews];
}

- (void)layoutVideoFrame
{
    if (self.hasVideoSize) {
        self.moviePlayer.view.frame = [self frameForViewWithContentSize:self.videoSize];
    }
    else {
        self.moviePlayer.view.frame = _photoImageView.frame;
    }
}


#pragma mark - Video playback

- (void)playVideo:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://www.ebookfrenzy.com/ios_book/movie/movie.mov"];
    
    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieNaturalSizeAvailable:) name:MPMovieNaturalSizeAvailableNotification object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detachGestureRecognizer) name:MPMoviePlayerWillEnterFullscreenNotification object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(attachGestureRecognizer) name:MPMoviePlayerDidExitFullscreenNotification object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(attachFullscreenGestureRecognizer) name:MPMoviePlayerDidEnterFullscreenNotification object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detachFullscreenGestureRecognizer) name:MPMoviePlayerWillExitFullscreenNotification object:self.moviePlayer];
    
    self.moviePlayer.shouldAutoplay = YES;
    self.moviePlayer.view.translatesAutoresizingMaskIntoConstraints = YES;
    [self insertSubview:self.moviePlayer.view aboveSubview:self.playButton];
    [self layoutVideoFrame];
    
    //Remove native pinches
    for (UIView *view in self.moviePlayer.view.subviews) {
        for (UIPinchGestureRecognizer *pinch in view.gestureRecognizers) {
            if ([pinch isKindOfClass:[UIPinchGestureRecognizer class]]) {
                [pinch.view removeGestureRecognizer:pinch];
            }
        }
    }
    
    
    [self attachGestureRecognizer];
    _photoImageView.hidden = self.playButton.hidden = YES;
    
    [self.moviePlayer prepareToPlay];
    [self.moviePlayer play];
    
    [self.captionView accommodateCustomControls:[[MWControlsView alloc] initWithPlayer:self.moviePlayer]];
    self.captionView.frame = [_photoBrowser frameForCaptionView:self.captionView atIndex:self.index];
    [self.captionView setNeedsLayout];
}

- (void)moviePlayBackDidFinish:(NSNotification*)notification
{
    MPMoviePlayerController *player = [notification object];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:player];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMovieNaturalSizeAvailableNotification object:player];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerWillEnterFullscreenNotification object:player];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidExitFullscreenNotification object:player];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerDidEnterFullscreenNotification object:player];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerWillExitFullscreenNotification object:player];
    [player.view removeFromSuperview];
    self.moviePlayer = nil;
    self.hasVideoSize = NO;
    [self.captionView removeCustomConstrols];
    self.captionView.frame = [_photoBrowser frameForCaptionView:self.captionView atIndex:self.index];
    
    _photoImageView.hidden = self.playButton.hidden = NO;
}

- (void)movieNaturalSizeAvailable:(NSNotification*)notification
{
    MPMoviePlayerController *player = [notification object];
    self.videoSize = player.naturalSize;
    self.hasVideoSize = YES;
    [self layoutVideoFrame];
}

- (void)attachGestureRecognizer
{
    if (!self.movieTap) {
        self.movieTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(movieTapped:)];
        self.movieTap.numberOfTapsRequired = 1;
    }
    if (!self.moviePinch) {
        self.moviePinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(moviePinched:)];
    }
    [self.moviePlayer.view addGestureRecognizer:self.movieTap];
    [self.moviePlayer.view addGestureRecognizer:self.moviePinch];
    self.moviePlayer.controlStyle = MPMovieControlStyleNone;
}

- (void)detachGestureRecognizer
{
    [self.moviePlayer.view removeGestureRecognizer:self.movieTap];
    [self.moviePlayer.view removeGestureRecognizer:self.moviePinch];
    self.moviePlayer.controlStyle = MPMovieControlStyleFullscreen;
}

//Because none controls disable pinch gestures

- (void)attachFullscreenGestureRecognizer
{
    if (!self.fullscreenPinch) {
        self.fullscreenPinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(moviePinched:)];
    }
    [[self fullscreenGestureContainer] addGestureRecognizer:self.fullscreenPinch];
}

- (void)detachFullscreenGestureRecognizer
{
    [[self fullscreenGestureContainer] removeGestureRecognizer:self.fullscreenPinch];
}

- (UIView *)fullscreenGestureContainer
{
    return [[[[UIApplication sharedApplication] windows] lastObject] subviews][0];
}

#pragma mark - Tap handling

- (void)moviePinched:(UIPinchGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if ([recognizer isEqual:self.moviePinch]) {
            if (recognizer.velocity >= 5) {
                [self.moviePlayer setFullscreen:YES animated:YES];
            }
        }
        else if ([recognizer isEqual:self.fullscreenPinch]) {
            if (recognizer.velocity <= -5) {
                [self.moviePlayer setFullscreen:NO animated:YES];
            }
        }
    }
}

- (void)movieTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self handleTap];
    }
}

- (void)view:(UIView *)view singleTapDetected:(UITouch *)touch
{
    [self handleTap];
}

- (void)handleTap
{
    [_photoBrowser performSelector:@selector(toggleControls) withObject:nil afterDelay:0.2];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}
// this enables you to handle multiple recognizers on single view
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}


@end
