//
//  ViewController.m
//  excursopedia_tj
//
//  Created by Ilya Saldin on 21/03/16.
//  Copyright © 2016 sald.in. All rights reserved.
//

#import "ViewController.h"
#import "LoopGalleryView.h"

@interface ViewController () <LoopGalleryViewManager>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.loopGalleryView.loopGalleryManager = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - LoopGalleryViewManager methods

- (void)loopGallery:(LoopGalleryView *)loopGallery didSelectAtIndex:(NSUInteger)index
{
    NSLog(@"did selected item at index %lu", (unsigned long)index);
}


- (NSArray *)imagesURLs
{
    return @[
            @"http://soyouknowbetter.com/wp-content/uploads/2013/02/2-pita.jpg",
            @"http://www.e-architect.co.uk/images/jpgs/italy/bolzano_science_technology_park_ct130208_1.jpg",
            @"http://blogs.aecom.com/connectedcities/wp-content/uploads/sites/5/2013/07/Virginia-Tech-670x355.jpg",
            @"http://images.cdn.stuff.tv/sites/stuff.tv/files/styles/big-image/public/brands/Tech-Buildings/agora-garden.jpg",
            @"http://www.travelthewholeworld.com/wp-content/uploads/2013/12/Netherlands-Eindhoven-Store.jpg",
    ];
}

@end
