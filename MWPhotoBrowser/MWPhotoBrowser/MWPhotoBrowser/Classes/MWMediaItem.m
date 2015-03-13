//
//  MWMediaItem.m
//  MWPhotoBrowser
//
//  Created by Ivan on 12/03/15.
//
//

#import "MWMediaItem.h"

@implementation MWMediaItem

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
@end
