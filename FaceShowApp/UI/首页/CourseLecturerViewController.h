//
//  CourseLecturerViewController.h
//  FaceShowAdminApp
//
//  Created by niuzhaowang on 2017/11/9.
//  Copyright © 2017年 niuzhaowang. All rights reserved.
//

#import "BaseViewController.h"
#import "GetCourseRequest.h"

@interface CourseLecturerViewController : BaseViewController
@property (nonatomic, strong) NSArray<GetCourseRequestItem_LecturerInfo, Optional> *lecturerInfos;
@end
