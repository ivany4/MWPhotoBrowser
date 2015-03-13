//
//  MWPhotoBrowser.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MWCommon.h"
#import "MWPhotoBrowser.h"
#import "MWPhotoBrowserPrivate.h"
#import "SDImageCache.h"

#define PADDING                  10
#define ACTION_SHEET_OLD_ACTIONS 2000

@implementation MWPhotoBrowser

#pragma mark - Init

- (id)init {
    if ((self = [super init])) {
        [self _initialisation];
    }
    return self;
}

- (id)initWithDelegate:(id <MWPhotoBrowserDelegate>)delegate {
    if ((self = [self init])) {
        _delegate = delegate;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super initWithCoder:decoder])) {
        [self _initialisation];
	}
	return self;
}

- (void)_initialisation {
    
    // Defaults
    NSNumber *isVCBasedStatusBarAppearanceNum = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"];
    if (isVCBasedStatusBarAppearanceNum) {
        _isVCBasedStatusBarAppearance = isVCBasedStatusBarAppearanceNum.boolValue;
    } else {
        _isVCBasedStatusBarAppearance = YES; // default
    }
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    if (SYSTEM_VERSION_LESS_THAN(@"7")) self.wantsFullScreenLayout = YES;
#endif
    self.hidesBottomBarWhenPushed = YES;
    _hasBelongedToViewController = NO;
    _mediaItemCount = NSNotFound;
    _previousLayoutBounds = CGRectZero;
    _currentPageIndex = 0;
    _previousPageIndex = NSUIntegerMax;
    _displayActionButton = YES;
    _displayNavArrows = NO;
    _zoomPhotosToFill = YES;
    _performingLayout = NO; // Reset on view did appear
    _rotating = NO;
    _viewIsActive = NO;
    _enableSwipeToDismiss = YES;
    _delayToHideElements = 5;
    _visiblePages = [[NSMutableSet alloc] init];
    _recycledPages = [[NSMutableSet alloc] init];
    _mediaItems = [[NSMutableArray alloc] init];
    _didSavePreviousStateOfNavBar = NO;
    if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)]){
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    // Listen for MWPhoto notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMWPhotoLoadingDidEndNotification:)
                                                 name:MWPHOTO_LOADING_DID_END_NOTIFICATION
                                               object:nil];
    
}

- (void)dealloc {
    _pagingScrollView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self releaseAllUnderlyingPhotos:NO];
    [[SDImageCache sharedImageCache] clearMemory]; // clear memory
}

- (void)releaseAllUnderlyingPhotos:(BOOL)preserveCurrent {
    // Create a copy in case this array is modified while we are looping through
    // Release photos
    NSArray *copy = [_mediaItems copy];
    for (id p in copy) {
        if (p != [NSNull null]) {
            if (preserveCurrent && p == [self mediaItemAtIndex:self.currentIndex]) {
                continue; // skip current
            }
            [p unloadUnderlyingImage];
        }
    }
}

- (void)didReceiveMemoryWarning {

	// Release any cached data, images, etc that aren't in use.
    [self releaseAllUnderlyingPhotos:YES];
	[_recycledPages removeAllObjects];
	
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
}

#pragma mark - View Loading

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    
	// View
	self.view.backgroundColor = [UIColor blackColor];
    self.view.clipsToBounds = YES;
	
	// Setup paging scrolling view
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
	_pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
	_pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_pagingScrollView.pagingEnabled = YES;
	_pagingScrollView.delegate = self;
	_pagingScrollView.showsHorizontalScrollIndicator = NO;
	_pagingScrollView.showsVerticalScrollIndicator = NO;
	_pagingScrollView.backgroundColor = [UIColor blackColor];
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	[self.view addSubview:_pagingScrollView];
	
    // Toolbar
    _toolbar = [[UIToolbar alloc] initWithFrame:[self frameForToolbarAtOrientation:self.interfaceOrientation]];
    _toolbar.tintColor = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7") ? [UIColor whiteColor] : nil;
    if ([_toolbar respondsToSelector:@selector(setBarTintColor:)]) {
        _toolbar.barTintColor = nil;
    }
    if ([[UIToolbar class] respondsToSelector:@selector(appearance)]) {
        [_toolbar setBackgroundImage:nil forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
        [_toolbar setBackgroundImage:nil forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsLandscapePhone];
    }
    _toolbar.barStyle = UIBarStyleBlackTranslucent;
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    
    // Toolbar Items
    if (self.displayNavArrows) {
        NSString *arrowPathFormat;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7")) {
            arrowPathFormat = @"MWPhotoBrowser.bundle/images/UIBarButtonItemArrowOutline%@.png";
        } else {
            arrowPathFormat = @"MWPhotoBrowser.bundle/images/UIBarButtonItemArrow%@.png";
        }
        _previousButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:arrowPathFormat, @"Left"]] style:UIBarButtonItemStylePlain target:self action:@selector(gotoPreviousPage)];
        _nextButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:arrowPathFormat, @"Right"]] style:UIBarButtonItemStylePlain target:self action:@selector(gotoNextPage)];
    }
    if (self.displayActionButton) {
        _actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
    }
    
    // Update
    [self reloadData];
    
    // Swipe to dismiss
    if (_enableSwipeToDismiss) {
        UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(doneButtonPressed:)];
        swipeGesture.direction = UISwipeGestureRecognizerDirectionDown | UISwipeGestureRecognizerDirectionUp;
        [self.view addGestureRecognizer:swipeGesture];
    }
    
	// Super
    [super viewDidLoad];
	
}

