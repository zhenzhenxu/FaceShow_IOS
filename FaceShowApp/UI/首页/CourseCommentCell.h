//
//  CourseCommentCell.h
//  FaceShowApp
//
//  Created by niuzhaowang on 2017/9/15.
//  Copyright © 2017年 niuzhaowang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CourseCommentCell : UITableViewCell
@property (nonatomic, assign) BOOL bottomLineHidden;
@property (nonatomic, strong) void(^favorBlock)();
@end
