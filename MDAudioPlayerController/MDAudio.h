//
//  MDAudio.h
//  MDAudioPlayerSample
//
//  Created by Edward Chiang on 11/11/14.
//  Copyright (c) 2011年 Polydice Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MDAudio : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, assign) float duration;
@property (nonatomic, copy) NSString *durationInMinutes;
@property (nonatomic, retain) UIImage *coverImage;
@property (nonatomic, retain) NSURL *url;

@end
