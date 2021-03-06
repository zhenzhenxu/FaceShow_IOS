//
//  ScheduleViewController.m
//  FaceShowApp
//
//  Created by niuzhaowang on 2017/9/14.
//  Copyright © 2017年 niuzhaowang. All rights reserved.
//

#import "ScheduleViewController.h"
#import "ShowPhotosViewController.h"
#import "EmptyView.h"
#import "ErrorView.h"
#import "GetScheduleListRequest.h"

@interface ScheduleViewController ()

@property (nonatomic, strong) EmptyView *emptyView;
@property (nonatomic, strong) ErrorView *errorView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *detailImageView;
@property (nonatomic, strong) GetScheduleListRequest *request;
@property (nonatomic, strong) GetScheduleListRequestItem_Schedule *schedule;

@end

@implementation ScheduleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self requestScheduleInfo];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)requestScheduleInfo {
    [self.view nyx_startLoading];
    WEAK_SELF
    [self.request stopRequest];
    self.request = [[GetScheduleListRequest alloc] init];
    self.request.clazsId = [UserManager sharedInstance].userModel.projectClassInfo.data.clazsInfo.clazsId;
    [self.request startRequestWithRetClass:[GetScheduleListRequestItem class] andCompleteBlock:^(id retItem, NSError *error, BOOL isMock) {
        STRONG_SELF
        [self.view nyx_stopLoading];
        self.errorView.hidden = YES;
        self.emptyView.hidden = YES;
        GetScheduleListRequestItem *item = (GetScheduleListRequestItem *)retItem;
        if (item.error.code.integerValue == 210025) {
            self.emptyView.hidden = NO;
            return;
        }
        if (error) {
            self.errorView.hidden = NO;
            return;
        }
        if (isEmpty(item.data.schedules.elements)) {
            self.emptyView.hidden = NO;
            return;
        }
        self.schedule = item.data.schedules.elements[0];
        [self setModel];
    }];
}

#pragma mark - setupUI
- (void)setupUI {
    self.contentView.backgroundColor = [UIColor colorWithHexString:@"ebeff2"];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.numberOfLines = 0;
    [self.contentView addSubview:self.titleLabel];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(25);
        make.left.mas_equalTo(15);
        make.right.mas_equalTo(-15);
    }];
    
    self.detailImageView = [[UIImageView alloc] init];
    self.detailImageView.userInteractionEnabled = YES;
    self.detailImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.detailImageView];
    [self.detailImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.titleLabel.mas_bottom).offset(20);
        make.left.mas_equalTo(15);
        make.right.bottom.mas_equalTo(-15);
    }];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    [self.detailImageView addGestureRecognizer:tap];
    
    self.emptyView = [[EmptyView alloc]init];
    self.emptyView.title = @"暂无日程";
    [self.view addSubview:self.emptyView];
    [self.emptyView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(0);
    }];
    self.emptyView.hidden = YES;
    self.errorView = [[ErrorView alloc]init];
    WEAK_SELF
    [self.errorView setRetryBlock:^{
        STRONG_SELF
        [self requestScheduleInfo];
    }];
    [self.view addSubview:self.errorView];
    [self.errorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(0);
    }];
    self.errorView.hidden = YES;
}

- (void)setModel {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.minimumLineHeight = 22;
    style.alignment = NSTextAlignmentCenter;
    NSMutableAttributedString *attributedStr = [[NSMutableAttributedString alloc] initWithString:self.schedule.subject attributes:@{
                                                                                                                                NSFontAttributeName : [UIFont boldSystemFontOfSize:16],
                                                                                                                                NSForegroundColorAttributeName : [UIColor colorWithHexString:@"333333"],
                                                                                                                                NSParagraphStyleAttributeName : style
                                                                                                                                }];
    self.titleLabel.attributedText = attributedStr;
    [self.detailImageView sd_setImageWithURL:[NSURL URLWithString:self.schedule.imageUrl] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (image) {
            self.detailImageView.image = [image nyx_aspectFitImageWithSize:CGSizeMake(SCREEN_WIDTH - 30, (SCREEN_WIDTH - 30) / image.size.width * image.size.height)];
        }
    }];
}

- (void)tapAction:(UITapGestureRecognizer *)sender {
    ShowPhotosViewController *showPhotosVC = [[ShowPhotosViewController alloc] init];
    PreviewPhotosModel *model = [[PreviewPhotosModel alloc] init];
    model.original = self.schedule.imageUrl;
    NSMutableArray *photoArr = [NSMutableArray arrayWithObject:model];
    showPhotosVC.animateRect = [self.view convertRect:self.detailImageView.frame toView:self.view.window.rootViewController.view];
    showPhotosVC.imageModelMutableArray = photoArr;
    showPhotosVC.startInteger = 0;
    [self.view.window.rootViewController presentViewController:showPhotosVC animated:YES completion:nil];
}

#pragma mark - RefreshDelegate
- (void)refreshUI {
    NSLog(@"refresh called!");
    [self requestScheduleInfo];
}

@end
