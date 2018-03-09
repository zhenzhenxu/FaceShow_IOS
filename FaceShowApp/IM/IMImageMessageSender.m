//
//  IMImageMessageSender.m
//  FaceShowApp
//
//  Created by niuzhaowang on 2018/3/9.
//  Copyright © 2018年 niuzhaowang. All rights reserved.
//

#import "IMImageMessageSender.h"
#import "IMDatabaseManager.h"
#import "IMManager.h"
#import "IMConfig.h"
#import "IMRequestManager.h"
#import "IMConnectionManager.h"
#import "QiniuDataManager.h"

NSString * const kIMImageUploadDidUpdateNotification = @"kIMImageUploadDidUpdateNotification";
NSString * const kIMImageUploadTopicKey = @"kIMImageUploadTopicKey";
NSString * const kIMImageUploadMessageKey = @"kIMImageUploadMessageKey";
NSString * const kIMImageUploadProgressKey = @"kIMImageUploadProgressKey";

@interface IMImageMessageSender()
@property (nonatomic, strong) NSMutableArray<IMImageMessage *> *msgArray;
@property (nonatomic, assign) BOOL isMsgSending;
//@property (nonatomic, strong) SaveTextMsgRequest *saveTextMsgRequest;
@property (nonatomic, strong) NSString *imageFolderPath;
@end

@implementation IMImageMessageSender
+ (IMImageMessageSender *)sharedInstance {
    static IMImageMessageSender *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[IMImageMessageSender alloc] init];
        manager.msgArray = [NSMutableArray array];
        manager.isMsgSending = NO;
        [manager createImageCacheFolderIfNotExist];
    });
    return manager;
}

- (void)createImageCacheFolderIfNotExist {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"im_image_cache"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if  (![fileManager fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    self.imageFolderPath = path;
}

- (void)addImageMessage:(IMImageMessage *)msg {
    IMTopicMessage *message = [[IMDatabaseManager sharedInstance]findMessageWithUniqueID:msg.uniqueID];
    if (!message) {
        NSString *reqId = [IMConfig generateUniqueID];
        message = [self imageMsgFromCurrentUserWithImage:msg.image topicID:msg.topicID uniqueID:reqId];
        msg.uniqueID = reqId;
    }
    message.sendState = MessageSendState_Sending;
    message.sendTime = [[NSDate date]timeIntervalSince1970]*1000 + [IMRequestManager sharedInstance].timeoffset;
    [[IMDatabaseManager sharedInstance]saveMessage:message];
    
    [self.msgArray addObject:msg];
    [self checkAndSend];
}

- (IMTopicMessage *)imageMsgFromCurrentUserWithImage:(UIImage *)image
                                           topicID:(int64_t)topicID
                                          uniqueID:(NSString *)uniqueID{
    IMTopicMessage *message = [[IMTopicMessage alloc]init];
    message.type = MessageType_Image;
    message.topicID = topicID;
    message.channel = [IMConfig generateUniqueID];
    message.uniqueID = uniqueID;
    message.sender = [[IMManager sharedInstance]currentMember];
    NSData *data = UIImageJPEGRepresentation(image, 1);
    NSString *path = [self.imageFolderPath stringByAppendingPathComponent:uniqueID];
    [data writeToFile:path atomically:YES];
    message.viewUrl = path;
    return message;
}

- (void)checkAndSend{
    if (self.isMsgSending || self.msgArray.count == 0) {
        return;
    }
    self.isMsgSending = YES;
    IMImageMessage *msg = [self.msgArray firstObject];
    if (!msg.topicID) {
        WEAK_SELF
        [[IMRequestManager sharedInstance]requestNewTopicWithMember:msg.otherMember completeBlock:^(IMTopic *topic, NSError *error) {
            STRONG_SELF
            if (error) {
                [self messageSentFailed:msg];
                [self sendNext];
                return;
            }
            // 更新topicid
            IMTopicMessage *message = [[IMDatabaseManager sharedInstance]findMessageWithUniqueID:msg.uniqueID];
            message.topicID = topic.topicID;
            [[IMDatabaseManager sharedInstance]saveMessage:message];
            // 订阅新的topic
            [[IMDatabaseManager sharedInstance]saveTopic:topic];
            [[IMConnectionManager sharedInstance]subscribeTopic:[IMConfig topicForTopicID:topic.topicID]];
            
            msg.topicID = topic.topicID;
            [self sendMessage:msg];
        }];
    }else {
        [self sendMessage:msg];
    }
}

- (void)sendMessage:(IMImageMessage *)imageMsg {
    NSData *data = UIImageJPEGRepresentation(imageMsg.image, 1);
    WEAK_SELF
    [[QiniuDataManager sharedInstance]uploadData:data withProgressBlock:^(CGFloat percent) {
        STRONG_SELF
        NSDictionary *info = @{kIMImageUploadTopicKey:@(imageMsg.topicID),
                               kIMImageUploadMessageKey:imageMsg.uniqueID,
                               kIMImageUploadProgressKey:@(percent)
                               };
        [[NSNotificationCenter defaultCenter]postNotificationName:kIMImageUploadDidUpdateNotification object:nil userInfo:info];
    } completeBlock:^(NSString *key, NSError *error) {
        STRONG_SELF
    }];
//    WEAK_SELF
//    [[IMRequestManager sharedInstance]requestSaveTextMsgWithMsg:textMsg completeBlock:^(IMTopicMessage *msg, NSError *error) {
//        STRONG_SELF
//        if (error) {
//            [self messageSentFailed:textMsg];
//        }else {
//            [[IMDatabaseManager sharedInstance]saveMessage:msg];
//        }
//        [self sendNext];
//    }];
}

- (void)messageSentFailed:(IMImageMessage *)msg {
    IMTopicMessage *message = [[IMDatabaseManager sharedInstance]findMessageWithUniqueID:msg.uniqueID];
    message.sendState = MessageSendState_Failed;
    [[IMDatabaseManager sharedInstance]saveMessage:message];
}

- (void)sendNext {
    [self.msgArray removeObjectAtIndex:0];
    self.isMsgSending = NO;
    [self checkAndSend];
}
@end
