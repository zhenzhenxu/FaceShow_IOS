//
//  ClassMomentPublishRequest.m
//  FaceShowApp
//
//  Created by 郑小龙 on 2017/9/20.
//  Copyright © 2017年 niuzhaowang. All rights reserved.
//

#import "ClassMomentPublishRequest.h"
@implementation ClassMomentPublishRequestItem

@end
@implementation ClassMomentPublishRequest
+ (JSONKeyMapper *)keyMapper {
    return [[JSONKeyMapper alloc] initWithDictionary:@{@"userId":@"userID"}];
}
- (instancetype)init {
    if (self = [super init]) {
        self.urlHead = @"";
    }
    return self;
}
@end
