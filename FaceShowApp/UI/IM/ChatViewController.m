//
//  ChatViewController.m
//  FaceShowApp
//
//  Created by ZLL on 2018/1/8.
//  Copyright © 2018年 niuzhaowang. All rights reserved.
//

#import "ChatViewController.h"
#import "IMTopicMessage.h"
#import "IMManager.h"
#import "IMConnectionManager.h"
#import "IMUserInterface.h"
#import "IMRequestManager.h"
#import "IMMessageBaseCell.h"
#import "IMTextMessageBaseCell.h"
#import "IMMessageCellFactory.h"
#import "IMInputView.h"
#import "IMMessageCellDelegate.h"
#import "IMMessageMenuView.h"
#import "IMMessageTableView.h"
#import "IMTimeHandleManger.h"
#import "ImageSelectionHandler.h"
#import "IMImageMessageBaseCell.h"
#import "IMImageMessageLeftCell.h"
#import "IMImageMessageRightCell.h"
#import "UIImage+YXImage.h"
#import "PhotoBrowserController.h"
#import "IMChatViewModel.h"

@interface ChatViewController ()<UITableViewDataSource,UITableViewDelegate,IMMessageCellDelegate>
@property (strong,nonatomic)UIActivityIndicatorView *activity;
@property (nonatomic, strong) IMMessageTableView *tableView;
@property (nonatomic, strong) IMInputView *imInputView;
@property (nonatomic, strong) ImageSelectionHandler *imageHandler;
@property (nonatomic, strong) IMMessageMenuView *menuView;

@property (nonatomic, strong) NSMutableArray<IMChatViewModel *> *dataArray;
@property (assign,nonatomic)BOOL hasMore;
@property (assign,nonatomic)BOOL isRefresh;
@end

@implementation ChatViewController

- (void)dealloc {
    [self.menuView dismiss];
    [IMUserInterface clearDirtyMessages];
}

- (void)backAction {
    BLOCK_EXEC(self.exitBlock);
    [super backAction];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.topic) {
        [self setupTitleWithTopic:self.topic];
    }else {
        self.title = self.member.name;
    }
    self.imageHandler = [[ImageSelectionHandler alloc]init];
    [self setupUI];
    [self setupData];
    [self setupObserver];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupTitleWithTopic:(IMTopic *)topic {
    if (topic.type == TopicType_Group) {
        self.title = [NSString stringWithFormat:@"%@(%@)",self.topic.name,@(self.topic.members.count)];
    }else {
        [topic.members enumerateObjectsUsingBlock:^(IMMember * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
            if (item.memberID == [IMManager sharedInstance].currentMember.memberID) {
                self.title = topic.members[topic.members.count - idx - 1].name;
            }
        }];
    }
}

