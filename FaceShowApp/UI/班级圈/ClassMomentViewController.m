//
//  ClassMomentViewController.m
//  FaceShowApp
//
//  Created by niuzhaowang on 2017/9/13.
//  Copyright © 2017年 niuzhaowang. All rights reserved.
//

#import "ClassMomentViewController.h"
#import "UITableView+TemplateLayoutHeaderView.h"
#import "ClassMomentHeaderView.h"
#import "ClassMomentCell.h"
#import "ClassMomentTableHeaderView.h"
#import "ClassMomentFooterView.h"
#import "PublishMomentViewController.h"
#import "ClassMomentFloatingView.h"
#import "YXImagePickerController.h"
#import "CommentInputView.h"
#import "ClassMomentListFetcher.h"
#import "ClassMomentClickLikeRequest.h"
#import "ClassMomentCommentRequest.h"

@interface ClassMomentViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) ClassMomentTableHeaderView *headerView;
@property (nonatomic, strong) ClassMomentFloatingView *floatingView;
@property (nonatomic, strong) YXImagePickerController *imagePickerController;
@property (nonatomic, strong) CommentInputView *inputView;

@property (nonatomic, assign) NSInteger commtentInteger;

@property (nonatomic, strong) ClassMomentClickLikeRequest *clickLikeRequest;
@property (nonatomic, strong) ClassMomentCommentRequest *commentRequest;
@end

