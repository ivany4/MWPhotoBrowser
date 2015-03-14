//
//  MWPhotoBrowser_Private.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
#import "MWZoomingScrollView.h"
#import "MWPhotoBrowser.h"
#import "MWMediaItem.h"
#import "MWPhotoBrowserPage.h"

// Declare private methods of browser
@interface MWPhotoBrowser (Private)

// Properties
@property (nonatomic) UIActivityViewController *activityViewController;

// Layout
- (void)layoutVisiblePages;
- (void)performLayout;
- (BOOL)presentingViewControllerPrefersStatusBarHidden;

// Nav Bar Appearance
- (void)setNavBarAppearance:(BOOL)animated;
- (void)storePreviousNavBarAppearance;
- (void)restorePreviousNavBarAppearance:(BOOL)animated;

// Paging
- (void)tilePages;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;
- (UIView<MWPhotoBrowserPage> *)pageDisplayedAtIndex:(NSUInteger)index;
- (UIView<MWPhotoBrowserPage> *)pageDisplayingMediaItem:(MWMediaItem *)mediaItem;
- (UIView<MWPhotoBrowserPage> *)dequeueRecycledPageForMediaItem:(MWMediaItem *)mediaItem;
- (void)configurePage:(UIView<MWPhotoBrowserPage> *)page forIndex:(NSUInteger)index withMediaItem:(MWMediaItem *)mediaItem;
- (void)didStartViewingPageAtIndex:(NSUInteger)index;

// Frames
- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;
- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index;
- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation;
- (CGRect)frameForCaptionView:(MWCaptionView *)captionView atIndex:(NSUInteger)index;

// Navigation
- (void)updateNavigation;
- (void)jumpToPageAtIndex:(NSUInteger)index animated:(BOOL)animated;
- (void)gotoPreviousPage;
- (void)gotoNextPage;

// Controls
- (void)cancelControlHiding;
- (void)hideControlsAfterDelay;
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent;
- (void)toggleControls;
- (BOOL)areControlsHidden;

// Data
- (NSUInteger)numberOfMediaItems;
- (MWMediaItem *)mediaItemAtIndex:(NSUInteger)index;
- (void)loadAdjacentMediaItemsIfNecessary:(MWMediaItem *)mediaItem;
- (void)releaseAllUnderlyingPhotos:(BOOL)preserveCurrent;

// Actions
- (void)saveMediaItem;
- (void)copyMediaItem;
- (void)emailMediaItem;

@end

