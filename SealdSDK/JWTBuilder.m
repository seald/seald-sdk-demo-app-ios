//
//  JWTBuilder.m
//  SealdSdk
//
//  Created by Clement on 03/10/2023.
//  Copyright © 2023 Seald SAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JWT/JWT.h>

@interface DemoAppJWTBuilder : NSObject

typedef NS_ENUM(NSInteger, JWTPermission) {
ALL = -1,
ANONYMOUS_CREATE_MESSAGE = 0,
ANONYMOUS_FIND_KEY = 1,
ANONYMOUS_FIND_SIGCHAIN = 2,
JOIN_TEAM = 3,
ADD_CONNECTOR = 4
};

@property (nonatomic, copy, readonly) NSString* JWTSharedSecretId;
@property (nonatomic, copy, readonly) NSString* JWTSharedSecret;
@property (nonatomic, copy, readonly) id<JWTAlgorithm> JWTAlgorithm;

- (instancetype)initWithJWTSharedSecretId:(NSString*)JWTSharedSecretId JWTSharedSecret:(NSString*)JWTSharedSecret;

- (NSString*)signupJWT;

- (NSString*)connectorJWTWithCustomUserId:(NSString*)customUserId appId:(NSString*)appId;

@end

@implementation DemoAppJWTBuilder
- (instancetype)initWithJWTSharedSecretId:(NSString*)JWTSharedSecretId JWTSharedSecret:(NSString*)JWTSharedSecret {
if (self = [super init]) {
_JWTSharedSecretId = JWTSharedSecretId;
_JWTSharedSecret = JWTSharedSecret;
    _JWTAlgorithm = [JWTAlgorithmFactory algorithmByName:@"HS256"];
}
return self;
}

- (NSString*)signupJWT {
NSDate *now = [NSDate date];
NSDate *exp = [NSDate dateWithTimeInterval:26060 sinceDate:now];

NSDictionary *headers = @{@"alg" : @"HS256",
@"typ" : @"JWT"};
NSDictionary *payload = @{@"join_team": @YES,
@"scopes": @(JOIN_TEAM),
@"jti" : [[NSUUID UUID] UUIDString],
@"iss" : _JWTSharedSecretId,
@"iat" : @((NSInteger)now.timeIntervalSince1970),
@"exp" : @((NSInteger)exp.timeIntervalSince1970)};

NSString *token = [JWT encodePayload:payload].headers(headers).secret(_JWTSharedSecret).algorithm(_JWTAlgorithm).encode;

return token;
}

- (NSString*)connectorJWTWithCustomUserId:(NSString*)customUserId appId:(NSString*)appId {
NSDate *now = [NSDate date];
NSDate *exp = [NSDate dateWithTimeInterval:26060 sinceDate:now];

NSDictionary *headers = @{@"alg" : @"HS256",
@"typ" : @"JWT"};
NSDictionary *payload = @{@"scopes": @(ADD_CONNECTOR),
@"connector_add": @{@"type": @"AP", @"value": [NSString stringWithFormat:@"%@@%@", customUserId, appId]},
@"jti" : [[NSUUID UUID] UUIDString],
@"iss" : _JWTSharedSecretId,
@"iat" : @((NSInteger)now.timeIntervalSince1970),
@"exp" : @((NSInteger)exp.timeIntervalSince1970)};
NSString *token = [JWT encodePayload:payload].headers(headers).secret(_JWTSharedSecret).algorithm(_JWTAlgorithm).encode;

return token;
}

@end
