//
//  MWPhoto.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 17/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import "MWZoomingScrollView.h"


@implementation MWPhoto


#pragma mark - Class Methods

+ (instancetype)photoWithImage:(UIImage *)image {
    return [[MWPhoto alloc] initWithImage:image];
}

- (Class)viewClass
{
    return [MWZoomingScrollView class];
}

- (id)initWithImage:(UIImage *)image {
    if ((self = [super init])) {
        self.isVideo = NO;
        _image = image;
    }
    return self;
}

- (id)initWithURL:(NSURL *)url
{
    if (self = [super initWithURL:url]) {
        self.isVideo = NO;
    }
    return self;
}

@end
