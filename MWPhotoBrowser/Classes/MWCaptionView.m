//
//  MWCaptionView.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 30/12/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MWCommon.h"
#import "MWCaptionView.h"
#import "MWPhoto.h"

static const CGFloat labelPadding = 10;

// Private
@interface MWCaptionView () {
    MWMediaItem *_mediaItem;
    UILabel *_label;
}
@property (nonatomic, strong) UIView *customControls;
@end

@implementation MWCaptionView

- (id)initWithMediaItem:(MWMediaItem *)mediaItem
{
    self = [super initWithFrame:CGRectMake(0, 0, 320, 44)]; // Random initial frame
    if (self) {
        self.userInteractionEnabled = NO;
        _mediaItem = mediaItem;
        self.barStyle = UIBarStyleBlackTranslucent;
        self.tintColor = nil;
        self.barTintColor = nil;
        self.barStyle = UIBarStyleBlackTranslucent;
        [self setBackgroundImage:nil forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        [self setupCaption];
    }
    return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat maxHeight = 9999;
    if (_label.numberOfLines > 0) maxHeight = _label.font.leading*_label.numberOfLines;
    CGSize textSize;
    textSize = [_label.text boundingRectWithSize:CGSizeMake(size.width - labelPadding*2, maxHeight)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName:_label.font}
                                         context:nil].size;

    CGFloat additionalHeight = 0;
    if (self.customControls) {
        additionalHeight = self.customControls.frame.size.height + 5;
    }
    
    return CGSizeMake(size.width, textSize.height + labelPadding * 2 + additionalHeight);
}

- (void)setupCaption {
    _label = [[UILabel alloc] init];
    _label.opaque = NO;
    _label.backgroundColor = [UIColor clearColor];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.lineBreakMode = NSLineBreakByWordWrapping;
    
    _label.numberOfLines = 0;
    _label.textColor = [UIColor whiteColor];
    _label.font = [UIFont systemFontOfSize:17];
    if ([_mediaItem respondsToSelector:@selector(caption)]) {
        _label.text = [_mediaItem caption] ?: @" ";
    }
    [self addSubview:_label];
    [self layoutCaption];
}

- (void)layoutCaption
{
    CGFloat additionalHeight = 0;
    if (self.customControls) {
        additionalHeight = self.customControls.frame.size.height + 5;
    }
    _label.frame = CGRectIntegral(CGRectMake(labelPadding, 0,
                              self.bounds.size.width-labelPadding*2,
                                             self.bounds.size.height-additionalHeight));
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
}

- (void)accommodateCustomControls:(UIView *)controlsContainer
{
    CGRect frame = controlsContainer.frame;
    frame.size.width = self.frame.size.width;
    frame.origin.x = 0;
    frame.origin.y = self.bounds.size.height - frame.size.height;
    [self addSubview:controlsContainer];
    controlsContainer.frame = frame;
    controlsContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleWidth;
    
    self.userInteractionEnabled = YES;
    
    self.customControls = controlsContainer;
    [self layoutCaption];
}

- (void)removeCustomConstrols
{
    self.userInteractionEnabled = NO;
    [self.customControls removeFromSuperview], self.customControls = nil;
    [self layoutCaption];
    [self setNeedsLayout];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [self.customControls hitTest:[self.customControls convertPoint:point fromView:self] withEvent:event];
    return view;
}


@end
