//
//  MWMediaItem.m
//  MWPhotoBrowser
//
//  Created by Ivan on 12/03/15.
//
//

#import "SDWebImageDecoder.h"
#import "SDWebImageManager.h"
#import "SDWebImageOperation.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "MWMediaItem.h"

@interface MWMediaItem () {
    UIImage *_image;
    BOOL _loadingInProgress;
    id <SDWebImageOperation> _webImageOperation;
}
@end

@implementation MWMediaItem
@synthesize underlyingImage = _underlyingImage; // synth property from protocol

+ (instancetype)mediaItemWithURL:(NSURL *)url
{
    return [[[self class] alloc] initWithURL:url];
}

- (id)initWithURL:(NSURL *)url
{
    if ((self = [super init])) {
        _URL = [url copy];
    }
    return self;
}

#pragma mark - MWPhoto Protocol Methods

- (UIImage *)underlyingImage {
    return _underlyingImage;
}

- (void)loadUnderlyingImageAndNotify {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    if (_loadingInProgress) return;
    _loadingInProgress = YES;
    @try {
        if (self.underlyingImage) {
            [self imageLoadingComplete];
        } else {
            [self performLoadUnderlyingImageAndNotify];
        }
    }
    @catch (NSException *exception) {
        self.underlyingImage = nil;
        _loadingInProgress = NO;
        [self imageLoadingComplete];
    }
    @finally {
    }
}

// Set the underlyingImage
- (void)performLoadUnderlyingImageAndNotify {
    
    // Get underlying image
    if (_image) {
        
        // We have UIImage!
        self.underlyingImage = _image;
        [self imageLoadingComplete];
        
    } else if (self.URL) {
        
        // Check what type of url it is
        if ([[[self.URL scheme] lowercaseString] isEqualToString:@"assets-library"]) {
            
            // Load from asset library async
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    @try {
                        ALAssetsLibrary *assetslibrary = [[ALAssetsLibrary alloc] init];
                        [assetslibrary assetForURL:self.URL
                                       resultBlock:^(ALAsset *asset){
                                           ALAssetRepresentation *rep = [asset defaultRepresentation];
                                           CGImageRef iref = [rep fullScreenImage];
                                           if (iref) {
                                               self.underlyingImage = [UIImage imageWithCGImage:iref];
                                           }
                                           [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                                       }
                                      failureBlock:^(NSError *error) {
                                          self.underlyingImage = nil;
                                          NSLog(@"Photo from asset library error: %@",error);
                                          [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                                      }];
                    } @catch (NSException *e) {
                        NSLog(@"Photo from asset library error: %@", e);
                        [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                    }
                }
            });
            
        } else if ([self.URL isFileReferenceURL]) {
            
            // Load from local file async
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    @try {
                        self.underlyingImage = [UIImage imageWithContentsOfFile:self.URL.path];
                        if (!_underlyingImage) {
                            NSLog(@"Error loading photo from path: %@", self.URL.path);
                        }
                    } @finally {
                        [self performSelectorOnMainThread:@selector(imageLoadingComplete) withObject:nil waitUntilDone:NO];
                    }
                }
            });
            
        } else {
            
            // Load async from web (using SDWebImage)
            @try {
                SDWebImageManager *manager = [SDWebImageManager sharedManager];
                _webImageOperation = [manager downloadImageWithURL:self.URL
                                                           options:0
                                                          progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                                                              if (expectedSize > 0) {
                                                                  float progress = receivedSize / (float)expectedSize;
                                                                  NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                        [NSNumber numberWithFloat:progress], @"progress",
                                                                                        self, @"photo", nil];
                                                                  [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_PROGRESS_NOTIFICATION object:dict];
                                                              }
                                                          }
                                                         completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                                                             if (error) {
                                                                 NSLog(@"SDWebImage failed to download image: %@", error);
                                                             }
                                                             _webImageOperation = nil;
                                                             self.underlyingImage = image;
                                                             [self imageLoadingComplete];
                                                         }];
            } @catch (NSException *e) {
                NSLog(@"Photo from web: %@", e);
                _webImageOperation = nil;
                [self imageLoadingComplete];
            }
            
        }
        
    } else {
        
        // Failed - no source
        @throw [NSException exceptionWithName:nil reason:nil userInfo:nil];
        
    }
}

// Release if we can get it again from path or url
- (void)unloadUnderlyingImage {
    _loadingInProgress = NO;
    self.underlyingImage = nil;
}

- (void)imageLoadingComplete {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    // Complete so notify
    _loadingInProgress = NO;
    // Notify on next run loop
    [self performSelector:@selector(postCompleteNotification) withObject:nil afterDelay:0];
}

- (void)postCompleteNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION
                                                        object:self];
}

- (void)cancelAnyLoading {
    if (_webImageOperation) {
        [_webImageOperation cancel];
        _loadingInProgress = NO;
    }
}
@end
