//
// Created by Ilya Saldin on 21/03/16.
// Copyright (c) 2016 sald.in. All rights reserved.
//

#import "LoopGalleryView.h"
#import "LoopGalleryItemCell.h"


static NSString *const kItemCellNibName = @"LoopGalleryItemCell";
static NSString *const kItemCellReuseIdentifier = @"LoopGalleryItemCellId";
static NSString *const kPlaceholderImageName = @"placeholder.gif";
static NSString *const kImageFetchedNotificationName = @"LoopGalleryViewImageFetchedNotificationName";

static const int kAutoScrollInterval = 2;

@interface LoopGalleryView () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong, readwrite) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray *imagesURLs;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

@implementation LoopGalleryView
{
    // "cache"
    NSMutableArray *_images;

    // timestamp
    CFTimeInterval _prevTimestamp;
}
#pragma mark - initialization

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {
        [self _commonInit];
    }

    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    [self _commonInit];
}

#pragma mark - override getters

- (UIImage *)placeholderImage
{
    static UIImage *_placeholderImg = nil;
    static dispatch_once_t token = 0;
    dispatch_once(&token, ^{
        _placeholderImg = [UIImage imageNamed:kPlaceholderImageName];
    });

    return _placeholderImg;
}

#pragma mark - override setters

- (void)setLoopGalleryManager:(id <LoopGalleryViewManager>)loopGalleryManager
{
    if (!loopGalleryManager || ![loopGalleryManager imagesURLs] || ![[loopGalleryManager imagesURLs] count]) {
        return;
    }

    if (!self.loopGalleryManager) {
        _loopGalleryManager = loopGalleryManager;

        NSArray *tempArray = [[self loopGalleryManager] imagesURLs];

        id firstItem = tempArray[0];
        id lastItem = [tempArray lastObject];

        NSMutableArray *imagesURLsArray = [tempArray mutableCopy];
        [imagesURLsArray insertObject:lastItem atIndex:0];
        [imagesURLsArray addObject:firstItem];

        self.imagesURLs = [imagesURLsArray copy];

        // fill images array with [NSNull null]
        _images = [NSMutableArray arrayWithCapacity:[self.imagesURLs count]];
        for (int i = 0; i < [self.imagesURLs count]; i++) {
            [_images addObject:[NSNull null]];
        }

        // start fetching images in bg
        [self _fetchImagesWithURLs];

        [self.collectionView reloadData];

        // avoid showing fake cell at left edge
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]
                                    atScrollPosition:UICollectionViewScrollPositionNone
                                            animated:NO];
        [self _createTimer];
        [self _startTimer];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [_images count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LoopGalleryItemCell *loopGalleryItemCell = [collectionView dequeueReusableCellWithReuseIdentifier:kItemCellReuseIdentifier
                                                                                         forIndexPath:indexPath];

    uint cellIndex = (uint) indexPath.row;
    if (_images[cellIndex] == [NSNull null]) {
        _images[cellIndex] = self.placeholderImage;
    }

    loopGalleryItemCell.imageView.image = _images[cellIndex];

    return loopGalleryItemCell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.loopGalleryManager respondsToSelector:@selector(loopGallery:didSelectAtIndex:)]) {
        [self.loopGalleryManager loopGallery:self didSelectAtIndex:self.indexOfVisibleCellForDelegate];
    }
}

#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{   // https://adoptioncurve.net/archives/2013/07/building-a-circular-gallery-with-a-uicollectionview/
    // Calculate where the collection view should be at the right-hand end item
    float contentOffsetWhenFullyScrolledRight = self.collectionView.frame.size.width * ([_images count] -1);

    if (scrollView.contentOffset.x == contentOffsetWhenFullyScrolledRight) {

        // user is scrolling to the right from the last item to the 'fake' item 1.
        // reposition offset to show the 'real' item 1 at the left-hand end of the collection view

        NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:1 inSection:0];

        [self.collectionView scrollToItemAtIndexPath:newIndexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
    } else if (scrollView.contentOffset.x == 0)  {

        // user is scrolling to the left from the first item to the fake 'item N'.
        // reposition offset to show the 'real' item N at the right end end of the collection view

        NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:([_images count]-2) inSection:0];

        [self.collectionView scrollToItemAtIndexPath:newIndexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
    }

    [self _startTimer];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    // stop time when user begins interaction with gallery
    [self _stopTimer];
}


#pragma mark - internal

