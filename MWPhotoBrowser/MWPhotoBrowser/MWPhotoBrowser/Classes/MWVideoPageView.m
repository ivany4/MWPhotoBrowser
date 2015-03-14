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

@interface MWVideoPageView () <MWTapDetectingViewDelegate>
@property (nonatomic, weak) MWPhotoBrowser *photoBrowser;
@property (nonatomic, strong) UIImageView *photoImageView;
@property (nonatomic, strong) DACircularProgressView *loadingIndicator;
@property (nonatomic, strong) UIImageView *loadingError;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) MPMoviePlayerController *moviePlayer;
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
        _photoImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _photoImageView.contentMode = UIViewContentModeCenter;
        _photoImageView.backgroundColor = [UIColor blackColor];
        _photoImageView.userInteractionEnabled = NO;
        [self addSubview:_photoImageView];
        
        
        _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _playButton.frame = CGRectMake(0, 0, 200, 200);
        _playButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        [_playButton setTitle:@"PLAY" forState:UIControlStateNormal];
        [_playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _playButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
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
        self.backgroundColor = [UIColor blackColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)prepareForReuse
{
    [self hideImageFailure];
    self.mediaItem = nil;
    self.captionView = nil;
    _photoImageView.image = nil;
    _index = NSUIntegerMax;
    if (self.moviePlayer) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
        [self.moviePlayer.view removeFromSuperview], self.moviePlayer = nil;
    }
}

- (void)updateLayoutForCurrentBounds
{
    
}

- (void)pausePlayback
{
    [self.moviePlayer pause];
}

// Get and display image
- (void)displayContent
{
    if (_mediaItem && _photoImageView.image == nil) {
        
        // Get image from browser as it handles ordering of fetching
        UIImage *img = [_photoBrowser imageForMediaItem:_mediaItem];
        if (img) {
            
            // Hide indicator
            [self hideLoadingIndicator];
            
            // Set image
            _photoImageView.image = img;
            _photoImageView.hidden = NO;
            
            // Setup photo frame
            CGRect photoImageViewFrame;
            photoImageViewFrame.origin = CGPointZero;
            photoImageViewFrame.size = img.size;
            _photoImageView.frame = photoImageViewFrame;
            
        } else {
            
            // Failed no image
            [self displayContentFailure];
            
        }
        [self setNeedsLayout];
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

#pragma mark - Video playback

- (void)playVideo:(id)sender
{
    //    [[[UIAlertView alloc] initWithTitle:@"PLAY" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    
    NSURL *url = [NSURL URLWithString:
                  @"http://www.ebookfrenzy.com/ios_book/movie/movie.mov"];
    
    self.moviePlayer = [[MPMoviePlayerController alloc]
                        initWithContentURL:url];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
    
    self.moviePlayer.controlStyle = MPMovieControlStyleEmbedded;
    self.moviePlayer.shouldAutoplay = YES;
    [self insertSubview:self.moviePlayer.view aboveSubview:self.playButton];
    self.moviePlayer.view.frame = _photoImageView.bounds;
    [self.moviePlayer setFullscreen:YES animated:YES];
}

- (void)moviePlayBackDidFinish:(NSNotification*)notification
{
    MPMoviePlayerController *player = [notification object];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:player];
    
    if ([player respondsToSelector:@selector(setFullscreen:animated:)]) {
        [player.view removeFromSuperview];
    }
    self.moviePlayer = nil;
}

#pragma mark - Tap handling


- (void)view:(UIView *)view singleTapDetected:(UITouch *)touch
{
    [_photoBrowser performSelector:@selector(toggleControls) withObject:nil afterDelay:0.2];
}


@end
