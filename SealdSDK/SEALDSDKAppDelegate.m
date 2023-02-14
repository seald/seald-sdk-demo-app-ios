//
//  SEALDSDKAppDelegate.m
//  SealdSDK
//
//  Created by clement on 02/13/2023.
//  Copyright (c) 2023 clement. All rights reserved.
//

#import "SEALDSDKAppDelegate.h"
#import <SealdSdk/SealdSdk.h>
#import <JWT/JWT.h>

@implementation SEALDSDKAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    NSString *databaseEncryptionKeyB64 = @"V4olGDOE5bAWNa9HDCvOACvZ59hUSUdKmpuZNyl1eJQnWKs5/l+PGnKUv4mKjivL3BtU014uRAIF2sOl83o6vQ";
    NSString *apiURL = @"https://api-dev.soyouz.seald.io/";
    NSString *appId = @"00000000-0000-1000-a000-7ea300000018";
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains
                (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];

    // Override point for customization after application launch.
    NSLog(@"SDK DEMO START");
    NSError *error = nil;
    Mobile_sdkInitializeOptions *initOpts = [[Mobile_sdkInitializeOptions alloc] init];
    initOpts.appId = appId;
    initOpts.apiURL = apiURL;
    initOpts.databaseEncryptionKeyB64 = databaseEncryptionKeyB64;
    initOpts.dbPath = [NSString stringWithFormat:@"%@/seald/inst1", documentsDirectory];
    initOpts.instanceName = @"inst1";
    NSLog(@"initOpts.appId  %@", initOpts.appId);
    Mobile_sdkMobileSDK *sdkInstance = Mobile_sdkInitialize(initOpts, &error);
    if (error != nil)
    {
        NSLog(@"Mobile_sdkInitialize ERROR %@", error.userInfo);
    }
    
    // GO JWT
    NSString *JWTSharedSecretId = @"00000000-0000-1000-a000-7ea300000019";
    NSString *JWTSharedSecret = @"o75u89og9rxc9me54qxaxvdutr2t4t25ozj4m64utwemm0osld0zdb02j7gv8t7x";
    id<JWTAlgorithm> algorithm = [JWTAlgorithmFactory algorithmByName:@"HS256"];

    NSDate *now = [NSDate date];
    NSDate *exp = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:30 toDate:now options:0];

    NSDictionary *headers = @{@"typ" : @"JWT"};
    NSDictionary *payload = @{@"iss" : JWTSharedSecretId,
                              @"iat" : [NSNumber numberWithDouble:now.timeIntervalSince1970],
                              @"exp" : [NSNumber numberWithDouble:exp.timeIntervalSince1970],
                              @"join_team": @YES,
                              @"scopes":@"-1"};
    
    NSString *token = [JWT encodePayload:payload].headers(headers).secret(JWTSharedSecret).algorithm(algorithm).encode;
    NSLog(@"JWT token %@", token);
    
    
    Common_modelsCreateAccountOptions *createAccountOpts = [[Common_modelsCreateAccountOptions alloc] init];
    createAccountOpts.displayName = @"MyName";
    createAccountOpts.signupJWT = token;
    createAccountOpts.deviceName = @"MyDeviceName";
    [sdkInstance createAccount:createAccountOpts error:&error];
    if (error != nil)
    {
        NSLog(@"createAccount ERROR %@", error.userInfo);
    }
    
    NSLog(@"SDK DEMO END");
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
