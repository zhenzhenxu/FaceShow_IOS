//
//  ResourceListViewController.m
//  FaceShowApp
//
//  Created by niuzhaowang on 2017/9/14.
//  Copyright © 2017年 niuzhaowang. All rights reserved.
//

#import "ResourceListViewController.h"
#import "EmptyView.h"
#import "ErrorView.h"
#import "ResourceCell.h"
#import "GetResourceRequest.h"
#import "ResourceDisplayViewController.h"
#import "GetResourceDetailRequest.h"
#import "PDFBrowser.h"

@interface ResourceListViewController ()<UITableViewDataSource,UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) EmptyView *emptyView;
@property (nonatomic, strong) ErrorView *errorView;
@property (nonatomic, strong) GetResourceRequest *request;
@property (nonatomic, strong) GetResourceDetailRequest *detailRequest;
@property (nonatomic, strong) NSArray *dataArray;
@property (nonatomic, strong) PDFBrowser *pdfBrowser;
@end

@implementation ResourceListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self requestResourceInfo];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)requestResourceInfo {
    [self.view nyx_startLoading];
    WEAK_SELF
    [self.request stopRequest];
    self.request = [[GetResourceRequest alloc] init];
    self.request.clazsId = [UserManager sharedInstance].userModel.projectClassInfo.data.clazsInfo.clazsId;
    [self.request startRequestWithRetClass:[GetResourceRequestItem class] andCompleteBlock:^(id retItem, NSError *error, BOOL isMock) {
        STRONG_SELF
        [self.view nyx_stopLoading];
        self.errorView.hidden = YES;
        self.emptyView.hidden = YES;
        if (error) {
            self.errorView.hidden = NO;
            return;
        }
        GetResourceRequestItem *item = (GetResourceRequestItem *)retItem;
        if (isEmpty(item.data.elements)) {
            self.emptyView.hidden = NO;
            return;
        }
        self.dataArray = [NSArray arrayWithArray:item.data.elements];
        [self.tableView reloadData];
    }];
}

- (void)requestResourceDetailWithResId:(NSString *)resId {
    [self.view nyx_startLoading];
    WEAK_SELF
    [self.detailRequest stopRequest];
    self.detailRequest = [[GetResourceDetailRequest alloc] init];
    self.detailRequest.resId = resId;
    [self.detailRequest startRequestWithRetClass:[GetResourceDetailRequestItem class] andCompleteBlock:^(id retItem, NSError *error, BOOL isMock) {
        STRONG_SELF
        [self.view nyx_stopLoading];
        if (error) {
            [self.view nyx_showToast:error.localizedDescription];;
            return;
        }
        GetResourceDetailRequestItem *item = (GetResourceDetailRequestItem *)retItem;
        if (item.data.type.integerValue > 0) {
            ResourceDisplayViewController *vc = [[ResourceDisplayViewController alloc] init];
            vc.urlString = item.data.url;
            vc.name = item.data.resName;
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            self.pdfBrowser = [[PDFBrowser alloc] init];
            self.pdfBrowser.urlString = item.data.ai.previewUrl;
            self.pdfBrowser.name = item.data.ai.resName;
            self.pdfBrowser.baseViewController = self;
            [self.pdfBrowser browseFile];
        }
    }];
}

#pragma mark - setupUI
- (void)setupUI {
    self.tableView = [[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithHexString:@"ebeff2"];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:[ResourceCell class] forCellReuseIdentifier:@"ResourceCell"];
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(0);
    }];
    
    self.emptyView = [[EmptyView alloc]init];
    [self.view addSubview:self.emptyView];
    [self.emptyView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(0);
    }];
    self.emptyView.hidden = YES;
    self.errorView = [[ErrorView alloc]init];
    WEAK_SELF
    [self.errorView setRetryBlock:^{
        STRONG_SELF
        [self requestResourceInfo];
    }];
    [self.view addSubview:self.errorView];
    [self.errorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(0);
    }];
    self.errorView.hidden = YES;
}

#pragma mark - UITableViewDataSource & UITableViewDelegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ResourceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ResourceCell"];
    cell.element = self.dataArray[indexPath.row];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArray.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    GetResourceRequestItem_Element *element = self.dataArray[indexPath.row];
    [self requestResourceDetailWithResId:element.resId];
}

#pragma mark - RefreshDelegate
- (void)refreshUI {
    NSLog(@"refresh called!");
    [self requestResourceInfo];
}

@end
