//
//  MWPhotoBrowser.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "MWMediaItem.h"
#import "MWCaptionView.h"

// Debug Logging
#if 0 // Set to 1 to enable debug logging
#define MWLog(x, ...) NSLog(x, ## __VA_ARGS__);
#else
#define MWLog(x, ...)
#endif

@class MWPhotoBrowser;

@protocol MWPhotoBrowserDelegate <NSObject>

- (NSUInteger)numberOfMediaItemsInBrowser:(MWPhotoBrowser *)browser;
- (MWMediaItem *)browser:(MWPhotoBrowser *)browser mediaItemAtIndex:(NSUInteger)index;

@optional

- (MWCaptionView *)browser:(MWPhotoBrowser *)browser captionViewForMediaItemAtIndex:(NSUInteger)index;
- (NSString *)browser:(MWPhotoBrowser *)browser titleForMediaItemAtIndex:(NSUInteger)index;
- (void)browser:(MWPhotoBrowser *)browser didDisplayMediaItemAtIndex:(NSUInteger)index;
- (void)browser:(MWPhotoBrowser *)browser actionButtonPressedForMediaItemAtIndex:(NSUInteger)index;
- (void)browserDidFinishModalPresentation:(MWPhotoBrowser *)browser;

@end

@interface MWPhotoBrowser : UIViewController <UIScrollViewDelegate, UIActionSheetDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, weak) IBOutlet id<MWPhotoBrowserDelegate> delegate;
@property (nonatomic) BOOL zoomPhotosToFill;
@property (nonatomic) BOOL displayNavArrows;
@property (nonatomic) BOOL displayActionButton;
@property (nonatomic) BOOL alwaysShowControls;
@property (nonatomic) BOOL enableSwipeToDismiss;
@property (nonatomic) NSUInteger delayToHideElements;
@property (nonatomic, readonly) NSUInteger currentIndex;

// Init
- (id)initWithDelegate:(id <MWPhotoBrowserDelegate>)delegate;

// Reloads the browser and refetches data
- (void)reloadData;

// Set page that photo browser starts on
- (void)setCurrentMediaItemIndex:(NSUInteger)index;

// Navigation
- (void)showNextMediaItemAnimated:(BOOL)animated;
- (void)showPreviousMediaItemAnimated:(BOOL)animated;

@end
