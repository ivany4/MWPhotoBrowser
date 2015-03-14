//
//  ZoomingScrollView.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MWTapDetectingView.h"
#import "MWPhotoBrowserPage.h"

@class MWPhotoBrowser, MWMediaItem, MWCaptionView;

@interface MWZoomingScrollView : UIScrollView <UIScrollViewDelegate, MWTapDetectingViewDelegate, MWPhotoBrowserPage> {

}
@end
