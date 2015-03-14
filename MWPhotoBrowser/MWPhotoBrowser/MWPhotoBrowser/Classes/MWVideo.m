//
//  MWVideo.m
//  MWPhotoBrowser
//
//  Created by IVANY4 on 2015-03-14.
//
//

#import "MWVideo.h"
#import <MediaPlayer/MediaPlayer.h>

@interface MWVideo ()
@property (nonatomic, strong) MPMoviePlayerController *moviePlayer;
@property (nonatomic, weak) UIView *containerView;
@end

@implementation MWVideo

- (instancetype)initWithURL:(NSURL *)URL
{
    if (self = [super initWithURL:URL]) {
        self.isVideo = YES;
    }
    return self;
}

- (UIView *)overlayView
{
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    //FIXME: Solve problem with passing touches through
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 200, 200);
    button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    [button setTitle:@"PLAY" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
    [button addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:button];
    
    return view;
}

- (void)mediaItemDidAriveToView:(UIView *)view
{
    self.containerView = view;
}

- (void)mediaItemStartedDragging
{
    if (self.moviePlayer) {
        [self.moviePlayer stop];
    }
}

- (void)play:(id)sender
{
//    [[[UIAlertView alloc] initWithTitle:@"PLAY" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    
    NSURL *url = [NSURL URLWithString:
                  @"http://www.ebookfrenzy.com/ios_book/movie/movie.mov"];
    
    self.moviePlayer = [[MPMoviePlayerController alloc]
                     initWithContentURL:url];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:self.moviePlayer];
    
    self.moviePlayer.controlStyle = MPMovieControlStyleEmbedded;
    self.moviePlayer.shouldAutoplay = YES;
    UIView *parentWindow = self.containerView;//[UIApplication sharedApplication].keyWindow;
    [parentWindow addSubview:self.moviePlayer.view];
    
    self.moviePlayer.view.frame = parentWindow.bounds;
    [self.moviePlayer setFullscreen:YES animated:YES];
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification {
    MPMoviePlayerController *player = [notification object];
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:MPMoviePlayerPlaybackDidFinishNotification
     object:player];
    
    if ([player
         respondsToSelector:@selector(setFullscreen:animated:)])
    {
        [player.view removeFromSuperview];
    }
}
@end