- (void)setupUI {
    self.imInputView = [[IMInputView alloc]init];
    self.imInputView.isChangeBool = YES;
    self.imInputView.textView.returnKeyType = UIReturnKeySend;
    WEAK_SELF
    self.imInputView.textHeightChangeBlock = ^(CGFloat textHeight) {
        STRONG_SELF
        [self.imInputView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(textHeight + 12.0f);
        }];
    };
    [self.imInputView setCompleteBlock:^(NSString *text){
        STRONG_SELF
        if (self.topic) {
            [IMUserInterface sendTextMessageWithText:text topicID:self.topic.topicID];
        }else {
            [IMUserInterface sendTextMessageWithText:text toMember:self.member fromGroup:self.groupId.integerValue];
        }
        if (self.imInputView.height > 50) {
            [UIView animateWithDuration:.3f animations:^{
                [self.imInputView mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.height.mas_equalTo(50.f);
                }];
                [self.view layoutIfNeeded];
            }];
        }
        self.imInputView.textString = @"";
        [self scrollToBottom];
    }];
    [self.imInputView setCameraButtonClickBlock:^{
        STRONG_SELF
        [self.imageHandler pickImageWithMaxCount:9 completeBlock:^(NSArray *array) {
            DDLogDebug(@"发送图片消息");
            for (UIImage *image in array) {
                if (self.topic) {
                    [IMUserInterface sendImageMessageWithImage:image topicID:self.topic.topicID];
                }else {
                    [IMUserInterface sendImageMessageWithImage:image toMember:self.member fromGroup:self.groupId.integerValue];
                }
            }
        }];
    }];
    [self.view addSubview:self.imInputView];
    [self.imInputView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.bottom.right.mas_equalTo(0);
        make.height.mas_equalTo(50.f);
    }];
    
    self.tableView = [[IMMessageTableView alloc]init];
    self.tableView.backgroundColor = [UIColor colorWithHexString:@"dfe3e5"];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:[IMMessageBaseCell class] forCellReuseIdentifier:@"IMMessageBaseCell"];
    [self.tableView registerClass:[IMTextMessageBaseCell class] forCellReuseIdentifier:@"IMTextMessageBaseCell"];
    [self.tableView registerClass:[IMTextMessageLeftCell class] forCellReuseIdentifier:@"IMTextMessageLeftCell"];
    [self.tableView registerClass:[IMTextMessageRightCell class] forCellReuseIdentifier:@"IMTextMessageRightCell"];
    [self.tableView registerClass:[IMImageMessageBaseCell class] forCellReuseIdentifier:@"IMImageMessageBaseCell"];
    [self.tableView registerClass:[IMImageMessageLeftCell class] forCellReuseIdentifier:@"IMImageMessageLeftCell"];
    [self.tableView registerClass:[IMImageMessageRightCell class] forCellReuseIdentifier:@"IMImageMessageRightCell"];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.estimatedRowHeight = 0.0f;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.mas_equalTo(0);
        make.bottom.equalTo(self.imInputView.mas_top);
    }];
    
    self.automaticallyAdjustsScrollViewInsets = false;  //第一个cell和顶部有留白，scrollerview遗留下来的，用来取消它
    UIView *headerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 20)];
    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activity.frame = CGRectMake(headerView.frame.size.width/2, 0, 20, 20);;
    [headerView addSubview:self.activity];
    self.tableView.tableHeaderView = headerView;
    headerView.hidden = YES;
}

- (void)setupData {
    WEAK_SELF
    [IMUserInterface findMessagesInTopic:self.topic.topicID count:5 asending:NO completeBlock:^(NSArray<IMTopicMessage *> *array, BOOL hasMore) {
        STRONG_SELF
        self.dataArray = [NSMutableArray array];
        for (IMTopicMessage *msg in array) {
            IMChatViewModel *model = [[IMChatViewModel alloc]init];
            model.message = msg;
            model.topicType = self.topic ? self.topic.type : TopicType_Private;
            [self.dataArray insertObject:model atIndex:0];
        }
        [self handelTimeForDataSource:self.dataArray];
        self.hasMore = hasMore;
        [self.tableView reloadData];
        [self scrollToBottom];
    }];
}

- (void)handelTimeForDataSource:(NSMutableArray *)dataArray {
    IMChatViewModel *model;
    NSTimeInterval lastVisibleTime = 0.0;
    for (int i=0; i<dataArray.count; i++) {
        model = [dataArray objectAtIndex:i];
        IMTopicMessage *msg = model.message;
        if (i == 0) {
            model.isTimeVisible = YES;
            lastVisibleTime = msg.sendTime;
        }else {
            int timeSpan=(int)[IMTimeHandleManger compareTime1:lastVisibleTime withTime2:msg.sendTime type:IMTimeType_Minute];
            if (timeSpan >= 5) {
                model.isTimeVisible = YES;
                lastVisibleTime = msg.sendTime;
            }else if (timeSpan < 0) {
                model.isTimeVisible = YES;
                lastVisibleTime = msg.sendTime;
            }else {
                model.isTimeVisible = NO;
            }
        }
        dataArray[i] = model;
    }
}

