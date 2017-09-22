//
//  CourseCommentViewController.m
//  FaceShowApp
//
//  Created by niuzhaowang on 2017/9/15.
//  Copyright © 2017年 niuzhaowang. All rights reserved.
//

#import "CourseCommentViewController.h"
#import "CourseCommentCell.h"
#import "CourseCommentTitleView.h"
#import "CourseCommentHeaderView.h"
#import "CommentInputView.h"
#import "CourseCommentDataFetcher.h"
#import "SaveUserCommentRequest.h"
#import "LikeCommentRequest.h"

@interface CourseCommentViewController ()
@property (nonatomic, strong) CommentInputView *inputView;
@property (nonatomic, strong) NSString *stepId;
@property (nonatomic, strong) SaveUserCommentRequest *saveCommentRequest;
@property (nonatomic, strong) LikeCommentRequest *likeRequest;
@end

@implementation CourseCommentViewController

- (instancetype)initWithStepId:(NSString *)stepId {
    if (self = [super init]) {
        self.stepId = stepId;
    }
    return self;
}

- (void)viewDidLoad {
    self.bIsGroupedTableViewStyle = YES;
    CourseCommentDataFetcher *fetcher = [[CourseCommentDataFetcher alloc]init];
    fetcher.stepId = self.stepId;
    fetcher.lastID = 0;
    WEAK_SELF
    [fetcher setFinishBlock:^(GetCourseCommentRequestItem *item){
        STRONG_SELF
        if (item.data.elements.count > 0) {
            return;
        }
        if (self.dataArray.count == 0) {
            [self.view nyx_showToast:@"暂无评论"];
        }else {
            [self.view nyx_showToast:@"没有评论了"];
        }
    }];
    self.dataFetcher = fetcher;
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.title = @"课程讨论";
    [self.emptyView removeFromSuperview];
    [self setupUI];
    [self setupObservers];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupUI {
    NSString *title = self.questionTitle;
    CGFloat height = [CourseCommentTitleView heightForTitle:title];
    CourseCommentTitleView *headerView = [[CourseCommentTitleView alloc]initWithFrame:CGRectMake(0, 0, 100, height)];
    headerView.title = title;
    self.tableView.backgroundColor = [UIColor colorWithHexString:@"ebeff2"];
    self.tableView.tableHeaderView = headerView;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 100, 0);
    [self.tableView registerClass:[CourseCommentCell class] forCellReuseIdentifier:@"CourseCommentCell"];
    [self.tableView registerClass:[CourseCommentHeaderView class] forHeaderFooterViewReuseIdentifier:@"CourseCommentHeaderView"];
    
    self.inputView = [[CommentInputView alloc]init];
    WEAK_SELF
    [self.inputView setCompleteBlock:^(NSString *text){
        STRONG_SELF
        [self submitComment:text];
    }];
    [self.view addSubview:self.inputView];
    [self.inputView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.bottom.right.mas_equalTo(0);
        make.height.mas_equalTo(100);
    }];
}

- (void)setupObservers {
    WEAK_SELF
    [[[NSNotificationCenter defaultCenter]rac_addObserverForName:UIKeyboardWillChangeFrameNotification object:nil]subscribeNext:^(id x) {
        STRONG_SELF
        NSNotification *noti = (NSNotification *)x;
        NSDictionary *dic = noti.userInfo;
        NSValue *keyboardFrameValue = [dic valueForKey:UIKeyboardFrameEndUserInfoKey];
        CGRect keyboardFrame = keyboardFrameValue.CGRectValue;
        NSNumber *duration = [dic valueForKey:UIKeyboardAnimationDurationUserInfoKey];
        [UIView animateWithDuration:duration.floatValue animations:^{
            self.tableView.contentInset = UIEdgeInsetsMake(0, 0, [UIScreen mainScreen].bounds.size.height-keyboardFrame.origin.y+self.inputView.height, 0);
            
            [self.inputView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.bottom.mas_equalTo(-([UIScreen mainScreen].bounds.size.height-keyboardFrame.origin.y));
            }];
            [self.view layoutIfNeeded];
        }];
    }];
}

- (void)submitComment:(NSString *)text {
    if (isEmpty(text)) {
        return;
    }
    [self.saveCommentRequest stopRequest];
    self.saveCommentRequest = [[SaveUserCommentRequest alloc]init];
    self.saveCommentRequest.stepId = self.stepId;
    self.saveCommentRequest.content = text;
    [self.view nyx_startLoading];
    WEAK_SELF
    [self.saveCommentRequest startRequestWithRetClass:[HttpBaseRequestItem class] andCompleteBlock:^(id retItem, NSError *error, BOOL isMock) {
        STRONG_SELF
        [self.view nyx_stopLoading];
        if (error) {
            [self.view nyx_showToast:error.localizedDescription];
            return;
        }
        self.inputView.textView.text = nil;
        [self.view nyx_showToast:@"提交成功"];
    }];
}

- (void)favorCommentWithIndex:(NSInteger)index {
    GetCourseCommentRequestItem_element *element = self.dataArray[index];
    [self.likeRequest stopRequest];
    self.likeRequest = [[LikeCommentRequest alloc]init];
    self.likeRequest.commentRecordId = element.elementId;
    [self.view nyx_startLoading];
    WEAK_SELF
    [self.likeRequest startRequestWithRetClass:[LikeCommentRequestItem class] andCompleteBlock:^(id retItem, NSError *error, BOOL isMock) {
        STRONG_SELF
        [self.view nyx_stopLoading];
        if (error) {
            [self.view nyx_showToast:error.localizedDescription];
            return;
        }
        [self.view nyx_showToast:@"提交成功"];
        LikeCommentRequestItem *item = (LikeCommentRequestItem *)retItem;
        element.likeNum = item.data.userNum;
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CourseCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CourseCommentCell"];
    cell.bottomLineHidden = indexPath.row==self.dataArray.count-1;
    cell.item = self.dataArray[indexPath.row];
    WEAK_SELF
    [cell setFavorBlock:^{
        STRONG_SELF
        [self favorCommentWithIndex:indexPath.row];
    }];
    return cell;
}

#pragma mark - UITableViewDelegate
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CourseCommentHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"CourseCommentHeaderView"];
    header.countStr = [NSString stringWithFormat:@"%@",@(self.dataArray.count)];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 45;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.1;
}

@end
