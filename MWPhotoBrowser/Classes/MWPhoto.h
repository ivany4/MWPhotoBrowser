//
//  MWPhoto.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MWMediaItem.h"

// This class models a photo/image and it's caption
// If you want to handle photos, caching, decompression
// yourself then you can simply ensure your custom data model
// conforms to MWPhotoProtocol
@interface MWPhoto : MWMediaItem

@property (nonatomic, readonly) UIImage *image;

+ (instancetype)photoWithImage:(UIImage *)image;

- (id)initWithImage:(UIImage *)image;

@end

