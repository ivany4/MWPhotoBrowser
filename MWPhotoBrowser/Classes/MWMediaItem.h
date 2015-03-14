//
//  MWMediaItem.h
//  MWPhotoBrowser
//
//  Created by Ivan on 12/03/15.
//
//

#import <Foundation/Foundation.h>

#define MWPHOTO_LOADING_DID_END_NOTIFICATION @"MWPHOTO_LOADING_DID_END_NOTIFICATION"
#define MWPHOTO_PROGRESS_NOTIFICATION @"MWPHOTO_PROGRESS_NOTIFICATION"

@interface MWMediaItem : NSObject
@property (nonatomic, strong) NSString *caption;
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, assign) BOOL isVideo;
- (Class)viewClass;
- (id)initWithURL:(NSURL *)url;
+ (instancetype)mediaItemWithURL:(NSURL *)url;

// Return underlying UIImage to be displayed
// Return nil if the image is not immediately available (loaded into memory, preferably
// already decompressed) and needs to be loaded from a source (cache, file, web, etc)
// IMPORTANT: You should *NOT* use this method to initiate
// fetching of images from any external of source. That should be handled
// in -loadUnderlyingImageAndNotify: which may be called by the photo browser if this
// methods returns nil.
@property (nonatomic, strong) UIImage *underlyingImage;
- (void)preloadContent;

// This is called when the photo browser has determined the photo data
// is no longer needed or there are low memory conditions
// You should release any underlying (possibly large and decompressed) image data
// as long as the image can be re-loaded (from cache, file, or URL)
- (void)unloadContent;


// Return a caption string to be displayed over the image
// Return nil to display no caption
- (NSString *)caption;

// Cancel any background loading of image data
- (void)cancelAnyLoading;

- (UIImage *)retrieveImage;

@end
