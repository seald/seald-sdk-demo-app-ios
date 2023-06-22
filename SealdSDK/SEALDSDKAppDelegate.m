//
//  SEALDSDKAppDelegate.m
//  SealdSDK
//
//  Created by clement on 02/13/2023.
//  Copyright (c) 2023 Seald SAS. All rights reserved.
//

#import "SEALDSDKAppDelegate.h"
#import <SealdSdk/SealdSdk.h>
#import <SealdSdk/SealdSsksPasswordPlugin.h>
#import <SealdSdk/SealdSsksTMRPlugin.h>
#import <JWT/JWT.h>
#import "JWTBuilder.h"
#import "ssksBackend.h"

@implementation SEALDSDKAppDelegate

- (BOOL)application:(UIApplication* )application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    // Seald account infos:
    // First step with Seald: https://docs.seald.io/en/sdk/guides/1-quick-start.html
    // Create a team here: https://www.seald.io/create-sdk
    const SealdCredentials sealdCredentials = {
        .apiURL = @"https://api.staging-0.seald.io/",
        .appId = @"1e2600a5-417e-4333-93a6-2b196781b0de",
        .JWTSharedSecretId = @"32b4e3db-300b-4916-90e6-0020639c3df0",
        .JWTSharedSecret = @"VstlqoxvQPAxRTDa6cAzWiQiqcgETNP8yYnNyhGWXaI6uS7X5t8csh1xYeLTjTTO",
        .ssksURL = @"https://ssks.soyouz.seald.io/",
        .ssksBackendAppId = @"00000000-0000-0000-0000-000000000001",
        .ssksBackendAppKey = @"00000000-0000-0000-0000-000000000002",
        .ssksTMRChallenge = @"aaaaaaaa"
    };
    
    // Find database Path
    NSArray* paths = NSSearchPathForDirectoriesInDomains
                (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    NSString* sealdDir = [NSString stringWithFormat:@"%@/seald", documentsDirectory];
    
    // Delete local database from previous run
    NSLog(@"Deleting local database from previous run...");
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = nil;
    if ([fileManager removeItemAtPath:sealdDir error:&error]) {
       NSLog(@"Seald Database removed successfully");
    } else {
        NSLog(@"Error removing Seald database %@", error.userInfo);
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        testSealdSsksTMR(&sealdCredentials);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        testSealdSsksPassword(&sealdCredentials);
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        testSealdSDKWithCredentials(&sealdCredentials, sealdDir);
    });
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication*)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication*)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication*)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication*)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication*)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

NSString* randomString(int len) {
    NSString* letters = @"abcdefghijklmnopqrstuvwxyz0123456789";
    NSMutableString* randomString = [NSMutableString stringWithCapacity: len];

    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform((uint32_t)[letters length])]];
    }

    return randomString;
}

