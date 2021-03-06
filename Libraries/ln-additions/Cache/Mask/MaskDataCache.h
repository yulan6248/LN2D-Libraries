//
// Created by knight on 30/01/2013.
//
// Contact me via Email(dlnathos321@gmail.com) or Twitter(@dailingnan)
//


#import <Foundation/Foundation.h>
#import "NSCache+LnAdditions.h"

@class MaskData;


@interface MaskDataCache : NSCache

+ (MaskDataCache *)sharedCache;

- (id)dataForSpriteFrame:(CCSpriteFrame *)f maskDataGenerator:(MaskData *(^)(CCSpriteFrame *frame))generator;
@end