- (void)setHasMore:(BOOL)hasMore {
    _hasMore = hasMore;
    self.tableView.tableHeaderView.hidden = !hasMore;
}

- (void)scrollToBottom {
    if (self.dataArray.count >= 1) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.dataArray.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
}

- (void)setupObserver {
    WEAK_SELF
    [[[NSNotificationCenter defaultCenter]rac_addObserverForName:kIMMessageDidUpdateNotification object:nil]subscribeNext:^(id x) {
        STRONG_SELF
        NSNotification *noti = (NSNotification *)x;
        IMTopicMessage *message = noti.object;
        for (IMChatViewModel *model in self.dataArray) {
            IMTopicMessage *item = model.message;
            if ([item.uniqueID isEqualToString:message.uniqueID]) {
                NSUInteger index = [self.dataArray indexOfObject:model];
                model.message = message;
                [self.dataArray replaceObjectAtIndex:index withObject:model];
//                [self.tableView reloadData];
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                return;
            }
        }
        IMChatViewModel *model = [[IMChatViewModel alloc]init];
        model.message = message;
        model.topicType = self.topic ? self.topic.type : TopicType_Private;
        [self.dataArray addObject:model];
        [self handelTimeForDataSource:self.dataArray];
//        [self.tableView reloadData];
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.dataArray.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        [self scrollToBottom];
    }];
    
    [[[NSNotificationCenter defaultCenter]rac_addObserverForName:UIKeyboardWillChangeFrameNotification object:nil]subscribeNext:^(id x) {
        STRONG_SELF
        NSNotification *noti = (NSNotification *)x;
        NSDictionary *dic = noti.userInfo;
        NSValue *keyboardFrameValue = [dic valueForKey:UIKeyboardFrameEndUserInfoKey];
        CGRect keyboardFrame = keyboardFrameValue.CGRectValue;
        NSNumber *duration = [dic valueForKey:UIKeyboardAnimationDurationUserInfoKey];
        [UIView animateWithDuration:duration.floatValue animations:^{
            [self.imInputView mas_updateConstraints:^(MASConstraintMaker *make) {
                make.bottom.mas_equalTo(-([UIScreen mainScreen].bounds.size.height-keyboardFrame.origin.y));
            }];
            [self.view layoutIfNeeded];
        }];
        [self scrollToBottom];
    }];
    
    [[[NSNotificationCenter defaultCenter]rac_addObserverForName:kIMTopicDidUpdateNotification object:nil]subscribeNext:^(id x) {
        STRONG_SELF
        NSNotification *noti = (NSNotification *)x;
        IMTopic *topic = noti.object;

        if (self.topic && self.topic.topicID == topic.topicID) {//有话题
            self.topic = topic;
            [self setupTitleWithTopic:topic];
            return;
        }
        if (topic.type == TopicType_Private) {
            for (IMMember *item in topic.members) {
                if (self.member.memberID) {
                    if (item.memberID == self.member.memberID) {
                        self.topic = topic;
                        return;
                    }
                }
                if (item.userID == self.member.userID) {
                    self.topic = topic;
                    return;
                }
            }
        }
    }];
    [[[NSNotificationCenter defaultCenter]rac_addObserverForName:kIMImageUploadDidUpdateNotification object:nil]subscribeNext:^(id x) {
        STRONG_SELF
        NSNotification *noti = (NSNotification *)x;
        int64_t topicID = ((NSNumber *)[noti.userInfo valueForKey:kIMImageUploadTopicKey]).longLongValue;
        NSString *uniqueId = [noti.userInfo valueForKey:kIMImageUploadMessageKey];
        CGFloat percent = ((NSNumber *)[noti.userInfo valueForKey:kIMImageUploadProgressKey]).floatValue;
        if (self.topic.topicID != topicID) {
            return;
        }
        for (IMChatViewModel *model in self.dataArray) {
            IMTopicMessage *item = model.message;
            if ([item.uniqueID isEqualToString:uniqueId]) {
                NSUInteger index = [self.dataArray indexOfObject:model];
                model.percent = percent;
                [self.dataArray replaceObjectAtIndex:index withObject:model];
                return;
            }
        }
    }];
}