void testSealdSsksTMR(const SealdCredentials* sealdCredentials)
{
    NSError* error = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSString* randKey = randomString(64);
    NSData* rawTMRKey = [randKey dataUsingEncoding:NSUTF8StringEncoding];
    
    DemoAppSsksBackend* ssksBackend = [[DemoAppSsksBackend alloc] initWithSsksURL:sealdCredentials->ssksURL AppId:sealdCredentials->ssksBackendAppId AppKey:sealdCredentials->ssksBackendAppKey];
    
    NSString* rand = randomString(10);
    NSString* userId = [NSString stringWithFormat:@"user-%@", rand];
    NSString* userEM = [NSString stringWithFormat:@"user-%@@test.com", rand];
    NSData* userIdentity = [randKey dataUsingEncoding:NSUTF8StringEncoding]; // should be: [sealdSDKInstance exportIdentity]
    
    SealdSsksAuthFactor* authFactor = [[SealdSsksAuthFactor alloc] initWithValue:userEM type:@"EM"];
    
    SealdSsksBackendChallengeResponse* authSession = [ssksBackend challengeSendWithUserId:userId authFactor:authFactor createUser:@YES forceAuth:@YES error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    
    SealdSsksTMRPlugin* ssksTMR = [[SealdSsksTMRPlugin alloc] initWithSsksURL:sealdCredentials->ssksURL appId:sealdCredentials->appId];
    
    [ssksTMR saveIdentityAsync:authSession.sessionId authFactor:authFactor challenge:sealdCredentials->ssksTMRChallenge rawTMRSymKey:rawTMRKey identity:userIdentity completionHandler:^(NSError* error) {
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    __block SealdSsksRetrieveIdentityResponse* resp;
    [ssksTMR retrieveIdentityAsync:authSession.sessionId authFactor:authFactor challenge:sealdCredentials->ssksTMRChallenge rawTMRSymKey:rawTMRKey completionHandler:^(SealdSsksRetrieveIdentityResponse* response, NSError* error) {
        resp = response;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([userIdentity isEqualToData:resp.identity], @"invalid retrieved identity");
    NSCAssert(!resp.shouldRenewKey, @"invalid should renew key value");
}

void testSealdSsksPassword(const SealdCredentials* sealdCredentials)
{
    __block NSError*error = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    NSString* rand = randomString(10);
    NSString* userId = [NSString stringWithFormat:@"user-%@", rand];
    NSString* userPassword = userId;
    NSData* userIdentity = [rand dataUsingEncoding:NSUTF8StringEncoding]; // should be: [sealdSDKInstance exportIdentity]

    SealdSsksPasswordPlugin* ssksPassword = [[SealdSsksPasswordPlugin alloc] initWithSsksURL:sealdCredentials->ssksURL appId:sealdCredentials->appId];

    [ssksPassword saveIdentityAsyncWithUserId:userId password:userPassword identity:userIdentity completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);

    __block NSData* retrieveIdentity;
    [ssksPassword retrieveIdentityAsyncWithUserId:userId password:userPassword completionHandler:^(NSData* response, NSError* threadError) {
        retrieveIdentity = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([userIdentity isEqualToData:retrieveIdentity], @"invalid retrieved identity");

    NSString* newPassword = @"a new password";
    [ssksPassword changeIdentityPasswordAsyncWithUserId:userId currentPassword:userPassword newPassword:newPassword completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);

    __block NSData* retrieveIdentityWithNewPassword;
    [ssksPassword retrieveIdentityAsyncWithUserId:userId password:newPassword completionHandler:^(NSData* response, NSError* threadError) {
        retrieveIdentityWithNewPassword = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([userIdentity isEqualToData:retrieveIdentityWithNewPassword], @"invalid retrieved identity");

    // With raw keys
    NSString* rawStorageKey = randomString(32);
    NSData* rawEncryptionKey = [randomString(64) dataUsingEncoding:NSUTF8StringEncoding];
    NSString* userIdRawKeys = [NSString stringWithFormat:@"user-%@", [rawStorageKey substringWithRange:NSMakeRange(0, 10)]];

    [ssksPassword saveIdentityAsyncWithUserId:userIdRawKeys rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey identity:userIdentity completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);

    __block NSData* retrieveIdentityRawKeys;
    [ssksPassword retrieveIdentityAsyncWithUserId:userIdRawKeys rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey completionHandler:^(NSData* response, NSError* threadError) {
        retrieveIdentityRawKeys = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([userIdentity isEqualToData:retrieveIdentityRawKeys], @"invalid retrieved identity");

    NSData* emptyData = [NSData data];
    [ssksPassword saveIdentityAsyncWithUserId:userIdRawKeys rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey identity:emptyData completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    __block NSData* retrieveEmptyIdentity;
    [ssksPassword retrieveIdentityAsyncWithUserId:userIdRawKeys rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey completionHandler:^(NSData* response, NSError* threadError) {
        retrieveIdentityRawKeys = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error != nil, @"expected error");
    NSRange range = [error.localizedDescription rangeOfString:@"ssks password cannot find identity with this id/password combination"];
    NSCAssert(range.location != NSNotFound, @"invalid error");
}

void testSealdSDKWithCredentials(const SealdCredentials* sealdCredentials, const NSString* sealdDir)
{
    __block NSError* error = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // The Seald SDK uses a local database that will persist on disk.
    // When instantiating a SealdSDK, it is highly recommended to set a symmetric key to encrypt this database.
    // This demo will use a fixed key. It should be generated at signup, and retrieved from your backend at login.
    NSString* databaseEncryptionKeyB64 = @"V4olGDOE5bAWNa9HDCvOACvZ59hUSUdKmpuZNyl1eJQnWKs5/l+PGnKUv4mKjivL3BtU014uRAIF2sOl83o6vQ";
    
    // Seald uses JWT to manage licenses and identity.
    // JWTs should be generated by your backend, and sent to the user at signup.
    // The JWT secretId and secret can be generated from your administration dashboard. They should NEVER be on client side.
    // However, as this is a demo without a backend, we will use them on the frontend.
    // JWT documentation: https://docs.seald.io/en/sdk/guides/jwt.html
    // identity documentation: https://docs.seald.io/en/sdk/guides/4-identities.html
    DemoAppJWTBuilder* jwtbuilder = [[DemoAppJWTBuilder alloc] initWithJWTSharedSecretId:sealdCredentials->JWTSharedSecretId JWTSharedSecret:sealdCredentials->JWTSharedSecret];

    // let's instantiate 3 SealdSDK. They will correspond to 3 users that will exchange messages.
    SealdSdk* sdk1 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst1", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    SealdSdk* sdk2 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst2", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User2" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    SealdSdk* sdk3 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst3", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User3" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    
    SealdAccountInfo* retrieveNoAccount = [sdk1 getCurrentAccountInfo];
    NSCAssert(retrieveNoAccount == nil, @"retrieveNoAccount not nil");
    
    // Create the 3 accounts. Again, the signupJWT should be generated by your backend
    __block SealdAccountInfo* user1AccountInfo;
    [sdk1 createAccountAsyncWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser1" displayName:@"User1" expireAfter:0 completionHandler:^(SealdAccountInfo* response, NSError* threadError) {
        user1AccountInfo = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    __block SealdAccountInfo* user2AccountInfo;
    [sdk2 createAccountAsyncWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser2" displayName:@"User2" expireAfter:0 completionHandler:^(SealdAccountInfo* response, NSError* threadError) {
        user2AccountInfo = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    __block SealdAccountInfo* user3AccountInfo;
    [sdk3 createAccountAsyncWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser3" displayName:@"User3" expireAfter:0 completionHandler:^(SealdAccountInfo* response, NSError* threadError) {
        user3AccountInfo = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // retrieve info about current user before creating a user should return null
    __block SealdAccountInfo* retrieveAccountInfo;
    [sdk1 getCurrentAccountInfoAsyncWithCompletionHandler:^(SealdAccountInfo* response) {
        retrieveAccountInfo = response;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert([retrieveAccountInfo.userId isEqualToString:user1AccountInfo.userId], @"retrieveAccountInfo.userId incorrect");
    NSCAssert([retrieveAccountInfo.deviceId isEqualToString:user1AccountInfo.deviceId],  @"retrieveAccountInfo.deviceId incorrect");
    
    // Create group: https://docs.seald.io/sdk/guides/5-groups.html
    NSArray<NSString*>* members = [NSArray arrayWithObject:user1AccountInfo.userId];
    NSArray<NSString*>* admins = [NSArray arrayWithObject:user1AccountInfo.userId];
    __block NSString* groupId;
    [sdk1 createGroupAsyncWithGroupName:@"group-1" members:members admins:admins completionHandler:^(NSString* response, NSError* threadError) {
        groupId = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // Manage group members and admins
    [sdk1 addGroupMembersAsyncWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user2AccountInfo.userId] adminsToSet:[NSArray new] completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }]; // Add user2 as group member
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    [sdk1 addGroupMembersAsyncWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user3AccountInfo.userId] adminsToSet:[NSArray arrayWithObject:user3AccountInfo.userId] completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }]; // user1 adds user3 as group member and group admin
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    [sdk3 removeGroupMembersAsyncWithGroupId:groupId membersToRemove:[NSArray arrayWithObject:user2AccountInfo.userId] completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]); // user3 can remove user2
    [sdk3 setGroupAdminsAsyncWithGroupId:groupId addToAdmins:[NSArray new] removeFromAdmins:[NSArray arrayWithObject:user1AccountInfo.userId] completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }]; // user3 can remove user1 from admins
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // Create encryption session: https://docs.seald.io/sdk/guides/6-encryption-sessions.html
    NSArray<NSString*>* recipients = [NSArray arrayWithObjects:user1AccountInfo.userId, user2AccountInfo.userId, groupId, nil];
    __block SealdEncryptionSession* es1SDK1;
    [sdk1 createEncryptionSessionAsyncWithRecipients:recipients useCache:@YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es1SDK1 = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }]; // user1, user2, and group as recipients
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // The SealdEncryptionSession object can encrypt and decrypt for user1
    NSString* initialString = @"a message that needs to be encrypted!";
    __block NSString* encryptedMessage;
    [es1SDK1 encryptMessageAsync:initialString completionHandler:^(NSString* response, NSError* threadError) {
        encryptedMessage = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    __block NSString* decryptedMessage;
    [es1SDK1 decryptMessageAsync:encryptedMessage completionHandler:^(NSString* response, NSError* threadError) {
        decryptedMessage = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([decryptedMessage isEqualToString:initialString], @"decryptedMessage incorrect");
    
    // Create a test file on disk that we will encrypt/decrypt
    NSString* filename = @"testfile.txt";
    NSString* fileContent = @"File clear data.";
    NSString* filePath = [NSString stringWithFormat:@"%@/%@", sealdDir, filename];
    [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSCAssert(error == nil, [error localizedDescription]);

    // Encrypt the test file. Resulting file will be written alongside the source file, with `.seald` extension added
    NSString* encryptedFileURI = [es1SDK1 encryptFileFromURI:filePath error:&error];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    // User1 can retrieve the encryptionSession directly from the encrypted file
    __block SealdEncryptionSession* es1SDK1FromFile;
    [sdk1 retrieveEncryptionSessionAsyncFromFile:encryptedFileURI useCache:YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es1SDK1FromFile = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // The retrieved session can decrypt the file.
    // The decrypted file will be named with the name it had at encryption. Any renaming of the encrypted file will be ignored.
    // NOTE: In this example, the decrypted file will have `(1)` suffix to avoid overwriting the original clear file.
    __block NSString* decryptedFileURI;
    [es1SDK1FromFile decryptFileAsyncFromURI:encryptedFileURI completionHandler:^(NSString* response, NSError* threadError) {
        decryptedFileURI = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([decryptedFileURI hasSuffix:@"testfile (1).txt"], @"decryptedFileURI incorrect");
    NSString* decryptedFileContent = [NSString stringWithContentsOfFile:decryptedFileURI encoding:NSUTF8StringEncoding error:&error];
    NSCAssert([fileContent isEqualToString:decryptedFileContent], @"decryptedFileContent incorrect");

    // user1 can retrieve the EncryptionSession from the encrypted message
    __block SealdEncryptionSession* es1SDK1RetrieveFromMess;
    [sdk1 retrieveEncryptionSessionAsyncFromMessage:encryptedMessage useCache:@YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es1SDK1FromFile = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSString* decryptedMessageFromMess = [es1SDK1RetrieveFromMess decryptMessage:encryptedMessage error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([decryptedMessageFromMess isEqualToString:initialString], @"decryptedMessageFromMess incorrect");

    // user2 and user3 can retrieve the encryptionSession (from the encrypted message or the session ID).
    __block SealdEncryptionSession* es1SDK2;
    [sdk2 retrieveEncryptionSessionAsyncWithSessionId:es1SDK1.sessionId useCache:@YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es1SDK2 = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSString* decryptedMessageSDK2 = [es1SDK2 decryptMessage:encryptedMessage error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([decryptedMessageSDK2 isEqualToString:initialString], @"decryptedMessageSDK2 incorrect");
    
    __block SealdEncryptionSession* es1SDK3FromGroup;
    [sdk3 retrieveEncryptionSessionAsyncFromMessage:encryptedMessage useCache:@YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es1SDK3FromGroup = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSString* decryptedMessageSDK3 = [es1SDK3FromGroup decryptMessage:encryptedMessage error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([decryptedMessageSDK3 isEqualToString:initialString], @"decryptedMessageSDK3 incorrect");
    
    // user3 removes all members of "group-1". A group without member is deleted.
    [sdk3 removeGroupMembersAsyncWithGroupId:groupId membersToRemove:[NSArray arrayWithObjects:user1AccountInfo.userId, user3AccountInfo.userId, nil] completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // user3 could retrieve the previous encryption session only because "group-1" was set as recipient.
    // As the group was deleted, it can no longer access it.
    // user3 still has the encryption session in its cache, but we can disable it.
    [sdk3 retrieveEncryptionSessionAsyncFromMessage:encryptedMessage useCache:@YES completionHandler:^(SealdEncryptionSession* _, NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error != nil, @"expected error");
    NSRange range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSCAssert(range.location != NSNotFound, @"invalid error");
    error = nil;

    __block NSDictionary<NSString*, SealdActionStatus*>* respRevokeBefore;
    [es1SDK2 revokeRecipientsAsync:@[user3AccountInfo.userId] completionHandler:^(NSDictionary<NSString*, SealdActionStatus*>* response, NSError* threadError) {
        respRevokeBefore = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert(respRevokeBefore.count == 1, @"Unexpected response count.");
    NSCAssert(!respRevokeBefore[user3AccountInfo.userId].success, @"User ID mismatch.");
    
    // user2 adds user3 as recipient of the encryption session.
    __block NSDictionary<NSString*, SealdActionStatus*>* respAdd;
    [es1SDK2 addRecipientsAsync:[NSArray arrayWithObject:user3AccountInfo.userId] completionHandler:^(NSDictionary<NSString*, SealdActionStatus*>* response, NSError* threadError) {
        respAdd = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert(respAdd.count == 1, @"Unexpected response count.");
    NSCAssert(respAdd[user3AccountInfo.deviceId].success, @"User ID mismatch."); // Note that addRecipient return userId instead of deviceId

    // user3 can now retrieve it.
    __block SealdEncryptionSession* es1SDK3;
    [sdk3 retrieveEncryptionSessionAsyncWithSessionId:es1SDK1.sessionId useCache:@NO completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es1SDK3 = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    __block NSString* decryptedMessageAfterAdd;
    [es1SDK3 decryptMessageAsync:encryptedMessage completionHandler:^(NSString* response, NSError* threadError) {
        decryptedMessageAfterAdd = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([decryptedMessageAfterAdd isEqualToString:initialString], @"decryptedMessageAfterAdd incorrect");

    // user2 revokes user3 from the encryption session.
    __block NSDictionary<NSString*, SealdActionStatus*>* respRevoke;
    [es1SDK2 revokeRecipientsAsync:[NSArray arrayWithObject:user3AccountInfo.userId] completionHandler:^(NSDictionary<NSString*, SealdActionStatus*>* response, NSError* threadError) {
        respRevoke = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert(respRevoke.count == 1, @"Unexpected response count.");
    NSCAssert(respRevoke[user3AccountInfo.userId].success, @"Unexpected status.");

    // user3 cannot retrieve the session anymore
    [sdk3 retrieveEncryptionSessionAsyncWithSessionId:es1SDK1.sessionId useCache:@NO completionHandler:^(SealdEncryptionSession* _, NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error != nil, @"expected error");
    range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSCAssert(range.location != NSNotFound, @"invalid error");
    error = nil;
    
    // user1 revokes all other recipients from the session
    __block NSDictionary<NSString*, SealdActionStatus*>* respOther;
    [es1SDK1 revokeOthersAsyncWithCompletionHandler:^(NSDictionary<NSString*, SealdActionStatus*>* response, NSError* threadError) {
        respOther = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert(respOther.count == 3, @"Unexpected response count.");
    for (NSString* key in respOther) {
        NSCAssert(respOther[key].success, @"Unexpected status.");
    }
    
    // user2 cannot retrieve the session anymore
    [sdk2 retrieveEncryptionSessionAsyncFromMessage:encryptedMessage useCache:@NO completionHandler:^(SealdEncryptionSession* _, NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error != nil, @"expected error");
    range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSCAssert(range.location != NSNotFound, @"invalid error");
    error = nil;
    
    // user1 revokes all. It can no longer retrieve it.
    __block NSDictionary<NSString*, SealdActionStatus*>* respRevokeAll;
    [es1SDK1 revokeAllAsyncWithCompletionHandler:^(NSDictionary<NSString*, SealdActionStatus*>* response, NSError* threadError) {
        respRevokeAll = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert(respRevokeAll[user1AccountInfo.userId].success, @"Unexpected status.");

    [sdk1 retrieveEncryptionSessionAsyncWithSessionId:es1SDK1.sessionId useCache:@NO completionHandler:^(SealdEncryptionSession* _, NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error != nil, @"expected error");
    range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSCAssert(range.location != NSNotFound, @"invalid error");
    error = nil;

    // Create additional data for user1
    __block SealdEncryptionSession* es2SDK1;
    [sdk1 createEncryptionSessionAsyncWithRecipients:[NSArray arrayWithObject:user1AccountInfo.userId] useCache:@YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es2SDK1 = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSString* anotherMessage = @"Nobody should read that!";
    __block NSString* secondEncryptedMessage;
    [es2SDK1 encryptMessageAsync:anotherMessage completionHandler:^(NSString* response, NSError* threadError) {
        secondEncryptedMessage = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // user1 can renew its key, and still decrypt old messages
    [sdk1 renewKeysWithExpireAfter:5 * 365 * 24 * 60 * 60 error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    __block SealdEncryptionSession* es2SDK1AfterRenew;
    [sdk1 retrieveEncryptionSessionAsyncFromMessage:secondEncryptedMessage useCache:@YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es2SDK1AfterRenew = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    __block NSString* decryptedMessageAfterRenew;
    [es2SDK1AfterRenew decryptMessageAsync:secondEncryptedMessage completionHandler:^(NSString* response, NSError* threadError) {
        decryptedMessageAfterRenew = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([decryptedMessageAfterRenew isEqualToString:anotherMessage], @"invalid error");
    
    // CONNECTORS https://docs.seald.io/en/sdk/guides/jwt.html#adding-a-userid

    // we can add a custom userId using a JWT
    NSString* customConnectorJWTValue = @"user1-custom-id";
    NSString* addConnectorJWT = [jwtbuilder connectorJWTWithCustomUserId:customConnectorJWTValue appId:sealdCredentials->appId];
    [sdk1 pushJWT:addConnectorJWT error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    
    // we can list a user connectors
    __block NSArray<SealdConnector*>* connectors;
    [sdk1 listConnectorsAsyncWithCompletionHandler:^(NSArray<SealdConnector*>* response, NSError* threadError) {
        connectors = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSString* expectedConnectorValue = [NSString stringWithFormat:@"%@@%@", customConnectorJWTValue, sealdCredentials->appId];
    NSCAssert([connectors count] == 1, @"connectors count incorrect");
    NSCAssert([connectors[0].type isEqualToString:@"AP"], @"connectors[0].type incorrect");
    NSCAssert([connectors[0].state isEqualToString:@"VO"], @"connectors[0].state incorrect");
    NSCAssert([connectors[0].sealdId isEqualToString:user1AccountInfo.userId], @"connectors[0].sealdId incorrect");
    NSCAssert([connectors[0].value isEqualToString: expectedConnectorValue], @"connectors[0].value incorrect");
    
    // Retrieve connector by its id
    __block SealdConnector* retrievedConnector;
    [sdk1 retrieveConnectorAsyncWithConnectorId:connectors[0].connectorId completionHandler:^(SealdConnector* response, NSError* threadError) {
        retrievedConnector = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([retrievedConnector.type isEqualToString:@"AP"], @"retrievedConnector.type incorrect ");
    NSCAssert([retrievedConnector.state isEqualToString:@"VO"], @"retrievedConnector.state incorrect");
    NSCAssert([retrievedConnector.sealdId isEqualToString:user1AccountInfo.userId], @"retrievedConnector.sealdId incorrect");
    NSCAssert([retrievedConnector.value isEqualToString:expectedConnectorValue], @"retrievedConnector.value incorrect");
    
    // Retrieve connectors from a user id.
    __block NSArray<SealdConnector*>* connectorsFromSealdId;
    [sdk1 getConnectorsAsyncFromSealdId:user1AccountInfo.userId completionHandler:^(NSArray<SealdConnector*>* response, NSError* threadError) {
        connectorsFromSealdId = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([connectorsFromSealdId count] == 1, @"connectorsFromSealdId count incorrect");
    NSCAssert([connectorsFromSealdId[0].type isEqualToString:@"AP"], @"connectorsFromSealdId[0].type incorrect");
    NSCAssert([connectorsFromSealdId[0].state isEqualToString:@"VO"], @"connectorsFromSealdId[0].state incorrect");
    NSCAssert([connectorsFromSealdId[0].sealdId isEqualToString:user1AccountInfo.userId], @"connectorsFromSealdId[0].sealdId incorrect");
    NSCAssert([connectorsFromSealdId[0].value isEqualToString: expectedConnectorValue], @"connectorsFromSealdId[0].value incorrect");

    // Get sealdId of a user from a connector
    SealdConnectorTypeValue* connectorToSearch = [[SealdConnectorTypeValue alloc] initWithType:@"AP" value:expectedConnectorValue];
    __block NSArray* sealdIds;
    [sdk1 getSealdIdsAsyncFromConnectors:[NSArray arrayWithObject:connectorToSearch] completionHandler:^(NSArray* response, NSError* threadError) {
        sealdIds = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([sealdIds count] == 1, @"sealdIds count incorrect");
    NSCAssert([sealdIds[0] isEqualToString:user1AccountInfo.userId], @"user1AccountInfo.userId incorrect");
    
    // user1 can remove a connector
    [sdk1 removeConnectorAsyncWithConnectorId:connectors[0].connectorId completionHandler:^(SealdConnector* _, NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // verify that only no connector left
    __block NSArray<SealdConnector*>* connectorListAfterRevoke;
    [sdk1 listConnectorsAsyncWithCompletionHandler:^(NSArray<SealdConnector*>* response, NSError* threadError) {
        connectorListAfterRevoke = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([connectorListAfterRevoke count] == 0, @"connectorListAfterRevoke count incorrect");
    
    // user1 can export its identity
    __block NSData* exportedIdentity;
    [sdk1 exportIdentityAsyncWithCompletionHandler:^(NSData* response, NSError* threadError) {
        exportedIdentity = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // We can instantiate a new SealdSDK, import the exported identity
    SealdSdk* sdk1Exported = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst1Exported", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1Exported" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    [sdk1Exported importIdentityAsyncWithIdentity:exportedIdentity completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // SDK with imported identity can decrypt
    __block SealdEncryptionSession* es2SDK1Exported;
    [sdk1Exported retrieveEncryptionSessionAsyncFromMessage:secondEncryptedMessage useCache:@YES completionHandler:^(SealdEncryptionSession* response, NSError* threadError) {
        es2SDK1Exported = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);

    __block NSString* clearMessageExportedIdentity;
    [es2SDK1Exported decryptMessageAsync:secondEncryptedMessage completionHandler:^(NSString* response, NSError* threadError) {
        clearMessageExportedIdentity = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([clearMessageExportedIdentity isEqualToString:anotherMessage], @"clearMessageExportedIdentity incorrect");

    // user1 can create sub identity
    __block SealdCreateSubIdentityResponse* subIdentity;
    [sdk1 createSubIdentityAsyncWithDeviceName:@"Sub-device" expireAfter:365 * 24 * 60 * 60 completionHandler:^(SealdCreateSubIdentityResponse* response, NSError* threadError) {
        subIdentity = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert(subIdentity.deviceId != nil, @"subIdentity.deviceId invalid");
    
    // first device needs to reencrypt for the new device
    SealdMassReencryptOptions* massReencryptOpts = [[SealdMassReencryptOptions alloc] init];
    [sdk1 massReencryptAsyncWithDeviceId:subIdentity.deviceId options:massReencryptOpts completionHandler:^(SealdMassReencryptResponse* _, NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // We can instantiate a new SealdSDK, import the sub-device identity
    SealdSdk* sdk1SubDevice = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst1SubDevice", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1SubDevice" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSCAssert(error == nil, [error localizedDescription]);
    [sdk1SubDevice importIdentityAsyncWithIdentity:subIdentity.backupKey completionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // sub device can decrypt
    __block SealdEncryptionSession* es2SDK1SubDevice;
    [sdk1SubDevice retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:@YES error:&error];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    __block NSString* clearMessageSubdIdentity;
    [es2SDK1SubDevice decryptMessageAsync:secondEncryptedMessage completionHandler:^(NSString* response, NSError* threadError) {
        clearMessageSubdIdentity = response;
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    NSCAssert([clearMessageSubdIdentity isEqualToString:anotherMessage], @"clearMessageSubdIdentity invalid");
    
    // users can send heartbeat
    [sdk1 heartbeatAsyncWithCompletionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    
    // close SDKs
    [sdk1 closeAsyncWithCompletionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    [sdk2 closeAsyncWithCompletionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
    [sdk3 closeAsyncWithCompletionHandler:^(NSError* threadError) {
        error = threadError;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSCAssert(error == nil, [error localizedDescription]);
}

@end
