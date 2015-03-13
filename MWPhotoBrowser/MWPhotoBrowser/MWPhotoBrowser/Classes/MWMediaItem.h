//
//  MWMediaItem.h
//  MWPhotoBrowser
//
//  Created by Ivan on 12/03/15.
//
//

#import <Foundation/Foundation.h>

@interface MWMediaItem : NSObject
@property (nonatomic, strong) NSString *caption;
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, assign) BOOL isVideo;
- (id)initWithURL:(NSURL *)url;
+ (instancetype)mediaItemWithURL:(NSURL *)url;
@end