#pragma mark - UITableViewDataSource & UITableViewDelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IMMessageBaseCell *cell = [IMMessageCellFactory cellWithMessageModel:self.dataArray[indexPath.row]];
    cell.model = self.dataArray[indexPath.row];
    cell.delegate = self;
    //测试图片
    //    IMImageMessageLeftCell *cell = [[IMImageMessageLeftCell alloc]init];
    //    IMTopicMessage *message = [[IMTopicMessage alloc]init];
    //    message.type = MessageType_Image;
    //    IMMember *mem = [[IMMember alloc]init];
    //    mem.name = @"发送者";
    //    mem.avatar = @"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1520226683021&di=f4f8c422c2a55a2f0fdeeecb9a51060b&imgtype=0&src=http%3A%2F%2Fpic.58pic.com%2F58pic%2F13%2F68%2F11%2F35W58PICzbv_1024.jpg";
    //    message.sender = mem;
    //    message.sender.name = @"发送者";
    //    message.sendState = MessageSendState_Sending;
    //    message.thumbnail = @"http://img5.imgtn.bdimg.com/it/u=4005232556,476955445&fm=27&gp=0.jpg";
    //    //@"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1520226599946&di=58056cbae9f7d5b2bda8c3b7cae51652&imgtype=0&src=http%3A%2F%2Fpic54.nipic.com%2Ffile%2F20141201%2F13740598_112413393000_2.jpg";
    //    cell.message = message;
    //    cell.topicType = TopicType_Group;
    //    cell.delegate = self;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    IMChatViewModel *model = self.dataArray[indexPath.row];
    return model.height;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.imInputView endEditing:YES];
    [self.imInputView resignFirstResponder];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y < 0  && self.hasMore && !self.isRefresh) {
        [self loadMoreHistoryData];
    }
}

- (void)loadMoreHistoryData {
    WEAK_SELF
    [self.activity startAnimating];
    self.isRefresh = YES;
    IMChatViewModel *model = self.dataArray.firstObject;
    [IMUserInterface findMessagesInTopic:self.topic.topicID count:5 beforeMsg:model.message completeBlock:^(NSArray<IMTopicMessage *> *array, BOOL hasMore) {
        STRONG_SELF
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.hasMore = hasMore;
            [self.activity stopAnimating];
            if (array.count > 0) {
                NSMutableArray *resultArray = [NSMutableArray array];
                for (NSInteger i = 0; i < array.count; i ++) {
                    IMChatViewModel *model = [[IMChatViewModel alloc]init];
                    model.topicType = self.topic ? self.topic.type : TopicType_Private;
                    model.message = array[i];
                    [self.dataArray insertObject:model atIndex:0];
                    [resultArray insertObject:model atIndex:0];
                }
                [self handelTimeForDataSource:resultArray];
                [self.tableView reloadData];
            }
            self.isRefresh = NO;
        });
    }];
}

#pragma mark - IMMessageCellDelegate
- (void)messageCellDidClickAvatarForUser:(IMMember *)user {
    [self.view nyx_showToast:@"click avatar to do ..."];
}

