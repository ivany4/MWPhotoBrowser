//
//  MWPhotoBrowserPage.h
//  MWPhotoBrowser
//
//  Created by Ivan on 14/03/15.
//
//

#import <Foundation/Foundation.h>
#import "MWMediaItem.h"

@class MWCaptionView, MWPhotoBrowser;
@protocol MWPhotoBrowserPage <NSObject>
@property (nonatomic) MWMediaItem *mediaItem;
@property (nonatomic, weak) MWCaptionView *captionView;
@property NSUInteger index;
- (id)initWithBrowser:(MWPhotoBrowser *)browser;
- (void)prepareForReuse;
- (void)updateLayoutForCurrentBounds;
- (void)displayContent;
- (void)displayContentFailure;
@end