- (void)performLayout {
    
    // Setup
    _performingLayout = YES;
    NSUInteger numberOfMediaItems = [self numberOfPhotos];
    
	// Setup pages
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];
    
    // Navigation buttons
    if ([self.navigationController.viewControllers objectAtIndex:0] == self) {
        // We're first on stack so show done button
        _doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStylePlain target:self action:@selector(doneButtonPressed:)];
        // Set appearance
        if ([UIBarButtonItem respondsToSelector:@selector(appearance)]) {
            [_doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [_doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
            [_doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [_doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
            [_doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateNormal];
            [_doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateHighlighted];
        }
        self.navigationItem.rightBarButtonItem = _doneButton;
    } else {
        // We're not first so show back button
        UIViewController *previousViewController = [self.navigationController.viewControllers objectAtIndex:self.navigationController.viewControllers.count-2];
        NSString *backButtonTitle = previousViewController.navigationItem.backBarButtonItem ? previousViewController.navigationItem.backBarButtonItem.title : previousViewController.title;
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:backButtonTitle style:UIBarButtonItemStylePlain target:nil action:nil];
        // Appearance
        if ([UIBarButtonItem respondsToSelector:@selector(appearance)]) {
            [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
            [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [newBackButton setBackButtonBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
            [newBackButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateNormal];
            [newBackButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateHighlighted];
        }
        _previousViewControllerBackButton = previousViewController.navigationItem.backBarButtonItem; // remember previous
        previousViewController.navigationItem.backBarButtonItem = newBackButton;
    }

    // Toolbar items
    BOOL hasItems = NO;
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpace.width = 32; // To balance action button
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    NSMutableArray *items = [[NSMutableArray alloc] init];

    [items addObject:fixedSpace];

    // Middle - Nav
    if (_previousButton && _nextButton && numberOfMediaItems > 1) {
        hasItems = YES;
        [items addObject:flexSpace];
        [items addObject:_previousButton];
        [items addObject:flexSpace];
        [items addObject:_nextButton];
        [items addObject:flexSpace];
    } else {
        [items addObject:flexSpace];
    }

    // Right - Action
    if (_actionButton && !(!hasItems && !self.navigationItem.rightBarButtonItem)) {
        [items addObject:_actionButton];
    } else {
        // We're not showing the toolbar so try and show in top right
        if (_actionButton)
            self.navigationItem.rightBarButtonItem = _actionButton;
        [items addObject:fixedSpace];
    }

    // Toolbar visibility
    [_toolbar setItems:items];
    BOOL hideToolbar = YES;
    for (UIBarButtonItem* item in _toolbar.items) {
        if (item != fixedSpace && item != flexSpace) {
            hideToolbar = NO;
            break;
        }
    }
    if (hideToolbar) {
        [_toolbar removeFromSuperview];
    } else {
        [self.view addSubview:_toolbar];
    }
    
    // Update nav
	[self updateNavigation];
    
    // Content offset
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:_currentPageIndex];
    [self tilePages];
    _performingLayout = NO;
    
}

- (BOOL)presentingViewControllerPrefersStatusBarHidden {
    UIViewController *presenting = self.presentingViewController;
    if (presenting) {
        if ([presenting isKindOfClass:[UINavigationController class]]) {
            presenting = [(UINavigationController *)presenting topViewController];
        }
    } else {
        // We're in a navigation controller so get previous one!
        if (self.navigationController && self.navigationController.viewControllers.count > 1) {
            presenting = [self.navigationController.viewControllers objectAtIndex:self.navigationController.viewControllers.count-2];
        }
    }
    if (presenting) {
        return [presenting prefersStatusBarHidden];
    } else {
        return NO;
    }
}

#pragma mark - Appearance

- (void)viewWillAppear:(BOOL)animated {
    
	// Super
	[super viewWillAppear:animated];
    
    // Status bar
    if ([UIViewController instancesRespondToSelector:@selector(prefersStatusBarHidden)]) {
        _leaveStatusBarAlone = [self presentingViewControllerPrefersStatusBarHidden];
    } else {
        _leaveStatusBarAlone = [UIApplication sharedApplication].statusBarHidden;
    }
    if (CGRectEqualToRect([[UIApplication sharedApplication] statusBarFrame], CGRectZero)) {
        // If the frame is zero then definitely leave it alone
        _leaveStatusBarAlone = YES;
    }
    if (!_leaveStatusBarAlone && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        _previousStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:animated];
    }
    
    // Navigation bar appearance
    if (!_viewIsActive && [self.navigationController.viewControllers objectAtIndex:0] != self) {
        [self storePreviousNavBarAppearance];
    }
    [self setNavBarAppearance:animated];
    
    // Update UI
//	[self hideControlsAfterDelay];
    
    // Initial appearance
    if (!_viewHasAppearedInitially) {
        _viewHasAppearedInitially = YES;
    }

}

- (void)viewWillDisappear:(BOOL)animated {
    
    // Check that we're being popped for good
    if ([self.navigationController.viewControllers objectAtIndex:0] != self &&
        ![self.navigationController.viewControllers containsObject:self]) {
        
        // State
        _viewIsActive = NO;
        
        // Bar state / appearance
        [self restorePreviousNavBarAppearance:animated];
        
    }
    
    // Controls
    [self.navigationController.navigationBar.layer removeAllAnimations]; // Stop all animations on nav bar
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // Cancel any pending toggles from taps
    [self setControlsHidden:NO animated:NO permanent:YES];
    
    // Status bar
    if (!_leaveStatusBarAlone && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:animated];
    }
    
	// Super
	[super viewWillDisappear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewIsActive = YES;
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    if (parent && _hasBelongedToViewController) {
        [NSException raise:@"MWPhotoBrowser Instance Reuse" format:@"MWPhotoBrowser instances cannot be reused."];
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (!parent) _hasBelongedToViewController = YES;
}

#pragma mark - Nav Bar Appearance

- (void)setNavBarAppearance:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.tintColor = [UIColor whiteColor];
    if ([navBar respondsToSelector:@selector(setBarTintColor:)]) {
        navBar.barTintColor = nil;
        navBar.shadowImage = nil;
    }
    navBar.translucent = YES;
    navBar.barStyle = UIBarStyleBlackTranslucent;
    if ([[UINavigationBar class] respondsToSelector:@selector(appearance)]) {
        [navBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        [navBar setBackgroundImage:nil forBarMetrics:UIBarMetricsLandscapePhone];
    }
}

- (void)storePreviousNavBarAppearance {
    _didSavePreviousStateOfNavBar = YES;
    if ([UINavigationBar instancesRespondToSelector:@selector(barTintColor)]) {
        _previousNavBarBarTintColor = self.navigationController.navigationBar.barTintColor;
    }
    _previousNavBarTranslucent = self.navigationController.navigationBar.translucent;
    _previousNavBarTintColor = self.navigationController.navigationBar.tintColor;
    _previousNavBarHidden = self.navigationController.navigationBarHidden;
    _previousNavBarStyle = self.navigationController.navigationBar.barStyle;
    if ([[UINavigationBar class] respondsToSelector:@selector(appearance)]) {
        _previousNavigationBarBackgroundImageDefault = [self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsDefault];
        _previousNavigationBarBackgroundImageLandscapePhone = [self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsLandscapePhone];
    }
}

- (void)restorePreviousNavBarAppearance:(BOOL)animated {
    if (_didSavePreviousStateOfNavBar) {
        [self.navigationController setNavigationBarHidden:_previousNavBarHidden animated:animated];
        UINavigationBar *navBar = self.navigationController.navigationBar;
        navBar.tintColor = _previousNavBarTintColor;
        navBar.translucent = _previousNavBarTranslucent;
        if ([UINavigationBar instancesRespondToSelector:@selector(barTintColor)]) {
            navBar.barTintColor = _previousNavBarBarTintColor;
        }
        navBar.barStyle = _previousNavBarStyle;
        if ([[UINavigationBar class] respondsToSelector:@selector(appearance)]) {
            [navBar setBackgroundImage:_previousNavigationBarBackgroundImageDefault forBarMetrics:UIBarMetricsDefault];
            [navBar setBackgroundImage:_previousNavigationBarBackgroundImageLandscapePhone forBarMetrics:UIBarMetricsLandscapePhone];
        }
        // Restore back button if we need to
        if (_previousViewControllerBackButton) {
            UIViewController *previousViewController = [self.navigationController topViewController]; // We've disappeared so previous is now top
            previousViewController.navigationItem.backBarButtonItem = _previousViewControllerBackButton;
            _previousViewControllerBackButton = nil;
        }
    }
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutVisiblePages];
}

- (void)layoutVisiblePages {
    
	// Flag
	_performingLayout = YES;
	
	// Toolbar
	_toolbar.frame = [self frameForToolbarAtOrientation:self.interfaceOrientation];
    
	// Remember index
	NSUInteger indexPriorToLayout = _currentPageIndex;
	
	// Get paging scroll view frame to determine if anything needs changing
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    
	// Frame needs changing
    if (!_skipNextPagingScrollViewPositioning) {
        _pagingScrollView.frame = pagingScrollViewFrame;
    }
    _skipNextPagingScrollViewPositioning = NO;
	
	// Recalculate contentSize based on current orientation
	_pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	
	// Adjust frames and configuration of each visible page
	for (MWZoomingScrollView *page in _visiblePages) {
        NSUInteger index = page.index;
		page.frame = [self frameForPageAtIndex:index];
        if (page.captionView) {
            page.captionView.frame = [self frameForCaptionView:page.captionView atIndex:index];
        }
        if (page.selectedButton) {
            page.selectedButton.frame = [self frameForSelectedButton:page.selectedButton atIndex:index];
        }
        
        // Adjust scales if bounds has changed since last time
        if (!CGRectEqualToRect(_previousLayoutBounds, self.view.bounds)) {
            // Update zooms for new bounds
            [page setMaxMinZoomScalesForCurrentBounds];
            _previousLayoutBounds = self.view.bounds;
        }

	}
	
	// Adjust contentOffset to preserve page location based on values collected prior to location
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:indexPriorToLayout];
	[self didStartViewingPageAtIndex:_currentPageIndex]; // initial
    
	// Reset
	_currentPageIndex = indexPriorToLayout;
	_performingLayout = NO;
    
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
	// Remember page index before rotation
	_pageIndexBeforeRotation = _currentPageIndex;
	_rotating = YES;
    
    // In iOS 7 the nav bar gets shown after rotation, but might as well do this for everything!
    if ([self areControlsHidden]) {
        // Force hidden
        self.navigationController.navigationBarHidden = YES;
    }
	
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	
	// Perform layout
	_currentPageIndex = _pageIndexBeforeRotation;
	
	// Delay control holding
//	[self hideControlsAfterDelay];
    
    // Layout
    [self layoutVisiblePages];
	
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	_rotating = NO;
    // Ensure nav bar isn't re-displayed
    if ([self areControlsHidden]) {
        self.navigationController.navigationBarHidden = NO;
        self.navigationController.navigationBar.alpha = 0;
    }
}

#pragma mark - Data

- (NSUInteger)currentIndex {
    return _currentPageIndex;
}

- (void)reloadData {
    
    // Reset
    _mediaItemCount = NSNotFound;
    
    // Get data
    NSUInteger numberOfMediaItems = [self numberOfPhotos];
    [self releaseAllUnderlyingPhotos:YES];
    [_mediaItems removeAllObjects];
    for (int i = 0; i < numberOfMediaItems; i++) {
        [_mediaItems addObject:[NSNull null]];
    }

    // Update current page index
    if (numberOfMediaItems > 0) {
        _currentPageIndex = MAX(0, MIN(_currentPageIndex, numberOfMediaItems - 1));
    } else {
        _currentPageIndex = 0;
    }
    
    // Update layout
    if ([self isViewLoaded]) {
        while (_pagingScrollView.subviews.count) {
            [[_pagingScrollView.subviews lastObject] removeFromSuperview];
        }
        [self performLayout];
        [self.view setNeedsLayout];
    }
    
}

- (NSUInteger)numberOfPhotos {
    if (_mediaItemCount == NSNotFound) {
        if ([_delegate respondsToSelector:@selector(numberOfMediaItemsInBrowser:)]) {
            _mediaItemCount = [_delegate numberOfMediaItemsInBrowser:self];
        }
    }
    if (_mediaItemCount == NSNotFound) _mediaItemCount = 0;
    return _mediaItemCount;
}

- (MWMediaItem *)mediaItemAtIndex:(NSUInteger)index {
    MWMediaItem *mediaItem = nil;
    if (index < _mediaItems.count) {
        if ([_mediaItems objectAtIndex:index] == [NSNull null]) {
            if ([_delegate respondsToSelector:@selector(browser:mediaItemAtIndex:)]) {
                mediaItem = [_delegate browser:self mediaItemAtIndex:index];
            }
            if (mediaItem) [_mediaItems replaceObjectAtIndex:index withObject:mediaItem];
        } else {
            mediaItem = [_mediaItems objectAtIndex:index];
        }
    }
    return mediaItem;
}

- (MWCaptionView *)captionViewForPhotoAtIndex:(NSUInteger)index {
    MWCaptionView *captionView = nil;
    if ([_delegate respondsToSelector:@selector(browser:captionViewForMediaItemAtIndex:)]) {
        captionView = [_delegate browser:self captionViewForMediaItemAtIndex:index];
    } else {
        MWMediaItem *mediaItem = [self mediaItemAtIndex:index];
        if ([mediaItem respondsToSelector:@selector(caption)]) {
            if ([mediaItem caption]) captionView = [[MWCaptionView alloc] initWithMediaItem:mediaItem];
        }
    }
    captionView.alpha = [self areControlsHidden] ? 0 : 1; // Initial alpha
    return captionView;
}

- (BOOL)mediaItemIsSelectedAtIndex:(NSUInteger)index {
    BOOL value = NO;
    if (_displaySelectionButtons) {
        if ([self.delegate respondsToSelector:@selector(browser:isMediaItemSelectedAtIndex:)]) {
            value = [self.delegate browser:self isMediaItemSelectedAtIndex:index];
        }
    }
    return value;
}

- (void)setMediaItemSelected:(BOOL)selected atIndex:(NSUInteger)index {
    if (_displaySelectionButtons) {
        if ([self.delegate respondsToSelector:@selector(browser:mediaItemAtIndex:selectedChanged:)]) {
            [self.delegate browser:self mediaItemAtIndex:index selectedChanged:selected];
        }
    }
}

- (UIImage *)imageForMediaItem:(MWMediaItem *)mediaItem {
	if (mediaItem) {
		// Get image or obtain in background
		if ([mediaItem underlyingImage]) {
			return [mediaItem underlyingImage];
		} else {
            [mediaItem loadUnderlyingImageAndNotify];
		}
	}
	return nil;
}

- (void)loadAdjacentMediaItemsIfNecessary:(MWMediaItem *)mediaItem {
    MWZoomingScrollView *page = [self pageDisplayingMediaItem:mediaItem];
    if (page) {
        // If page is current page then initiate loading of previous and next pages
        NSUInteger pageIndex = page.index;
        if (_currentPageIndex == pageIndex) {
            if (pageIndex > 0) {
                // Preload index - 1
                MWMediaItem *mediaItem = [self mediaItemAtIndex:pageIndex-1];
                if (![mediaItem underlyingImage]) {
                    [mediaItem loadUnderlyingImageAndNotify];
                    MWLog(@"Pre-loading image at index %lu", (unsigned long)pageIndex-1);
                }
            }
            if (pageIndex < [self numberOfPhotos] - 1) {
                // Preload index + 1
                MWMediaItem *mediaItem = [self mediaItemAtIndex:pageIndex+1];
                if (![mediaItem underlyingImage]) {
                    [mediaItem loadUnderlyingImageAndNotify];
                    MWLog(@"Pre-loading image at index %lu", (unsigned long)pageIndex+1);
                }
            }
        }
    }
}

#pragma mark - MWPhoto Loading Notification

- (void)handleMWPhotoLoadingDidEndNotification:(NSNotification *)notification {
    MWMediaItem *mediaItem = [notification object];
    MWZoomingScrollView *page = [self pageDisplayingMediaItem:mediaItem];
    if (page) {
        if ([mediaItem underlyingImage]) {
            // Successful load
            [page displayImage];
            [self loadAdjacentMediaItemsIfNecessary:mediaItem];
        } else {
            // Failed to load
            [page displayImageFailure];
        }
        // Update nav
        [self updateNavigation];
    }
}

#pragma mark - Paging

- (void)tilePages {
	
	// Calculate which pages should be visible
	// Ignore padding as paging bounces encroach on that
	// and lead to false page loads
	CGRect visibleBounds = _pagingScrollView.bounds;
	NSInteger iFirstIndex = (NSInteger)floorf((CGRectGetMinX(visibleBounds)+PADDING*2) / CGRectGetWidth(visibleBounds));
	NSInteger iLastIndex  = (NSInteger)floorf((CGRectGetMaxX(visibleBounds)-PADDING*2-1) / CGRectGetWidth(visibleBounds));
    if (iFirstIndex < 0) iFirstIndex = 0;
    if (iFirstIndex > [self numberOfPhotos] - 1) iFirstIndex = [self numberOfPhotos] - 1;
    if (iLastIndex < 0) iLastIndex = 0;
    if (iLastIndex > [self numberOfPhotos] - 1) iLastIndex = [self numberOfPhotos] - 1;
	
	// Recycle no longer needed pages
    NSInteger pageIndex;
	for (MWZoomingScrollView *page in _visiblePages) {
        pageIndex = page.index;
		if (pageIndex < (NSUInteger)iFirstIndex || pageIndex > (NSUInteger)iLastIndex) {
			[_recycledPages addObject:page];
            [page.captionView removeFromSuperview];
            [page.selectedButton removeFromSuperview];
            [page prepareForReuse];
			[page removeFromSuperview];
			MWLog(@"Removed page at index %lu", (unsigned long)pageIndex);
		}
	}
	[_visiblePages minusSet:_recycledPages];
    while (_recycledPages.count > 2) // Only keep 2 recycled pages
        [_recycledPages removeObject:[_recycledPages anyObject]];
	
	// Add missing pages
	for (NSUInteger index = (NSUInteger)iFirstIndex; index <= (NSUInteger)iLastIndex; index++) {
		if (![self isDisplayingPageForIndex:index]) {
            
            // Add new page
			MWZoomingScrollView *page = [self dequeueRecycledPage];
			if (!page) {
				page = [[MWZoomingScrollView alloc] initWithBrowser:self];
			}
			[_visiblePages addObject:page];
			[self configurePage:page forIndex:index];

			[_pagingScrollView addSubview:page];
			MWLog(@"Added page at index %lu", (unsigned long)index);
            
            // Add caption
            MWCaptionView *captionView = [self captionViewForPhotoAtIndex:index];
            if (captionView) {
                captionView.frame = [self frameForCaptionView:captionView atIndex:index];
                [_pagingScrollView addSubview:captionView];
                page.captionView = captionView;
            }
            
            // Add selected button
            if (self.displaySelectionButtons) {
                UIButton *selectedButton = [UIButton buttonWithType:UIButtonTypeCustom];
                [selectedButton setImage:[UIImage imageNamed:@"MWPhotoBrowser.bundle/images/ImageSelectedOff.png"] forState:UIControlStateNormal];
                [selectedButton setImage:[UIImage imageNamed:@"MWPhotoBrowser.bundle/images/ImageSelectedOn.png"] forState:UIControlStateSelected];
                [selectedButton sizeToFit];
                selectedButton.adjustsImageWhenHighlighted = NO;
                [selectedButton addTarget:self action:@selector(selectedButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
                selectedButton.frame = [self frameForSelectedButton:selectedButton atIndex:index];
                [_pagingScrollView addSubview:selectedButton];
                page.selectedButton = selectedButton;
                selectedButton.selected = [self mediaItemIsSelectedAtIndex:index];
            }
            
		}
	}
	
}

- (void)updateVisiblePageStates {
    NSSet *copy = [_visiblePages copy];
    for (MWZoomingScrollView *page in copy) {
        
        // Update selection
        page.selectedButton.selected = [self mediaItemIsSelectedAtIndex:page.index];
        
    }
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
	for (MWZoomingScrollView *page in _visiblePages)
		if (page.index == index) return YES;
	return NO;
}

- (MWZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index {
	MWZoomingScrollView *thePage = nil;
	for (MWZoomingScrollView *page in _visiblePages) {
		if (page.index == index) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (MWZoomingScrollView *)pageDisplayingMediaItem:(MWMediaItem *)mediaItem
{
	MWZoomingScrollView *thePage = nil;
	for (MWZoomingScrollView *page in _visiblePages) {
		if ([page.mediaItem isEqual:mediaItem]) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (void)configurePage:(MWZoomingScrollView *)page forIndex:(NSUInteger)index {
	page.frame = [self frameForPageAtIndex:index];
    page.index = index;
    page.mediaItem = [self mediaItemAtIndex:index];
}

- (MWZoomingScrollView *)dequeueRecycledPage {
	MWZoomingScrollView *page = [_recycledPages anyObject];
	if (page) {
		[_recycledPages removeObject:page];
	}
	return page;
}

// Handle page changes
- (void)didStartViewingPageAtIndex:(NSUInteger)index {
    
    if (![self numberOfPhotos]) {
        // Show controls
        [self setControlsHidden:NO animated:YES permanent:YES];
        return;
    }
    
    // Release images further away than +/-1
    NSUInteger i;
    if (index > 0) {
        // Release anything < index - 1
        for (i = 0; i < index-1; i++) { 
            id photo = [_mediaItems objectAtIndex:i];
            if (photo != [NSNull null]) {
                [photo unloadUnderlyingImage];
                [_mediaItems replaceObjectAtIndex:i withObject:[NSNull null]];
                MWLog(@"Released underlying image at index %lu", (unsigned long)i);
            }
        }
    }
    if (index < [self numberOfPhotos] - 1) {
        // Release anything > index + 1
        for (i = index + 2; i < _mediaItems.count; i++) {
            id photo = [_mediaItems objectAtIndex:i];
            if (photo != [NSNull null]) {
                [photo unloadUnderlyingImage];
                [_mediaItems replaceObjectAtIndex:i withObject:[NSNull null]];
                MWLog(@"Released underlying image at index %lu", (unsigned long)i);
            }
        }
    }
    
    // Load adjacent images if needed and the photo is already
    // loaded. Also called after photo has been loaded in background
    MWMediaItem *currentMediaItem = [self mediaItemAtIndex:index];
    if ([currentMediaItem underlyingImage]) {
        // photo loaded so load ajacent now
        [self loadAdjacentMediaItemsIfNecessary:currentMediaItem];
    }
    
    // Notify delegate
    if (index != _previousPageIndex) {
        if ([_delegate respondsToSelector:@selector(browser:didDisplayMediaItemAtIndex:)])
            [_delegate browser:self didDisplayMediaItemAtIndex:index];
        _previousPageIndex = index;
    }
    
    // Update nav
    [self updateNavigation];
    
}

#pragma mark - Frame Calculations

- (CGRect)frameForPagingScrollView {
    CGRect frame = self.view.bounds;// [[UIScreen mainScreen] bounds];
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    return CGRectIntegral(frame);
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = _pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return CGRectIntegral(pageFrame);
}

- (CGSize)contentSizeForPagingScrollView {
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    CGRect bounds = _pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self numberOfPhotos], bounds.size.height);
}

- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index {
	CGFloat pageWidth = _pagingScrollView.bounds.size.width;
	CGFloat newOffset = index * pageWidth;
	return CGPointMake(newOffset, 0);
}

- (CGRect)frameForToolbarAtOrientation:(UIInterfaceOrientation)orientation {
    CGFloat height = 44;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
        UIInterfaceOrientationIsLandscape(orientation)) height = 32;
	return CGRectIntegral(CGRectMake(0, self.view.bounds.size.height - height, self.view.bounds.size.width, height));
}

- (CGRect)frameForCaptionView:(MWCaptionView *)captionView atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    CGSize captionSize = [captionView sizeThatFits:CGSizeMake(pageFrame.size.width, 0)];
    CGRect captionFrame = CGRectMake(pageFrame.origin.x,
                                     pageFrame.size.height - captionSize.height - (_toolbar.superview?_toolbar.frame.size.height:0),
                                     pageFrame.size.width,
                                     captionSize.height);
    return CGRectIntegral(captionFrame);
}

- (CGRect)frameForSelectedButton:(UIButton *)selectedButton atIndex:(NSUInteger)index {
    CGRect pageFrame = [self frameForPageAtIndex:index];
    CGFloat yOffset = 0;
    if (![self areControlsHidden]) {
        UINavigationBar *navBar = self.navigationController.navigationBar;
        yOffset = navBar.frame.origin.y + navBar.frame.size.height;
    }
    CGFloat statusBarOffset = [[UIApplication sharedApplication] statusBarFrame].size.height;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    if (SYSTEM_VERSION_LESS_THAN(@"7") && !self.wantsFullScreenLayout) statusBarOffset = 0;
#endif
    CGRect captionFrame = CGRectMake(pageFrame.origin.x + pageFrame.size.width - 20 - selectedButton.frame.size.width,
                                     statusBarOffset + yOffset,
                                     selectedButton.frame.size.width,
                                     selectedButton.frame.size.height);
    return CGRectIntegral(captionFrame);
}

#pragma mark - UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	
    // Checks
	if (!_viewIsActive || _performingLayout || _rotating) return;
	
	// Tile pages
	[self tilePages];
	
	// Calculate current page
	CGRect visibleBounds = _pagingScrollView.bounds;
	NSInteger index = (NSInteger)(floorf(CGRectGetMidX(visibleBounds) / CGRectGetWidth(visibleBounds)));
    if (index < 0) index = 0;
	if (index > [self numberOfPhotos] - 1) index = [self numberOfPhotos] - 1;
	NSUInteger previousCurrentPage = _currentPageIndex;
	_currentPageIndex = index;
	if (_currentPageIndex != previousCurrentPage) {
        [self didStartViewingPageAtIndex:index];
    }
	
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	// Hide controls when dragging begins
//	[self setControlsHidden:YES animated:YES permanent:NO];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	// Update nav when page changes
	[self updateNavigation];
}

#pragma mark - Navigation

- (void)updateNavigation {
    
	// Title
    NSUInteger numberOfPhotos = [self numberOfPhotos];
    if (numberOfPhotos > 1) {
        if ([_delegate respondsToSelector:@selector(browser:titleForMediaItemAtIndex:)]) {
            self.title = [_delegate browser:self titleForMediaItemAtIndex:_currentPageIndex];
        } else {
            self.title = [NSString stringWithFormat:@"%lu %@ %lu", (unsigned long)(_currentPageIndex+1), NSLocalizedString(@"of", @"Used in the context: 'Showing 1 of 3 items'"), (unsigned long)numberOfPhotos];
        }
	} else {
		self.title = nil;
	}
	
	// Buttons
	_previousButton.enabled = (_currentPageIndex > 0);
	_nextButton.enabled = (_currentPageIndex < numberOfPhotos - 1);
    _actionButton.enabled = [[self mediaItemAtIndex:_currentPageIndex] underlyingImage] != nil;
	
}

- (void)jumpToPageAtIndex:(NSUInteger)index animated:(BOOL)animated {
	
	// Change page
	if (index < [self numberOfPhotos]) {
		CGRect pageFrame = [self frameForPageAtIndex:index];
        [_pagingScrollView setContentOffset:CGPointMake(pageFrame.origin.x - PADDING, 0) animated:animated];
		[self updateNavigation];
	}
	
	// Update timer to give more time
//	[self hideControlsAfterDelay];
	
}

- (void)gotoPreviousPage {
    [self showPreviousMediaItemAnimated:NO];
}
- (void)gotoNextPage {
    [self showNextMediaItemAnimated:NO];
}

- (void)showPreviousMediaItemAnimated:(BOOL)animated {
    [self jumpToPageAtIndex:_currentPageIndex-1 animated:animated];
}

- (void)showNextMediaItemAnimated:(BOOL)animated {
    [self jumpToPageAtIndex:_currentPageIndex+1 animated:animated];
}

#pragma mark - Interactions

- (void)selectedButtonTapped:(id)sender {
    UIButton *selectedButton = (UIButton *)sender;
    selectedButton.selected = !selectedButton.selected;
    NSUInteger index = NSUIntegerMax;
    for (MWZoomingScrollView *page in _visiblePages) {
        if (page.selectedButton == selectedButton) {
            index = page.index;
            break;
        }
    }
    if (index != NSUIntegerMax) {
        [self setMediaItemSelected:selectedButton.selected atIndex:index];
    }
}

#pragma mark - Control Hiding / Showing

// If permanent then we don't set timers to hide again
// Fades all controls on iOS 5 & 6, and iOS 7 controls slide and fade
- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent {
    
    // Force visible
    if (![self numberOfPhotos] || _alwaysShowControls)
        hidden = NO;
    
    // Cancel any timers
    [self cancelControlHiding];
    
    // Animations & positions
    BOOL slideAndFade = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7");
    CGFloat animatonOffset = 20;
    CGFloat animationDuration = (animated ? 0.35 : 0);
    
    // Status bar
    if (!_leaveStatusBarAlone) {
        if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
            
            // iOS 7
            // Hide status bar
            if (!_isVCBasedStatusBarAppearance) {
                
                // Non-view controller based
                [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animated ? UIStatusBarAnimationSlide : UIStatusBarAnimationNone];
                
            } else {
                
                // View controller based so animate away
                _statusBarShouldBeHidden = hidden;
                [UIView animateWithDuration:animationDuration animations:^(void) {
                    [self setNeedsStatusBarAppearanceUpdate];
                } completion:^(BOOL finished) {}];
                
            }
            
        } else {
            
            // Need to get heights and set nav bar position to overcome display issues
            
            // Get status bar height if visible
            CGFloat statusBarHeight = 0;
            if (![UIApplication sharedApplication].statusBarHidden) {
                CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
                statusBarHeight = MIN(statusBarFrame.size.height, statusBarFrame.size.width);
            }
            
            // Status Bar
            [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animated?UIStatusBarAnimationFade:UIStatusBarAnimationNone];
            
            // Get status bar height if visible
            if (![UIApplication sharedApplication].statusBarHidden) {
                CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
                statusBarHeight = MIN(statusBarFrame.size.height, statusBarFrame.size.width);
            }
            
            // Set navigation bar frame
            CGRect navBarFrame = self.navigationController.navigationBar.frame;
            navBarFrame.origin.y = statusBarHeight;
            self.navigationController.navigationBar.frame = navBarFrame;
            
            
        }
    }
    
    // Toolbar, nav bar and captions
    // Pre-appear animation positions for iOS 7 sliding
    if (slideAndFade && [self areControlsHidden] && !hidden && animated) {
        
        // Toolbar
        _toolbar.frame = CGRectOffset([self frameForToolbarAtOrientation:self.interfaceOrientation], 0, animatonOffset);
        
        // Captions
        for (MWZoomingScrollView *page in _visiblePages) {
            if (page.captionView) {
                MWCaptionView *v = page.captionView;
                // Pass any index, all we're interested in is the Y
                CGRect captionFrame = [self frameForCaptionView:v atIndex:0];
                captionFrame.origin.x = v.frame.origin.x; // Reset X
                v.frame = CGRectOffset(captionFrame, 0, animatonOffset);
            }
        }
        
    }
    [UIView animateWithDuration:animationDuration animations:^(void) {
        
        CGFloat alpha = hidden ? 0 : 1;

        // Nav bar slides up on it's own on iOS 7
        [self.navigationController.navigationBar setAlpha:alpha];
        
        // Toolbar
        if (slideAndFade) {
            _toolbar.frame = [self frameForToolbarAtOrientation:self.interfaceOrientation];
            if (hidden) _toolbar.frame = CGRectOffset(_toolbar.frame, 0, animatonOffset);
        }
        _toolbar.alpha = alpha;

        // Captions
        for (MWZoomingScrollView *page in _visiblePages) {
            if (page.captionView) {
                MWCaptionView *v = page.captionView;
                if (slideAndFade) {
                    // Pass any index, all we're interested in is the Y
                    CGRect captionFrame = [self frameForCaptionView:v atIndex:0];
                    captionFrame.origin.x = v.frame.origin.x; // Reset X
                    if (hidden) captionFrame = CGRectOffset(captionFrame, 0, animatonOffset);
                    v.frame = captionFrame;
                }
                v.alpha = alpha;
            }
        }
        
        // Selected buttons
        for (MWZoomingScrollView *page in _visiblePages) {
            if (page.selectedButton) {
                UIButton *v = page.selectedButton;
                CGRect newFrame = [self frameForSelectedButton:v atIndex:0];
                newFrame.origin.x = v.frame.origin.x;
                v.frame = newFrame;
            }
        }

    } completion:^(BOOL finished) {}];
    
	// Control hiding timer
	// Will cancel existing timer but only begin hiding if
	// they are visible
//	if (!permanent) [self hideControlsAfterDelay];
	
}

- (BOOL)prefersStatusBarHidden {
    if (!_leaveStatusBarAlone) {
        return _statusBarShouldBeHidden;
    } else {
        return [self presentingViewControllerPrefersStatusBarHidden];
    }
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationSlide;
}

- (void)cancelControlHiding {
	// If a timer exists then cancel and release
	if (_controlVisibilityTimer) {
		[_controlVisibilityTimer invalidate];
		_controlVisibilityTimer = nil;
	}
}

// Enable/disable control visiblity timer
- (void)hideControlsAfterDelay {
	if (![self areControlsHidden]) {
        [self cancelControlHiding];
		_controlVisibilityTimer = [NSTimer scheduledTimerWithTimeInterval:self.delayToHideElements target:self selector:@selector(hideControls) userInfo:nil repeats:NO];
	}
}

- (BOOL)areControlsHidden { return (_toolbar.alpha == 0); }
- (void)hideControls { [self setControlsHidden:YES animated:YES permanent:NO]; }
- (void)toggleControls { [self setControlsHidden:![self areControlsHidden] animated:YES permanent:NO]; }

#pragma mark - Properties

- (void)setCurrentMediaItemIndex:(NSUInteger)index {
    // Validate
    NSUInteger photoCount = [self numberOfPhotos];
    if (photoCount == 0) {
        index = 0;
    } else {
        if (index >= photoCount)
            index = [self numberOfPhotos]-1;
    }
    _currentPageIndex = index;
	if ([self isViewLoaded]) {
        [self jumpToPageAtIndex:index animated:NO];
        if (!_viewIsActive)
            [self tilePages]; // Force tiling if view is not visible
    }
}

#pragma mark - Misc

- (void)doneButtonPressed:(id)sender {
    // Only if we're modal and there's a done button
    if (_doneButton) {
        
        // Dismiss view controller
        if ([_delegate respondsToSelector:@selector(browserDidFinishModalPresentation:)]) {
            // Call delegate method and let them dismiss us
            [_delegate browserDidFinishModalPresentation:self];
        } else  {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma mark - Actions

- (void)actionButtonPressed:(id)sender {
    if (_actionsSheet) {
        
        // Dismiss
        [_actionsSheet dismissWithClickedButtonIndex:_actionsSheet.cancelButtonIndex animated:YES];
        
    } else {
        
        // Only react when image has loaded
        MWMediaItem *mediaItem = [self mediaItemAtIndex:_currentPageIndex];
        if ([self numberOfPhotos] > 0 && [mediaItem underlyingImage]) {
            
            // If they have defined a delegate method then just message them
            if ([self.delegate respondsToSelector:@selector(browser:actionButtonPressedForMediaItemAtIndex:)]) {
                
                // Let delegate handle things
                [self.delegate browser:self actionButtonPressedForMediaItemAtIndex:_currentPageIndex];
                
            } else {
                
                // Handle default actions
                if (SYSTEM_VERSION_LESS_THAN(@"6")) {
                    
                    // Old handling of activities with action sheet
                    if ([MFMailComposeViewController canSendMail]) {
                        _actionsSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
                                                               cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil
                                                               otherButtonTitles:NSLocalizedString(@"Save", nil), NSLocalizedString(@"Copy", nil), NSLocalizedString(@"Email", nil), nil];
                    } else {
                        _actionsSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
                                                               cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil
                                                               otherButtonTitles:NSLocalizedString(@"Save", nil), NSLocalizedString(@"Copy", nil), nil];
                    }
                    _actionsSheet.tag = ACTION_SHEET_OLD_ACTIONS;
                    _actionsSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                        [_actionsSheet showFromBarButtonItem:sender animated:YES];
                    } else {
                        [_actionsSheet showInView:self.view];
                    }
                    
                } else {
                    
                    // Show activity view controller
                    NSMutableArray *items = [NSMutableArray arrayWithObject:[mediaItem underlyingImage]];
                    if (mediaItem.caption) {
                        [items addObject:mediaItem.caption];
                    }
                    self.activityViewController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
                    
                    // Show loading spinner after a couple of seconds
                    double delayInSeconds = 2.0;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        if (self.activityViewController) {
                            [self showProgressHUDWithMessage:nil];
                        }
                    });

                    // Show
                    typeof(self) __weak weakSelf = self;
                    [self.activityViewController setCompletionHandler:^(NSString *activityType, BOOL completed) {
                        weakSelf.activityViewController = nil;
                        [weakSelf hideControlsAfterDelay];
                        [weakSelf hideProgressHUD:YES];
                    }];
                    // iOS 8 - Set the Anchor Point for the popover
                    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8")) {
                        self.activityViewController.popoverPresentationController.barButtonItem = _actionButton;
                    }
                    [self presentViewController:self.activityViewController animated:YES completion:nil];
                    
                }
                
            }
            
            // Keep controls hidden
            [self setControlsHidden:NO animated:YES permanent:YES];

        }
    }
}

