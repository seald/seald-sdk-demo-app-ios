//
//  SEALDSDKAppDelegate.h
//  SealdSDK
//
//  Created by clement on 02/13/2023.
//  Copyright (c) 2023 Seald SAS. All rights reserved.
//

@import UIKit;

@interface SEALDSDKAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow* window;
@property (strong, nonatomic) NSString* testSdkLabel;
@property (strong, nonatomic) NSString* testSsksPasswordLabel;
@property (strong, nonatomic) NSString* testSsksTmrLabel;

@end

typedef struct {
    const NSString* apiURL;
    const NSString* appId;
    const NSString* JWTSharedSecretId;
    const NSString* JWTSharedSecret;
    const NSString* ssksURL;
    const NSString* ssksBackendAppId;
    const NSString* ssksBackendAppKey;
    const NSString* ssksTMRChallenge;
} SealdCredentials;
