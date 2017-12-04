//
//  YXTestViewController.m
//  TrainApp
//
//  Created by niuzhaowang on 16/6/13.
//  Copyright © 2016年 niuzhaowang. All rights reserved.
//

#import "YXTestViewController.h"
#import "QuestionnaireResultViewController.h"
#import "CourseCommentViewController.h"
#import "QuestionnaireViewController.h"
#import "QADataManager.h"
#import "YXLocationManager.h"

@interface YXTestViewController ()
@end

@implementation YXTestViewController
- (void)viewDidLoad {
    self.devTestActions = @[@"问卷",@"问卷结果",@"comment", @"上传图片", @"单次定位"];
    [super viewDidLoad];
}

- (void)问卷 {
    QuestionnaireViewController *vc = [[QuestionnaireViewController alloc]initWithStepId:nil interactType:InteractType_Vote];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)问卷结果 {
    QuestionnaireResultViewController *vc = [[QuestionnaireResultViewController alloc]init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)comment {
    CourseCommentViewController *vc = [[CourseCommentViewController alloc]init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)上传图片 {
    WEAK_SELF
    [self.view nyx_startLoading];
    [QADataManager uploadFile:[UIImage imageNamed:@"登录背景"] fileName:@"登录背景.jpg" completeBlock:^(QAFileUploadSecondStepRequestItem *item, NSError *error) {
        STRONG_SELF
        [self.view nyx_stopLoading];
        if (error) {
            [self.view nyx_showToast:error.localizedDescription];
            return;
        }
        [self.view nyx_showToast:[NSString stringWithFormat:@"上传成功\n资源ID是：%@", item.result.resid]];
    }];
}

- (void)单次定位 {
    [[YXLocationManager sharedInstance] requestLocation];
}

@end

