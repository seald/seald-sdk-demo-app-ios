//
//  SEALDSDKAppDelegate.m
//  SealdSDK
//
//  Created by clement on 02/13/2023.
//  Copyright (c) 2023 Seald SAS. All rights reserved.
//

#import "SEALDSDKAppDelegate.h"
#import <SealdSdk/SealdSdk.h>
#import "SealdSdkWrapper.h"
#import <JWT/JWT.h>

@implementation SEALDSDKAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"SDK DEMO START");
    
    NSString *databaseEncryptionKeyB64 = @"V4olGDOE5bAWNa9HDCvOACvZ59hUSUdKmpuZNyl1eJQnWKs5/l+PGnKUv4mKjivL3BtU014uRAIF2sOl83o6vQ";
    NSString *apiURL = @"https://api-dev.soyouz.seald.io/";
    NSString *appId = @"00000000-0000-1000-a000-7ea300000018";
    
    // Find database Path
    NSArray *paths = NSSearchPathForDirectoriesInDomains
                (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *sealdDir = [NSString stringWithFormat:@"%@/seald", documentsDirectory];
    
    NSLog(@"Removing existing database...");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fileManager removeItemAtPath:sealdDir error:&error]) {
       NSLog(@"Seald Database removed successfully");
    } else {
        NSLog(@"Error removing Seald database %@", error.userInfo);
    }

    SealdSdk *sdkWrapper = [[SealdSdk alloc] initWithApiUrl:apiURL appId:appId dbPath:[NSString stringWithFormat:@"%@/inst1", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"inst1" logLevel:0 encryptionSessionCacheTTL:0 keySize:4096 error:&error];
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
    NSLog(@"JWT %@", token);
    
    NSString *userId = [sdkWrapper createAccount:token deviceName:@"MyDeviceName" displayName:@"MyName" error:&error];
    if (error != nil)
    {
        NSLog(@"createAccount ERROR %@", error.userInfo);
    }
    NSLog(@"userId %@", userId);
    
    NSArray* members = [NSArray arrayWithObject:userId];
    NSString* groupId = [sdkWrapper createGroup:@"amzingGroupName" members:members admins:members error:&error];
    if (error != nil)
    {
        NSLog(@"createGroup ERROR %@", error.userInfo);
    }
    NSLog(@"groupId %@", groupId);

    EncryptionSession *es1SDK1 = [sdkWrapper createEncryptionSession:members useCache:@YES error:&error];
    if (error != nil)
    {
        NSLog(@"createEncryptionSession ERROR %@", error.userInfo);
    }
    
    NSString *encryptedMessage = [es1SDK1 encryptMessage:@"coucou" error:&error];
    if (error != nil)
    {
        NSLog(@"encryptMessage ERROR %@", error.userInfo);
    }
    NSLog(@"encryptedMessage %@", encryptedMessage);

    NSString *decryptedMessage = [es1SDK1 decryptMessage:encryptedMessage error:&error];
    if (error != nil)
    {
        NSLog(@"decryptMessage ERROR %@", error.userInfo);
    }
    NSLog(@"decryptMessage %@", decryptedMessage);
    
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
