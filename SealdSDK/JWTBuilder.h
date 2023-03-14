//
//  JWTBuilder.h
//  SealdSDK
//
//  Created by clement on 03/10/2023.
//  Copyright (c) 2023 Seald SAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JWT/JWT.h>

NS_ASSUME_NONNULL_BEGIN

@interface DemoAppJWTBuilder : NSObject

@property (nonatomic, copy, readonly) NSString* JWTSharedSecretId;
@property (nonatomic, copy, readonly) NSString* JWTSharedSecret;
@property (nonatomic, copy, readonly) id<JWTAlgorithm> JWTAlgorithm;

- (instancetype)initWithJWTSharedSecretId:(NSString *)JWTSharedSecretId JWTSharedSecret:(NSString *)JWTSharedSecret;
- (NSString *)signupJWT;
- (NSString *)connectorJWTWithCustomUserId:(NSString *)customUserId appId:(NSString *)appId;

@end

NS_ASSUME_NONNULL_END