- (void)_commonInit
{
    // init defaults
    _images = [NSMutableArray array];

    // init collectionViewFlowLayout
    UICollectionViewFlowLayout *collectionViewFlowLayout = [[UICollectionViewFlowLayout alloc] init];
    collectionViewFlowLayout.itemSize = self.bounds.size;
    collectionViewFlowLayout.minimumInteritemSpacing = 0.f;
    collectionViewFlowLayout.minimumLineSpacing = 0.f;
    collectionViewFlowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    // init collectionView
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.bounds
                                                          collectionViewLayout:collectionViewFlowLayout];
    collectionView.delegate = self;
    collectionView.dataSource = self;
    collectionView.pagingEnabled = YES;
    collectionView.showsHorizontalScrollIndicator = NO;
    collectionView.bounces = NO;
    [collectionView registerNib:[UINib nibWithNibName:kItemCellNibName bundle:nil]
     forCellWithReuseIdentifier:kItemCellReuseIdentifier];

    self.collectionView.collectionViewLayout = collectionViewFlowLayout;
    self.collectionView = collectionView;
    [self addSubview:collectionView];

    // create timer
    [self _createTimer];

    // subscribe for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_handleImageFetchedNotification:)
                                                 name:kImageFetchedNotificationName
                                               object:nil];
}

- (void)_handleImageFetchedNotification:(NSNotification *)notification
{
    if (notification.object) {
        NSNumber *fetchedImageIndex = notification.object;
        if (self.indexOfVisibleCell == [fetchedImageIndex unsignedIntValue]) {
            self.visibleCell.imageView.image = _images[[fetchedImageIndex unsignedIntValue]];
        }
    }
}

// @brief fetch images by URLs in bg-thread
- (void)_fetchImagesWithURLs
{
    dispatch_queue_t fetchImagesQueue = dispatch_queue_create("sald.in.fetchImagesQueue", nil);

    __block NSMutableArray *images = _images;
    for (uint i = 0; i < self.imagesURLs.count; i++) {
        NSString *URLString = self.imagesURLs[i];
        NSURL *url = [[NSURL alloc] initWithString:URLString];
        dispatch_async(fetchImagesQueue, ^{
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (image) {
                    images[i] = image;
                    [[NSNotificationCenter defaultCenter] postNotificationName:kImageFetchedNotificationName object:@(i)];
                }
            });
        });
    }
}

#pragma mark - calculated properties

- (LoopGalleryItemCell *)visibleCell
{
    LoopGalleryItemCell *visibleCell = [self.collectionView.visibleCells firstObject];
    return visibleCell;
}

- (uint)indexOfVisibleCell
{
    LoopGalleryItemCell *visibleCell = self.visibleCell;
    return (uint) [self.collectionView indexPathForCell:visibleCell].row;
}

- (uint)indexOfVisibleCellForDelegate
{
    uint visibleCellIndex = self.indexOfVisibleCell;

    if (visibleCellIndex == 0) {
        return _images.count - 2;
    } else if (visibleCellIndex == _images.count-1) {
        return 0;
    } else {
        return visibleCellIndex-1;
    }
}

#pragma mark - timer related methods

- (void)_handleTimerTick:(CADisplayLink *)displayLink
{
    if (_prevTimestamp == 0) {
        _prevTimestamp = self.displayLink.timestamp;
    }

    if (self.displayLink && (self.displayLink.timestamp - _prevTimestamp) > kAutoScrollInterval) {
        [self scrollToNextItem];
    }
}

- (void)_stopTimer
{
    self.displayLink.paused = YES;
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)_createTimer
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_handleTimerTick:)];
    self.displayLink.frameInterval = 2;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:UITrackingRunLoopMode];
    self.displayLink.paused = YES;
}

- (void)_startTimer
{
    [self _stopTimer];
    [self _createTimer];

    _prevTimestamp = self.displayLink.timestamp;
    self.displayLink.paused = NO;
}

#pragma mark - gallery related methods

- (void)scrollToNextItem
{
    // in first, scroll silently from right fake cell to first "normal" cell, if needed without animation

    uint cellIndex = self.indexOfVisibleCell;

    // if current cell's index is last
    if (cellIndex == _images.count-1) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionLeft
                                            animated:NO];
    }

    // scroll to next with animation
    dispatch_after(5*NSEC_PER_SEC, dispatch_get_main_queue(), ^{
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.indexOfVisibleCell+1
                                                    inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionLeft
                                            animated:YES];

        [self _startTimer];
    });
}

#pragma mark - dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // utilize timer
    self.displayLink.paused = YES;
    [self.displayLink invalidate];
    self.displayLink = nil;
}

@end