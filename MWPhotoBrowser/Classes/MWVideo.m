//
//  MWVideo.m
//  MWPhotoBrowser
//
//  Created by IVANY4 on 2015-03-14.
//
//

#import "MWVideo.h"
#import "MWVideoPageView.h"


@implementation MWVideo

- (instancetype)initWithURL:(NSURL *)URL
{
    if (self = [super initWithURL:URL]) {
        self.isVideo = YES;
    }
    return self;
}

- (Class)viewClass
{
    return [MWVideoPageView class];
}
@end