- (void)messageCellTap:(IMChatViewModel *)model {
    [self.view nyx_showToast:@"click image to do ..."];
    UIImage *image;
    if (model.message.sendState == MessageSendState_Success) {
        NSURL *url = [NSURL URLWithString:model.message.viewUrl];
        NSData *data = [NSData dataWithContentsOfURL:url];
        image = [UIImage imageWithData:data];
    }else {
        image = [model.message imageWaitForSending];
    }
    NSMutableArray *array = [NSMutableArray arrayWithObject:image];
    PhotoBrowserController *vc = [[PhotoBrowserController alloc] init];
    vc.cantNotDeleteImage = YES;
    vc.images = array;
    vc.currentIndex = 0;
    WEAK_SELF
    vc.didDeleteImage = ^{
        STRONG_SELF
        
    };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)messageCellLongPress:(IMChatViewModel *)model rect:(CGRect)rect {
    DDLogDebug(@"long press to do ...");
    NSInteger row = [self.dataArray indexOfObject:model];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    rect.origin.y += cellRect.origin.y - self.tableView.contentOffset.y;
    
    IMTopicMessage *message = model.message;
    WEAK_SELF
    [self.menuView setMenuItemActionBlock:^(IMMessageMenuItemType type) {
        STRONG_SELF
        if (type == IMMessageMenuItemType_Copy) {
            NSString *str = message.text;
            [[UIPasteboard generalPasteboard] setString:str];
        }
    }];
    
    NSMutableArray *array = [NSMutableArray array];
    IMMessageMenuItemModel *model0 = [[IMMessageMenuItemModel alloc]init];
    model0.title = @"复制";
    model0.type = IMMessageMenuItemType_Copy;
    [array addObject:model0];
    
    IMMessageMenuItemModel *model1 = [[IMMessageMenuItemModel alloc]init];
    model1.title = @"删除";
    model1.type = IMMessageMenuItemType_Delete;
    [array addObject:model1];
    
    IMMessageMenuItemModel *model2 = [[IMMessageMenuItemModel alloc]init];
    model2.title = @"取消";
    model2.type = IMMessageMenuItemType_Cancel;
    [array addObject:model2];
    
    [self.menuView addMenuItemModels:array.copy];
    
    [self.menuView showInView:self.tableView  withRect:rect];
}

- (void)messageCellDoubleClick:(IMChatViewModel *)mmodel {
    [self.view nyx_showToast:@"double click to do ..."];
}

- (void)messageCellDidClickStateButton:(IMChatViewModel *)model rect:(CGRect)rect {
    DDLogDebug(@"click state button to do ...");
    if ([self isFirstResponder]) {
        [self resignFirstResponder];
    }
    NSInteger row = [self.dataArray indexOfObject:model];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    rect.origin.y += cellRect.origin.y - self.tableView.contentOffset.y;
    
    IMTopicMessage *message = model.message;
    WEAK_SELF
    [self.menuView setMenuItemActionBlock:^(IMMessageMenuItemType type) {
        STRONG_SELF
        if (type == IMMessageMenuItemType_Resend) {
            if ([self.dataArray containsObject:model]) {
                NSUInteger index = [self.dataArray indexOfObject:model];
                [self.dataArray removeObjectAtIndex:index];
                [self.dataArray addObject:model];
                [self handelTimeForDataSource:self.dataArray];
                [self.tableView reloadData];
            }
            if (message.type == MessageType_Text) {
                [IMUserInterface sendTextMessageWithText:message.text topicID:self.topic.topicID uniqueID:message.uniqueID];
            }else if (message.type == MessageType_Image) {
                [IMUserInterface sendImageMessageWithImage:[message imageWaitForSending] topicID:self.topic.topicID uniqueID:message.uniqueID];
            }
        }
    }];
    
    NSMutableArray *array = [NSMutableArray array];
    IMMessageMenuItemModel *model0 = [[IMMessageMenuItemModel alloc]init];
    model0.title = @"重试";
    model0.type = IMMessageMenuItemType_Resend;
    [array addObject:model0];
    
    IMMessageMenuItemModel *model1 = [[IMMessageMenuItemModel alloc]init];
    model1.title = @"取消";
    model1.type = IMMessageMenuItemType_Delete;
    [array addObject:model1];
    
    [self.menuView addMenuItemModels:array.copy];
    
    [self.menuView showInView:self.tableView  withRect:rect];
}

- (void)messageCellUpdateHeight:(IMChatViewModel *)model {
    NSInteger row = [self.dataArray indexOfObject:model];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (IMMessageMenuView *)menuView {
    if (_menuView == nil) {
        _menuView = [[IMMessageMenuView alloc] init];
    }
    return _menuView;
}

@end