#pragma mark - Action Sheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == ACTION_SHEET_OLD_ACTIONS) {
        // Old Actions
        _actionsSheet = nil;
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            if (buttonIndex == actionSheet.firstOtherButtonIndex) {
                [self saveMediaItem]; return;
            } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1) {
                [self copyMediaItem]; return;	
            } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 2) {
                [self emailMediaItem]; return;
            }
        }
    }
    [self hideControlsAfterDelay]; // Continue as normal...
}

#pragma mark - Action Progress

- (MBProgressHUD *)progressHUD {
    if (!_progressHUD) {
        _progressHUD = [[MBProgressHUD alloc] initWithView:self.view];
        _progressHUD.minSize = CGSizeMake(120, 120);
        _progressHUD.minShowTime = 1;
        // The sample image is based on the
        // work by: http://www.pixelpressicons.com
        // licence: http://creativecommons.org/licenses/by/2.5/ca/
        self.progressHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MWPhotoBrowser.bundle/images/Checkmark.png"]];
        [self.view addSubview:_progressHUD];
    }
    return _progressHUD;
}

- (void)showProgressHUDWithMessage:(NSString *)message {
    self.progressHUD.labelText = message;
    self.progressHUD.mode = MBProgressHUDModeIndeterminate;
    [self.progressHUD show:YES];
    self.navigationController.navigationBar.userInteractionEnabled = NO;
}

