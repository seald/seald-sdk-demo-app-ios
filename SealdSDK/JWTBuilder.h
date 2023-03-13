//
//  JWTBuilder.h
//  SealdSDK
//
//  Created by clement on 03/10/2023.
//  Copyright (c) 2023 Seald SAS. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DemoAppJWTBuilder : NSObject

typedef NS_ENUM(NSInteger, JWTPermission) {
    JWTPermissionAll = -1,
    JWTPermissionAnonymousCreateMessage = 0,
    JWTPermissionAnonymousFindKey = 1,
    JWTPermissionAnonymousFindSigchain = 2,
    JWTPermissionJoinTeam = 3,
    JWTPermissionAddConnector = 4,
};

- (instancetype)initWithJWTSharedSecretId:(NSString *)JWTSharedSecretId JWTSharedSecret:(NSString *)JWTSharedSecret;
- (NSString *)signupJWT;
- (NSString *)connectorJWTWithCustomUserId:(NSString *)customUserId appId:(NSString *)appId;

@end

NS_ASSUME_NONNULL_END
