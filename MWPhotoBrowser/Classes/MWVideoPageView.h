//
//  MWVideoPageView.h
//  MWPhotoBrowser
//
//  Created by Ivan on 14/03/15.
//
//

#import <UIKit/UIKit.h>
#import "MWPhotoBrowserPage.h"
#import "MWTapDetectingView.h"

@interface MWVideoPageView : MWTapDetectingView <MWPhotoBrowserPage>
- (void)pausePlayback;
@end