- (void)hideProgressHUD:(BOOL)animated {
    [self.progressHUD hide:animated];
    self.navigationController.navigationBar.userInteractionEnabled = YES;
}

- (void)showProgressHUDCompleteMessage:(NSString *)message {
    if (message) {
        if (self.progressHUD.isHidden) [self.progressHUD show:YES];
        self.progressHUD.labelText = message;
        self.progressHUD.mode = MBProgressHUDModeCustomView;
        [self.progressHUD hide:YES afterDelay:1.5];
    } else {
        [self.progressHUD hide:YES];
    }
    self.navigationController.navigationBar.userInteractionEnabled = YES;
}

#pragma mark - Actions

- (void)saveMediaItem {
    MWMediaItem *mediaItem = [self mediaItemAtIndex:_currentPageIndex];
    if ([mediaItem underlyingImage]) {
        [self showProgressHUDWithMessage:[NSString stringWithFormat:@"%@\u2026" , NSLocalizedString(@"Saving", @"Displayed with ellipsis as 'Saving...' when an item is in the process of being saved")]];
        [self performSelector:@selector(actuallySaveMediaItem:) withObject:mediaItem afterDelay:0];
    }
}

- (void)actuallySaveMediaItem:(MWMediaItem *)mediaItem {
    if ([mediaItem underlyingImage]) {
        UIImageWriteToSavedPhotosAlbum([mediaItem underlyingImage], self, 
                                       @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self showProgressHUDCompleteMessage: error ? NSLocalizedString(@"Failed", @"Informing the user a process has failed") : NSLocalizedString(@"Saved", @"Informing the user an item has been saved")];
    [self hideControlsAfterDelay]; // Continue as normal...
}

- (void)copyMediaItem {
    MWMediaItem *mediaItem = [self mediaItemAtIndex:_currentPageIndex];
    if ([mediaItem underlyingImage]) {
        [self showProgressHUDWithMessage:[NSString stringWithFormat:@"%@\u2026" , NSLocalizedString(@"Copying", @"Displayed with ellipsis as 'Copying...' when an item is in the process of being copied")]];
        [self performSelector:@selector(actuallyCopyMediaItem:) withObject:mediaItem afterDelay:0];
    }
}

- (void)actuallyCopyMediaItem:(MWMediaItem *)mediaItem {
    if ([mediaItem underlyingImage]) {
        [[UIPasteboard generalPasteboard] setData:UIImagePNGRepresentation([mediaItem underlyingImage])
                                forPasteboardType:@"public.png"];
        [self showProgressHUDCompleteMessage:NSLocalizedString(@"Copied", @"Informing the user an item has finished copying")];
        [self hideControlsAfterDelay]; // Continue as normal...
    }
}

- (void)emailMediaItem {
    MWMediaItem *mediaItem = [self mediaItemAtIndex:_currentPageIndex];
    if ([mediaItem underlyingImage]) {
        [self showProgressHUDWithMessage:[NSString stringWithFormat:@"%@\u2026" , NSLocalizedString(@"Preparing", @"Displayed with ellipsis as 'Preparing...' when an item is in the process of being prepared")]];
        [self performSelector:@selector(actuallyEmailMediaItem:) withObject:mediaItem afterDelay:0];
    }
}

- (void)actuallyEmailMediaItem:(MWMediaItem *)mediaItem {
    if ([mediaItem underlyingImage]) {
        MFMailComposeViewController *emailer = [[MFMailComposeViewController alloc] init];
        emailer.mailComposeDelegate = self;
        [emailer setSubject:NSLocalizedString(@"Photo", nil)];
        [emailer addAttachmentData:UIImagePNGRepresentation([mediaItem underlyingImage]) mimeType:@"png" fileName:@"Photo.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            emailer.modalPresentationStyle = UIModalPresentationPageSheet;
        }
        [self presentViewController:emailer animated:YES completion:nil];
        [self hideProgressHUD:NO];
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    if (result == MFMailComposeResultFailed) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Email", nil)
                                                         message:NSLocalizedString(@"Email failed to send. Please try again.", nil)
                                                        delegate:nil cancelButtonTitle:NSLocalizedString(@"Dismiss", nil) otherButtonTitles:nil];
		[alert show];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