@implementation ClassMomentViewController
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    DDLogDebug(@"release========>>%@",[self class]);
}
- (void)viewDidLoad {
    ClassMomentListFetcher *fetcher = [[ClassMomentListFetcher alloc] init];
    fetcher.pagesize = 20;
    fetcher.clazsId = @"7";
    self.dataFetcher = fetcher;
    self.bIsGroupedTableViewStyle = YES;
    [super viewDidLoad];
    self.navigationItem.title = @"班级圈";
    [self setupUI];
    [self setupObservers];
//    self.edgesForExtendedLayout = UIRectEdgeAll;

}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.floatingView removeFromSuperview];
}
#pragma mark - set & get
- (YXImagePickerController *)imagePickerController
{
    if (_imagePickerController == nil) {
        _imagePickerController = [[YXImagePickerController alloc] init];
    }
    return _imagePickerController;
}
- (ClassMomentFloatingView *)floatingView {
    if (_floatingView == nil) {
        _floatingView = [[ClassMomentFloatingView alloc] init];
    }
    return _floatingView;
}
- (void)setCommtentInteger:(NSInteger)commtentInteger {
    _commtentInteger = commtentInteger;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - setupUI
- (void)setupUI {
    self.tableView.backgroundColor = [UIColor colorWithHexString:@"ebeff2"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:[ClassMomentHeaderView class] forHeaderFooterViewReuseIdentifier:@"ClassMomentHeaderView"];
    [self.tableView registerClass:[ClassMomentCell class] forCellReuseIdentifier:@"ClassMomentCell"];
    [self.tableView registerClass:[ClassMomentFooterView class] forHeaderFooterViewReuseIdentifier:@"ClassMomentFooterView"];
    self.headerView = [[ClassMomentTableHeaderView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 157.0f)];
    self.headerView.hidden = YES;
    self.tableView.tableHeaderView = self.headerView;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] init];
     WEAK_SELF
    [[tapGestureRecognizer rac_gestureSignal] subscribeNext:^(UITapGestureRecognizer *x) {
        STRONG_SELF
        [self hiddenInputTextView];
    }];
    [self.tableView addGestureRecognizer:tapGestureRecognizer];
    
    UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rightButton.frame = CGRectMake(0, 0, 40.0f, 40.0f);
    [rightButton setImage:[UIImage imageNamed:@"上传内容图标正常态"] forState:UIControlStateNormal];
    [rightButton setImage:[UIImage imageNamed:@"上传内容图标点击态"] forState:UIControlStateHighlighted];

    [[rightButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        STRONG_SELF
        [self showAlertView];
    }];
    UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] init];
    gestureRecognizer.minimumPressDuration = 1.0f;
    [[gestureRecognizer rac_gestureSignal] subscribeNext:^(UILongPressGestureRecognizer *x) {
        if (x.state == UIGestureRecognizerStateBegan) {
            [self presentNextPublishViewController:nil];
        }
    }];
    [rightButton addGestureRecognizer:gestureRecognizer];
    [self nyx_setupRightWithCustomView:rightButton];
    
    self.inputView = [[CommentInputView alloc]init];
    self.inputView.completeBlock = ^(NSString *text) {
        STRONG_SELF
        if (text.length == 0) {
            
        }else if (text.length > 250) {
            [self.view nyx_showToast:@"评论最多支持250字"];
        }else {
            [self requstForPublishComment:text];
        }
    };
    [self.view addSubview:self.inputView];
    [self.inputView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.mas_equalTo(0);
        make.height.mas_equalTo(100);
        make.bottom.mas_equalTo(100.0f);
    }];
}
- (void)hiddenInputTextView {
    ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[self.commtentInteger];
    moment.draftModel = self.inputView.textView.text;
    self.inputView.textView.text = nil;
    [self.inputView.textView resignFirstResponder];
    if (self.floatingView.superview != nil) {
        [self.floatingView removeFromSuperview];
    }
}
- (void)stopAnimation {
    [super stopAnimation];
    self.headerView.hidden = NO;
}
- (void)showAlertView {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    WEAK_SELF
    UIAlertAction *cancleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        STRONG_SELF
    }];
    [alertVC addAction:cancleAction];
    UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:@"拍照" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        STRONG_SELF
        [self.imagePickerController pickImageWithSourceType:UIImagePickerControllerSourceTypeCamera completion:^(UIImage *selectedImage) {
            STRONG_SELF
            [self presentNextPublishViewController:selectedImage];
        }];
    }];
    [alertVC addAction:cameraAction];
    UIAlertAction *photoAction = [UIAlertAction actionWithTitle:@"从相册选择" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        STRONG_SELF
        [self.imagePickerController pickImageWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary completion:^(UIImage *selectedImage) {
            STRONG_SELF
            [self presentNextPublishViewController:selectedImage];
        }];
    }];
    [alertVC addAction:photoAction];
    [[self nyx_visibleViewController] presentViewController:alertVC animated:YES completion:nil];
}
- (void)presentNextPublishViewController:(UIImage *)image {
    PublishMomentViewController *VC = [[PublishMomentViewController alloc] init];
    if (image != nil) {
        VC.imageArray = @[image];
    }
    VC.clazsId = @"7";
    WEAK_SELF
    VC.publishMomentDataBlock = ^(ClassMomentListRequestItem_Data_Moment *moment) {
        STRONG_SELF
        if (moment != nil) {
            self.emptyView.hidden = YES;
            self.errorView.hidden = YES;
            [self.dataArray insertObject:moment atIndex:0];
            [self.tableView reloadData];
        }

    };
    FSNavigationController *nav = [[FSNavigationController alloc] initWithRootViewController:VC];
    [self presentViewController:nav animated:YES completion:^{
        
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
            [self.inputView mas_updateConstraints:^(MASConstraintMaker *make) {
                if (SCREEN_HEIGHT == keyboardFrame.origin.y) {
                    make.bottom.mas_equalTo(-(SCREEN_HEIGHT -keyboardFrame.origin.y) + 100.0f);
                }else {
                    make.bottom.mas_equalTo(-(SCREEN_HEIGHT -keyboardFrame.origin.y) + 50.0f);
                }
            }];
            [self.view layoutIfNeeded];
        }];
    }];
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataArray.count;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[section];
    return moment.comments.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ClassMomentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ClassMomentCell" forIndexPath:indexPath];
    ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[indexPath.section];
    ClassMomentListRequestItem_Data_Moment_Comment *comment = moment.comments[indexPath.row];
    [cell reloadName:comment.publisher.realName withComment:comment.content withLast:indexPath.row + 1 == moment.comments.count];
    return cell;
}
#pragma mark - UITableViewDelegate
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    ClassMomentHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"ClassMomentHeaderView"];
    ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[section];
    headerView.moment = moment;
    WEAK_SELF
    headerView.classMomentLikeCommentBlock = ^(UIButton *sender) {
        STRONG_SELF
        CGRect rect = [sender convertRect:sender.bounds toView:self.view];
        [self showFloatView:rect withSection:section];
    };
    headerView.classMomentOpenCloseBlock = ^(BOOL isOpen) {
        STRONG_SELF
        moment.isOpen = [NSString stringWithFormat:@"%@",@(!isOpen)];
//        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:section];
//        [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView reloadData];
    };
    return headerView;
}
- (void)showFloatView:(CGRect)rect withSection:(NSInteger)section{
    if (self.floatingView.superview != nil) {
        [self.floatingView removeFromSuperview];
        return;
    }
    ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[section];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:NSNotFound inSection:section];
    if (moment.comments.count > 0) {
        indexPath = [NSIndexPath indexPathForRow:moment.comments.count - 1 inSection:section];
    }
    WEAK_SELF
    self.floatingView.classMomentFloatingBlock = ^(ClassMomentClickStatus status) {
        STRONG_SELF
        if (status == ClassMomentClickStatus_Comment) {
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            self.commtentInteger = section;
            if (moment.draftModel != nil) {
                self.inputView.textView.text = moment.draftModel;
            }
            [self.inputView.textView becomeFirstResponder];
        }else {
            [self requestForClickLike:section];
        }
    };
    [self.view addSubview:self.floatingView];
    __block BOOL isLike = NO;
    [moment.likes enumerateObjectsUsingBlock:^(ClassMomentListRequestItem_Data_Moment_Like *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.publisher.userID.integerValue == [UserManager sharedInstance].userModel.userID.integerValue) {
            isLike = YES;
            *stop = YES;
        }
    }];
    [self.floatingView reloadFloatingView:rect withStyle:isLike ? ClassMomentFloatingStyle_Comment : ClassMomentFloatingStyle_Double];
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    ClassMomentFooterView *footerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"ClassMomentFooterView"];
    return footerView;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [tableView yx_heightForHeaderWithIdentifier:@"ClassMomentHeaderView" configuration:^(ClassMomentHeaderView *headerView) {
        headerView.moment = self.dataArray[section];
    }];
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 16.0f;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [tableView fd_heightForCellWithIdentifier:@"ClassMomentCell" configuration:^(ClassMomentCell *cell) {
        ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[indexPath.section];
        ClassMomentListRequestItem_Data_Moment_Comment *comment = moment.comments[indexPath.row];
        [cell reloadName:comment.publisher.realName withComment:comment.content withLast:indexPath.row];
    }];
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self hiddenInputTextView];
}

