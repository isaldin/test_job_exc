//
// Created by Ilya Saldin on 21/03/16.
// Copyright (c) 2016 sald.in. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIKit/UIKit.h"

@class LoopGalleryView;

@protocol LoopGalleryViewManager <NSObject>

@required
- (NSArray *)imagesURLs;

@optional
- (void)loopGallery:(LoopGalleryView *)loopGallery didSelectAtIndex:(NSUInteger)index;

@end

@interface LoopGalleryView : UIView

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong) id<LoopGalleryViewManager> loopGalleryManager;
@property (nonatomic, strong, readonly) UICollectionView *collectionView;

@end