#pragma mark - request
- (void)requestForClickLike:(NSInteger)section {
    ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[section];
    ClassMomentClickLikeRequest *request = [[ClassMomentClickLikeRequest alloc] init];
    request.clazsId = @"7";
    request.momentId = moment.momentID;
    WEAK_SELF
    [request startRequestWithRetClass:[ClassMomentClickLikeRequestItem class] andCompleteBlock:^(id retItem, NSError *error, BOOL isMock) {
        STRONG_SELF
        ClassMomentClickLikeRequestItem *item = retItem;
        if (item.data != nil) {
            if (moment.likes.count == 0) {
                NSMutableArray<ClassMomentListRequestItem_Data_Moment_Like> *mutableArray = [[NSMutableArray<ClassMomentListRequestItem_Data_Moment_Like> alloc] init];
                [mutableArray addObject:item.data];
                moment.likes = mutableArray;
            }else {
                [moment.likes addObject:item.data];
            }
            [self.tableView reloadData];
        }else {
            [self.view nyx_showToast:item.message];
        }
    }];
    self.clickLikeRequest = request;
}
- (void)requstForPublishComment:(NSString *)content {
    ClassMomentListRequestItem_Data_Moment *moment = self.dataArray[self.commtentInteger];
    ClassMomentCommentRequest *request = [[ClassMomentCommentRequest alloc] init];
    request.clazsId = @"7";
    request.momentId = moment.momentID;
    request.content = content;
    WEAK_SELF
    [request startRequestWithRetClass:[ClassMomentCommentRequestItem class] andCompleteBlock:^(id retItem, NSError *error, BOOL isMock) {
        STRONG_SELF
        ClassMomentCommentRequestItem *item = retItem;
        if (item.data != nil) {
            item.data.content = content;
            if (moment.comments.count == 0) {
                NSMutableArray<ClassMomentListRequestItem_Data_Moment_Comment> *mutableArray = [[NSMutableArray<ClassMomentListRequestItem_Data_Moment_Comment> alloc] init];
                [mutableArray addObject:item.data];
                moment.comments = mutableArray;
            }else {
                [moment.comments addObject:item.data];
            }
            moment.draftModel = nil;
            self.inputView.textView.text = nil;
            [self.tableView reloadData];
        }else {
            [self.view nyx_showToast:item.message];
        }
    }];
    self.commentRequest = request;
}
@end
