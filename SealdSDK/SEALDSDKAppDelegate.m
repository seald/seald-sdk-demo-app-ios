//
//  SEALDSDKAppDelegate.m
//  SealdSDK
//
//  Created by clement on 02/13/2023.
//  Copyright (c) 2023 Seald SAS. All rights reserved.
//

#import "SEALDSDKAppDelegate.h"
#import <SealdSdk/SealdSdk.h>
#import <SealdSdk/Utils.h>
#import <SealdSdk/SealdSsksPasswordPlugin.h>
#import <SealdSdk/SealdSsksTMRPlugin.h>
#import "JWTBuilder.h"
#import "ssksBackend.h"
#import "credentials.h"


NSString* randomString(int len) {
    NSString* letters = @"abcdefghijklmnopqrstuvwxyz0123456789";
    NSMutableString* str = [NSMutableString stringWithCapacity:len];

    for (int i = 0; i < len; i++) {
        [str appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }

    return str;
}

NSData* randomData(int len) {
    NSMutableData* randomData = [NSMutableData dataWithCapacity:len];

    for (NSInteger i = 0; i < len; i++) {
        uint8_t randomByte = arc4random_uniform(UINT8_MAX);
        [randomData appendBytes:&randomByte length:1];
    }

    return randomData;
}

// In ObjC, these tests will all use synchronous variants of the methods,
// in order to be more readable.
// Async variants of all methods, with `completionHandler`s, also exist.

BOOL testSealdSsksTMR(void)
{
    @try {
        NSError* error = nil;

        // rawTMRSymKey is a secret, generated and stored by your _backend_, unique for the user.
        // It can be retrieved by client-side when authenticated (usually as part of signup/sign-in call response).
        // This *MUST* be a cryptographically random NSData of 64 bytes.
        NSData* rawTMRSymKey = randomData(64);

        DemoAppSsksBackend* ssksBackend = [[DemoAppSsksBackend alloc] initWithSsksURL:sealdCredentials.ssksURL AppId:sealdCredentials.appId AppKey:sealdCredentials.ssksBackendAppKey];

        // First, we need to simulate a user. For a simpler example, we will use random data.
        // userId is the ID of the user in your app.
        NSString* rand = randomString(10);
        NSString* userId = [NSString stringWithFormat:@"user-%@", rand];
        // userIdentity is the user's exported identity that you want to store on SSKS
        NSData* userIdentity = randomData(64); // should be: [sealdSDKInstance exportIdentity]

        SealdSsksTMRPlugin* ssksTMR = [[SealdSsksTMRPlugin alloc] initWithSsksURL:sealdCredentials.ssksURL appId:sealdCredentials.appId instanceName:@"SsksTmr" logLevel:-1 logNoColor:YES];

        // Define an AuthFactor: the user's email address.
        // AuthFactor can be an email `AuthFactorType.EM` or a phone number `AuthFactorType.SMS`
        NSString* userEM = [NSString stringWithFormat:@"user-%@@test.com", rand];
        SealdTmrAuthFactor* authFactor = [[SealdTmrAuthFactor alloc] initWithValue:userEM type:@"EM"];

        // The app backend creates a session to save the identity.
        // This is the first time that this email is storing an identity, so `must_authenticate` is false.
        SealdSsksBackendChallengeResponse* authSessionSave =
            [ssksBackend challengeSendWithUserId:userId
                                      authFactor:authFactor
                                      createUser:YES
                                       forceAuth:NO
                                         fakeOtp:YES // `fakeOtp` is only on the staging server, to force the challenge to be 'aaaaaaaa'. In production, you cannot use this.
                                           error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionSave.mustAuthenticate == NO, @"unexpected mustAuthenticate value 1");

        // Saving the identity. No challenge necessary because `must_authenticate` is false.
        SealdSsksSaveIdentityResponse* saveIdentityRes1 = [ssksTMR saveIdentity:authSessionSave.sessionId
                                                                     authFactor:authFactor
                                                                   rawTMRSymKey:rawTMRSymKey
                                                                       identity:userIdentity
                                                                          error:&error];
        NSCAssert(![saveIdentityRes1.ssksId isEqualToString:@""], @"saveIdentityRes1.ssksId empty");
        NSCAssert(saveIdentityRes1.authenticatedSessionId == nil, @"saveIdentityRes1.authenticatedSessionId not nil");

        // The app backend creates another session to retrieve the identity.
        // The identity is already saved, so `must_authenticate` is true.
        SealdSsksBackendChallengeResponse* authSessionRetrieve =
            [ssksBackend challengeSendWithUserId:userId
                                      authFactor:authFactor
                                      createUser:YES
                                       forceAuth:NO
                                         fakeOtp:YES // `fakeOtp` is only on the staging server, to force the challenge to be 'aaaaaaaa'. In production, you cannot use this.
                                           error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionRetrieve.mustAuthenticate == YES, @"unexpected mustAuthenticate value 2");

        // Retrieving identity. Challenge is necessary for this.
        SealdSsksRetrieveIdentityResponse* retrieveResp = [ssksTMR retrieveIdentity:authSessionRetrieve.sessionId
                                                                         authFactor:authFactor
                                                                       rawTMRSymKey:rawTMRSymKey
                                                           // on this test server, the challenge is fixed. In an actual app, this will be the challenge recieved by the user by email or SMS.
                                                                          challenge:sealdCredentials.ssksTMRChallenge
                                                                              error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([userIdentity isEqualToData:retrieveResp.identity], @"invalid retrieved identity TMR1");
        NSCAssert(retrieveResp.shouldRenewKey == YES, @"invalid should renew key value 1");

        // If initial key has been saved without being fully authenticated, you should renew the user's private key, and save it again.
        // sdk.renewKeys(Duration.ofDays(365 * 5))

        // Let's simulate the renew with another random identity
        NSData* identitySecondKey = randomData(64); // should be: [sealdSDKInstance exportIdentity]
        // to save the newly renewed identity on the server, you can use the `authenticatedSessionId` from the response to `retrieveIdentity`, with no challenge
        [ssksTMR saveIdentity:retrieveResp.authenticatedSessionId authFactor:authFactor rawTMRSymKey:rawTMRSymKey identity:identitySecondKey challenge:@"" error:&error];
        // to save the newly renewed identity on the server, you can use the `authenticatedSessionId` from the response to `retrieveIdentity`, with no challenge
        SealdSsksSaveIdentityResponse* saveIdentityRes2 = [ssksTMR saveIdentity:retrieveResp.authenticatedSessionId
                                                                     authFactor:authFactor
                                                                   rawTMRSymKey:rawTMRSymKey
                                                                       identity:identitySecondKey
                                                                          error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([saveIdentityRes2.ssksId isEqualToString:saveIdentityRes1.ssksId], @"saveIdentityRes2.ssksId different from saveIdentityRes1.ssksId");
        NSCAssert(saveIdentityRes2.authenticatedSessionId == nil, @"saveIdentityRes2.authenticatedSessionId not nil");

        // And now let's retrieve this new saved identity
        SealdSsksBackendChallengeResponse* authSessionRetrieve2 =
            [ssksBackend challengeSendWithUserId:userId
                                      authFactor:authFactor
                                      createUser:YES
                                       forceAuth:NO
                                         fakeOtp:YES // `fakeOtp` is only on the staging server, to force the challenge to be 'aaaaaaaa'. In production, you cannot use this.
                                           error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionRetrieve2.mustAuthenticate == YES, @"unexpected mustAuthenticate value 3");
        SealdSsksRetrieveIdentityResponse* retrieveResp2 = [ssksTMR retrieveIdentity:authSessionRetrieve2.sessionId
                                                                          authFactor:authFactor
                                                                        rawTMRSymKey:rawTMRSymKey
                                                                           challenge:sealdCredentials.ssksTMRChallenge
                                                                               error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([identitySecondKey isEqualToData:retrieveResp2.identity], @"invalid retrieved identity TMR2");
        NSCAssert(retrieveResp2.shouldRenewKey == NO, @"invalid should renew key value 2"); // this time, the identity was saved with a challenge : no need to renew

        // Try retrieving with another SealdSsksTMRPlugin instance
        SealdSsksTMRPlugin* ssksTMR2 = [[SealdSsksTMRPlugin alloc] initWithSsksURL:sealdCredentials.ssksURL appId:sealdCredentials.appId instanceName:@"SsksTmr2" logLevel:-1 logNoColor:YES];
        SealdSsksBackendChallengeResponse* authSessionRetrieve3 =
            [ssksBackend challengeSendWithUserId:userId
                                      authFactor:authFactor
                                      createUser:YES
                                       forceAuth:NO
                                         fakeOtp:YES // `fakeOtp` is only on the staging server, to force the challenge to be 'aaaaaaaa'. In production, you cannot use this.
                                           error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionRetrieve2.mustAuthenticate == YES, @"unexpected mustAuthenticate value 4");
        SealdSsksRetrieveIdentityResponse* retrieveResp3 = [ssksTMR2 retrieveIdentity:authSessionRetrieve3.sessionId
                                                                           authFactor:authFactor
                                                                         rawTMRSymKey:rawTMRSymKey
                                                                            challenge:sealdCredentials.ssksTMRChallenge
                                                                                error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([identitySecondKey isEqualToData:retrieveResp3.identity], @"invalid retrieved identity TMR3");
        NSCAssert(retrieveResp2.shouldRenewKey == NO, @"invalid should renew key value 3");

        NSLog(@"SSKS TMR tests success!");
        return YES;
    }
    @catch (NSException* exception) {
        NSLog(@"SSKS TMR tests failed");
        NSLog(@"Error: %@", exception);
        return NO;
    }
}

BOOL testSealdSsksPassword(void)
{
    @try {
        NSError* error = nil;

        // Simulating a Seald identity with random data, for a simpler example.
        NSString* rand = randomString(10);
        NSString* userId = [NSString stringWithFormat:@"user-%@", rand];
        NSData* userIdentity = randomData(64); // should be: [sealdSDKInstance exportIdentity]

        SealdSsksPasswordPlugin* ssksPassword = [[SealdSsksPasswordPlugin alloc] initWithSsksURL:sealdCredentials.ssksURL appId:sealdCredentials.appId instanceName:@"SsksPassword" logLevel:-1 logNoColor:YES];

        // Test with password
        NSString* userPassword = randomString(10);

        // Saving the identity with a password
        NSString* ssksId1 = [ssksPassword saveIdentityWithUserId:userId password:userPassword identity:userIdentity error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(![ssksId1 isEqualToString:@""], @"ssksId1 empty");

        // Retrieving the identity with the password
        NSData* retrieveResp = [ssksPassword retrieveIdentityWithUserId:userId password:userPassword error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([userIdentity isEqualToData:retrieveResp], @"invalid retrieved identity Pass1");

        // Changing the password
        NSString* newPassword = @"a new password";
        NSString* ssksId1b = [ssksPassword changeIdentityPasswordWithUserId:userId currentPassword:userPassword newPassword:newPassword error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(![ssksId1b isEqualToString:ssksId1], @"ssksId1b equals ssksId1");

        // The previous password does not work anymore
        NSData* retrieveRespFail = [ssksPassword retrieveIdentityWithUserId:userId password:userPassword error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"code"] isEqualToString:@"SSKSPASSWORD_CANNOT_FIND_IDENTITY"], @"invalid error");
        NSCAssert(retrieveRespFail == nil, @"unexpected identity");
        error = nil;

        // Retrieving with the new password works
        NSData* retrieveIdentityWithNewPassword = [ssksPassword retrieveIdentityWithUserId:userId password:newPassword error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([userIdentity isEqualToData:retrieveIdentityWithNewPassword], @"invalid retrieved identity Pass2");

        // Test with raw keys
        NSString* rawStorageKey = randomString(32);
        NSData* rawEncryptionKey = randomData(64);

        // Saving identity with raw keys
        NSString* ssksId2 = [ssksPassword saveIdentityWithUserId:userId rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey identity:userIdentity error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(![ssksId2 isEqualToString:@""], @"ssksId2 empty");

        // Retrieving the identity with raw keys
        NSData* retrieveIdentityRawKeys = [ssksPassword retrieveIdentityWithUserId:userId rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([userIdentity isEqualToData:retrieveIdentityRawKeys], @"invalid retrieved identity Pass3");

        // Deleting the identity by saving an empty `Data`
        NSData* emptyData = [NSData data];
        NSString* ssksId2b = [ssksPassword saveIdentityWithUserId:userId rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey identity:emptyData error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([ssksId2b isEqualToString:ssksId2], @"ssksId2b different from ssksId2");

        NSData* retrieveEmptyIdentity = [ssksPassword retrieveIdentityWithUserId:userId rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"code"] isEqualToString:@"SSKSPASSWORD_CANNOT_FIND_IDENTITY"], @"invalid error");
        NSCAssert(retrieveEmptyIdentity == nil, @"unexpected identity");
        error = nil;

        NSLog(@"SSKS Password tests success!");
        return YES;
    }
    @catch (NSException* exception) {
        NSLog(@"SSKS Password tests failed");
        NSLog(@"Error: %@", exception);
        return NO;
    }
}

BOOL testSealdSDKWithCredentials(const NSString* sealdDir)
{
    @try {
        NSError* error = nil;

        // The Seald SDK uses a local database that will persist on disk.
        // When instantiating a SealdSDK, it is highly recommended to set a symmetric key to encrypt this database.
        // In an actual app, it should be generated at signup,
        // either on the server and retrieved from your backend at login,
        // or on the client-side directly and stored in the system's keychain.
        // WARNING: This should be a cryptographically random buffer of 64 bytes. This random generation is NOT good enough.
        NSData* databaseEncryptionKey = randomData(64);

        // Seald uses JWT to manage licenses and identity.
        // JWTs should be generated by your backend, and sent to the user at signup.
        // The JWT secretId and secret can be generated from your administration dashboard. They should NEVER be on client side.
        // However, as this is a demo without a backend, we will use them on the frontend.
        // JWT documentation: https://docs.seald.io/en/sdk/guides/jwt.html
        // identity documentation: https://docs.seald.io/en/sdk/guides/4-identities.html
        DemoAppJWTBuilder* jwtbuilder = [[DemoAppJWTBuilder alloc] initWithJWTSharedSecretId:sealdCredentials.JWTSharedSecretId JWTSharedSecret:sealdCredentials.JWTSharedSecret];

        // let's instantiate 3 SealdSDK. They will correspond to 3 users that will exchange messages.
        SealdSdk* sdk1 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials.apiURL appId:sealdCredentials.appId databasePath:[NSString stringWithFormat:@"%@/inst1", sealdDir] databaseEncryptionKey:databaseEncryptionKey instanceName:@"User1" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdSdk* sdk2 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials.apiURL appId:sealdCredentials.appId databasePath:[NSString stringWithFormat:@"%@/inst2", sealdDir] databaseEncryptionKey:databaseEncryptionKey instanceName:@"User2" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdSdk* sdk3 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials.apiURL appId:sealdCredentials.appId databasePath:[NSString stringWithFormat:@"%@/inst3", sealdDir] databaseEncryptionKey:databaseEncryptionKey instanceName:@"User3" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        SealdAccountInfo* retrieveNoAccount = [sdk1 getCurrentAccountInfo];
        NSCAssert(retrieveNoAccount == nil, @"retrieveNoAccount not nil");

        // Create the 3 accounts. Again, the signupJWT should be generated by your backend
        SealdAccountInfo* user1AccountInfo = [sdk1 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser1" displayName:@"User1" privateKeys:nil expireAfter:0 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdAccountInfo* user2AccountInfo = [sdk2 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser2" displayName:@"User2" privateKeys:nil expireAfter:0 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdAccountInfo* user3AccountInfo = [sdk3 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser3" displayName:@"User3" privateKeys:nil expireAfter:0 error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // retrieve info about current user before creating a user should return null
        SealdAccountInfo* retrieveAccountInfo = [sdk1 getCurrentAccountInfo];
        NSCAssert([retrieveAccountInfo.userId isEqualToString:user1AccountInfo.userId], @"retrieveAccountInfo.userId incorrect");
        NSCAssert([retrieveAccountInfo.deviceId isEqualToString:user1AccountInfo.deviceId],  @"retrieveAccountInfo.deviceId incorrect");

        // Create group: https://docs.seald.io/sdk/guides/5-groups.html
        NSArray<NSString*>* members = [NSArray arrayWithObject:user1AccountInfo.userId];
        NSArray<NSString*>* admins = [NSArray arrayWithObject:user1AccountInfo.userId];
        NSString* groupId = [sdk1 createGroupWithGroupName:@"group-1" members:members admins:admins privateKeys:nil error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // Manage group members and admins
        [sdk1 addGroupMembersWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user2AccountInfo.userId] adminsToSet:[NSArray new] privateKeys:nil error:&error]; // Add user2 as group member
        NSCAssert(error == nil, error.localizedDescription);
        [sdk1 addGroupMembersWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user3AccountInfo.userId] adminsToSet:[NSArray arrayWithObject:user3AccountInfo.userId] privateKeys:nil error:&error]; // user1 adds user3 as group member and group admin
        NSCAssert(error == nil, error.localizedDescription);
        [sdk3 removeGroupMembersWithGroupId:groupId membersToRemove:[NSArray arrayWithObject:user2AccountInfo.userId] privateKeys:nil error:&error];
        NSCAssert(error == nil, error.localizedDescription); // user3 can remove user2
        [sdk3 setGroupAdminsWithGroupId:groupId addToAdmins:[NSArray new] removeFromAdmins:[NSArray arrayWithObject:user1AccountInfo.userId] error:&error]; // user3 can remove user1 from admins
        NSCAssert(error == nil, error.localizedDescription);

        // Create encryption session: https://docs.seald.io/sdk/guides/6-encryption-sessions.html
        // user1, user2, and group as recipients
        // Default rights for the session creator (if included as recipients without RecipientRights)  read = true, forward = true, revoke = true
        // Default rights for any other recipient:  read = true, forward = true, revoke = false
        NSArray<SealdRecipientWithRights*>* recipients =
            [NSArray arrayWithObjects:
             [[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId],
             [[SealdRecipientWithRights alloc] initWithRecipientId:user2AccountInfo.userId],
             [[SealdRecipientWithRights alloc] initWithRecipientId:groupId], nil];
        SealdEncryptionSession* es1SDK1 = [sdk1 createEncryptionSessionWithRecipients:recipients useCache:YES error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(es1SDK1.retrievalDetails.flow == SealdEncryptionSessionRetrievalCreated, @"unexpected flow");

        // Using two-man-rule accesses

        // Add TMR accesses to the session, then, retrieve the session using it.
        // Create TMR a recipient
        NSString* rand = randomString(5);
        NSString* authFactorValue = [NSString stringWithFormat:@"tmr-em-objc-%@@test.com", rand];
        SealdTmrAuthFactor* tmrAuthFactor = [[SealdTmrAuthFactor alloc] initWithValue:authFactorValue type:@"EM"];

        // WARNING: This should be a cryptographically random buffer of 64 bytes. This random generation is NOT good enough.
        NSData* overEncryptionKey = randomData(64);

        SealdTmrRecipientWithRights* tmrRecipient = [[SealdTmrRecipientWithRights alloc] initWithAuthFactor:tmrAuthFactor overEncryptionKey:overEncryptionKey];

        // Add the TMR access
        NSString* addedTMRAccessId = [es1SDK1 addTmrAccess:tmrRecipient error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([addedTMRAccessId length] == 36, @"Expected UUID v4");

        // Retrieve the TMR JWT
        SealdSsksTMRPlugin* ssksTMR = [[SealdSsksTMRPlugin alloc] initWithSsksURL:sealdCredentials.ssksURL appId:sealdCredentials.appId instanceName:@"SsksTmr" logLevel:-1 logNoColor:YES];

        // The app backend creates an SSKS authentication session to save the identity.
        // This is the first time that this email is storing an identity, so `mustAuthenticate` is false.
        DemoAppSsksBackend* ssksBackend = [[DemoAppSsksBackend alloc] initWithSsksURL:sealdCredentials.ssksURL AppId:sealdCredentials.appId AppKey:sealdCredentials.ssksBackendAppKey];
        SealdSsksBackendChallengeResponse* authSession =
            [ssksBackend challengeSendWithUserId:user2AccountInfo.userId
                                      authFactor:tmrAuthFactor
                                      createUser:YES
                                       forceAuth:NO
                                         fakeOtp:YES // `fakeOtp` is only on the staging server, to force the challenge to be 'aaaaaaaa'. In production, you cannot use this.
                                           error:&error];

        // Retrieve a JWT associated with the authentication factor from SSKS
        SealdSsksGetFactorTokenResponse* tmrJWT = [ssksTMR getFactorToken:authSession.sessionId
                                                               authFactor:tmrAuthFactor
                                                                challenge:sealdCredentials.ssksTMRChallenge
                                                                    error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // Retrieve the encryption session using the JWT
        SealdEncryptionSession* tmrES = [sdk2 retrieveEncryptionSessionByTmr:tmrJWT.token sessionId:es1SDK1.sessionId overEncryptionKey:overEncryptionKey tmrAccessesFilters:nil tryIfMultiple:YES useCache:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(tmrES.retrievalDetails.flow == SealdEncryptionSessionRetrievalViaTmrAccess, @"unexpected flow");

        // Convert the TMR accesses
        [sdk2 convertTmrAccesses:tmrJWT.token overEncryptionKey:overEncryptionKey conversionFilters:nil deleteOnConvert:YES error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // After conversion, sdk2 can retrieve the encryption session directly.
        SealdEncryptionSession* classicES = [sdk2 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:NO lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(classicES.retrievalDetails.flow == SealdEncryptionSessionRetrievalDirect, @"unexpected flow");

        // Using proxy sessions: https://docs.seald.io/sdk/guides/proxy-sessions.html

        // Create proxy sessions: user1 needs to be a recipient of this session in order
        // to be able to add it as a proxy session
        NSArray<SealdRecipientWithRights*>* proxy1Recipients = [NSArray arrayWithObjects:
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId], // user1 needs to be a recipient of this session in order to be able to add it as a proxy session
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user3AccountInfo.userId],
                                                                nil];
        SealdEncryptionSession* proxySession1 = [sdk1 createEncryptionSessionWithRecipients:proxy1Recipients
                                                                                   useCache:YES
                                                                                      error:&error
                                                ];
        NSCAssert(error == nil, error.localizedDescription);

        [es1SDK1 addProxySession:proxySession1.sessionId error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        NSArray<SealdRecipientWithRights*>* proxy2Recipients = [NSArray arrayWithObjects:
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId], // user1 needs to be a recipient of this session in order to be able to add it as a proxy session
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user2AccountInfo.userId],
                                                                nil];
        // user1 needs to be a recipient of this session in order to be able to add it as a proxy session
        SealdEncryptionSession* proxySession2 = [sdk1 createEncryptionSessionWithRecipients:proxy2Recipients
                                                                                   useCache:YES
                                                                                      error:&error
                                                ];
        NSCAssert(error == nil, error.localizedDescription);
        [es1SDK1 addProxySession:proxySession2.sessionId error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // The SealdEncryptionSession object can encrypt and decrypt for user1
        NSString* initialString = @"a message that needs to be encrypted!";
        NSString* encryptedMessage = [es1SDK1 encryptMessage:initialString error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* decryptedMessage = [es1SDK1 decryptMessage:encryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedMessage isEqualToString:initialString], @"decryptedMessage incorrect");

        // Create a test file on disk that we will encrypt/decrypt
        NSString* filename = @"testfile.txt";
        NSString* fileContent = @"File clear data.";
        NSString* filePath = [NSString stringWithFormat:@"%@/%@", sealdDir, filename];
        [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // Encrypt the test file. Resulting file will be written alongside the source file, with `.seald` extension added
        NSString* encryptedFileURI = [es1SDK1 encryptFileFromURI:filePath error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // User1 can retrieve the encryptionSession directly from the encrypted file
        NSString* es1SDK1FromFileId = [SealdUtils parseSessionIdFromFile:encryptedFileURI error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([es1SDK1FromFileId isEqualToString:es1SDK1.sessionId], @"bad session id");
        SealdEncryptionSession* es1SDK1FromFile = [sdk1 retrieveEncryptionSessionFromFile:encryptedFileURI useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([es1SDK1FromFile.sessionId isEqualToString:es1SDK1.sessionId], @"bad session id");
        NSCAssert(es1SDK1FromFile.retrievalDetails.flow == SealdEncryptionSessionRetrievalDirect, @"unexpected flow");

        // The retrieved session can decrypt the file.
        // The decrypted file will be named with the name it had at encryption. Any renaming of the encrypted file will be ignored.
        // NOTE: In this example, the decrypted file will have `(1)` suffix to avoid overwriting the original clear file.
        NSString* decryptedFileURI = [es1SDK1FromFile decryptFileFromURI:encryptedFileURI error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedFileURI hasSuffix:@"testfile (1).txt"], @"decryptedFileURI incorrect");
        NSString* decryptedFileContent = [NSString stringWithContentsOfFile:decryptedFileURI encoding:NSUTF8StringEncoding error:&error];
        NSCAssert([fileContent isEqualToString:decryptedFileContent], @"decryptedFileContent incorrect");

        // User1 can retrieve the encryptionSession directly from the encrypted file bytes
        NSData* fileBytes = [NSData dataWithContentsOfFile:encryptedFileURI];
        NSString* es1SDK1FromBytesId = [SealdUtils parseSessionIdFromBytes:fileBytes error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([es1SDK1FromBytesId isEqualToString:es1SDK1.sessionId], @"bad session id");
        SealdEncryptionSession* es1SDK1FromBytes = [sdk1 retrieveEncryptionSessionFromBytes:fileBytes useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([es1SDK1FromBytes.sessionId isEqualToString:es1SDK1.sessionId], @"bad session id");
        NSCAssert(es1SDK1FromBytes.retrievalDetails.flow == SealdEncryptionSessionRetrievalDirect, @"unexpected flow");

        // user1 can retrieve the EncryptionSession from the encrypted message
        NSString* es1SDK1FromMessId = [SealdUtils parseSessionIdFromMessage:encryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([es1SDK1FromMessId isEqualToString:es1SDK1.sessionId], @"bad session id");
        SealdEncryptionSession* es1SDK1RetrieveFromMess = [sdk1 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([es1SDK1RetrieveFromMess.sessionId isEqualToString:es1SDK1.sessionId], @"bad session id");
        NSCAssert(es1SDK1RetrieveFromMess.retrievalDetails.flow == SealdEncryptionSessionRetrievalDirect, @"unexpected flow");
        NSString* decryptedMessageFromMess = [es1SDK1RetrieveFromMess decryptMessage:encryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedMessageFromMess isEqualToString:initialString], @"decryptedMessageFromMess incorrect");

        // user2 can retrieve the encryptionSession from the session ID.
        SealdEncryptionSession* es1SDK2 = [sdk2 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(es1SDK2.retrievalDetails.flow == SealdEncryptionSessionRetrievalDirect, @"unexpected flow");
        NSString* decryptedMessageSDK2 = [es1SDK2 decryptMessage:encryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedMessageSDK2 isEqualToString:initialString], @"decryptedMessageSDK2 incorrect");

        // user3 cannot retrieve the SealdEncryptionSession with lookupGroupKey set to NO.
        [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"code"] isEqualToString:@"NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"id"] isEqualToString:@"GOSDK_NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"description"] isEqualToString:@"Can't decipher this session"], @"invalid error");
        error = nil;

        // user3 can retrieve the encryptionSession from the encrypted message through the group.
        SealdEncryptionSession* es1SDK3FromGroup = [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:YES error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(es1SDK3FromGroup.retrievalDetails.flow == SealdEncryptionSessionRetrievalViaGroup, @"unexpected flow");
        NSCAssert([es1SDK3FromGroup.retrievalDetails.groupId isEqualToString:groupId], @"es1SDK3FromGroup.retrievalDetails.groupId incorrect");
        NSString* decryptedMessageSDK3 = [es1SDK3FromGroup decryptMessage:encryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedMessageSDK3 isEqualToString:initialString], @"decryptedMessageSDK3 incorrect");

        // user3 removes all members of "group-1". A group without member is deleted.
        [sdk3 removeGroupMembersWithGroupId:groupId membersToRemove:[NSArray arrayWithObjects:user1AccountInfo.userId, user3AccountInfo.userId, nil] privateKeys:nil error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // user3 could retrieve the previous encryption session only because "group-1" was set as recipient.
        // As the group was deleted, it can no longer access it.
        // user3 still has the encryption session in its cache, but we can disable it.
        [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:NO lookupProxyKey:NO lookupGroupKey:YES error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"code"] isEqualToString:@"NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"id"] isEqualToString:@"GOSDK_NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"description"] isEqualToString:@"Can't decipher this session"], @"invalid error");
        error = nil;

        // user3 can still retrieve the session via proxy.
        SealdEncryptionSession* es1SDK3FromProxy = [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:YES lookupProxyKey:YES lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(es1SDK3FromProxy.retrievalDetails.flow == SealdEncryptionSessionRetrievalViaProxy, @"unexpected flow");
        NSCAssert([es1SDK3FromProxy.retrievalDetails.proxySessionId isEqualToString:proxySession1.sessionId], @"es1SDK3FromProxy.retrievalDetails.proxySessionId incorrect");
        NSCAssert([es1SDK3FromProxy.retrievalDetails.proxySessionId isEqualToString:proxySession1.sessionId], @"es1SDK3FromProxy.retrievalDetails.proxySessionId incorrect");

        // user2 adds user3 as recipient of the encryption session.
        NSArray<SealdRecipientWithRights*>* recipientsToAdd = [NSArray arrayWithObjects:[[SealdRecipientWithRights alloc] initWithRecipientId:user3AccountInfo.userId], nil];
        NSDictionary<NSString*, SealdActionStatus*>* respAdd = [es1SDK2 addRecipients:recipientsToAdd error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(respAdd.count == 1, @"Unexpected response count.");
        NSCAssert(respAdd[user3AccountInfo.deviceId].success == YES, @"User ID mismatch."); // Note that addRecipient return userId instead of deviceId

        // user3 can now retrieve it without group or proxy.
        SealdEncryptionSession* es1SDK3 = [sdk3 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:NO lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(es1SDK3.retrievalDetails.flow == SealdEncryptionSessionRetrievalDirect, @"unexpected flow");
        NSString* decryptedMessageAfterAdd = [es1SDK3 decryptMessage:encryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedMessageAfterAdd isEqualToString:initialString], @"decryptedMessageAfterAdd incorrect");

        // user1 revokes user3 and proxy1 from the encryption session.
        SealdRevokeResult* respRevoke = [es1SDK1 revokeRecipientsIds:[NSArray arrayWithObject:user3AccountInfo.userId]
                                                    proxySessionsIds:[NSArray arrayWithObject:proxySession1.sessionId]
                                                               error:&error
                                        ];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(respRevoke.recipients.count == 1, @"Unexpected response count.");
        NSCAssert(respRevoke.recipients[user3AccountInfo.userId].success == YES, @"Unexpected status.");
        NSCAssert(respRevoke.proxySessions.count == 1, @"Unexpected response count.");
        NSCAssert(respRevoke.proxySessions[proxySession1.sessionId].success == YES, @"Unexpected status.");

        // user3 cannot retrieve the session anymore, even with proxy or group
        [sdk3 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:NO lookupProxyKey:YES lookupGroupKey:YES error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"code"] isEqualToString:@"NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"id"] isEqualToString:@"GOSDK_NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"description"] isEqualToString:@"Can't decipher this session"], @"invalid error");
        error = nil;

        // user1 revokes all other recipients from the session
        SealdRevokeResult* respRevokeOther = [es1SDK1 revokeOthers:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(respRevokeOther.recipients.count == 2, @"Unexpected response recipients count %lu", (unsigned long)respRevokeOther.recipients.count); // revoke user2 and group
        NSCAssert(respRevokeOther.recipients[groupId].success == YES, @"Unexpected status.");
        NSCAssert(respRevokeOther.recipients[user2AccountInfo.userId].success == YES, @"Unexpected status.");
        NSCAssert(respRevokeOther.proxySessions.count == 1, @"Unexpected response proxies count %lu", (unsigned long)respRevokeOther.proxySessions.count);
        NSCAssert(respRevokeOther.proxySessions[proxySession2.sessionId].success == YES, @"Unexpected status.");

        // user2 cannot retrieve the session anymore
        [sdk2 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:NO lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"code"] isEqualToString:@"NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"id"] isEqualToString:@"GOSDK_NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"description"] isEqualToString:@"Can't decipher this session"], @"invalid error");
        error = nil;

        // user1 revokes all. It can no longer retrieve it.
        SealdRevokeResult* respRevokeAll = [es1SDK1 revokeAll:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(respRevokeAll.recipients.count == 1, @"Unexpected response recipients count %lu", (unsigned long)respRevokeAll.recipients.count);
        NSCAssert(respRevokeAll.recipients[user1AccountInfo.userId].success == YES, @"Unexpected status.");
        NSCAssert(respRevokeAll.proxySessions.count == 0, @"Unexpected response proxies count %lu", (unsigned long)respRevokeAll.proxySessions.count);

        // user1 cannot retrieve anymore
        [sdk1 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:NO lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"code"] isEqualToString:@"NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"id"] isEqualToString:@"GOSDK_NO_TOKEN_FOR_YOU"], @"invalid error");
        NSCAssert([error.userInfo[@"description"] isEqualToString:@"Can't decipher this session"], @"invalid error");
        error = nil;

        // Create additional data for user1
        NSArray<SealdRecipientWithRights*>* recipientsES234 = [NSArray arrayWithObject:[[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId]];
        SealdEncryptionSession* es2SDK1 = [sdk1 createEncryptionSessionWithRecipients:recipientsES234 useCache:YES error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* anotherMessage = @"Nobody should read that!";
        NSString* secondEncryptedMessage = [es2SDK1 encryptMessage:anotherMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdEncryptionSession* es3SDK1 = [sdk1 createEncryptionSessionWithRecipients:recipientsES234 useCache:YES error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdEncryptionSession* es4SDK1 = [sdk1 createEncryptionSessionWithRecipients:recipientsES234 useCache:YES error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // user1 can retrieveMultiple
        NSArray<SealdEncryptionSession*>* encryptionSessions = [sdk1 retrieveMultipleEncryptionSessions:[NSArray arrayWithObjects:es2SDK1.sessionId, es3SDK1.sessionId, es4SDK1.sessionId, nil] useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([encryptionSessions count] == 3, @"wrong length");
        NSCAssert(encryptionSessions[0] != nil, @"session is nil");
        NSCAssert([encryptionSessions[0].sessionId isEqualToString:es2SDK1.sessionId], @"wrong session id");
        NSCAssert(encryptionSessions[1] != nil, @"session is nil");
        NSCAssert([encryptionSessions[1].sessionId isEqualToString:es3SDK1.sessionId], @"wrong session id");
        NSCAssert(encryptionSessions[2] != nil, @"session is nil");
        NSCAssert([encryptionSessions[2].sessionId isEqualToString:es4SDK1.sessionId], @"wrong session id");

        // user1 can renew its key, and still decrypt old messages
        NSData* preparedRenewal = [sdk1 prepareRenewWithPrivateKeys:nil error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        // `preparedRenewal` Can be stored on SSKS as a new identity. That way, a backup will be available is the renewKeys fail.

        [sdk1 renewKeysWithPreparedRenewal:preparedRenewal privateKeys:nil expireAfter:5 * 365 * 24 * 60 * 60 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdEncryptionSession* es2SDK1AfterRenew = [sdk1 retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* decryptedMessageAfterRenew = [es2SDK1AfterRenew decryptMessage:secondEncryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedMessageAfterRenew isEqualToString:anotherMessage], @"invalid error");

        // CONNECTORS https://docs.seald.io/en/sdk/guides/jwt.html#adding-a-userid

        // we can add a custom userId using a JWT
        NSString* customConnectorJWTValue = @"user1-custom-id";
        NSString* addConnectorJWT = [jwtbuilder connectorJWTWithCustomUserId:customConnectorJWTValue appId:sealdCredentials.appId];
        [sdk1 pushJWT:addConnectorJWT error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // we can list a user connectors
        NSArray<SealdConnector*>* connectors = [sdk1 listConnectorsWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* expectedConnectorValue = [NSString stringWithFormat:@"%@@%@", customConnectorJWTValue, sealdCredentials.appId];
        NSCAssert([connectors count] == 1, @"connectors count incorrect");
        NSCAssert([connectors[0].type isEqualToString:@"AP"], @"connectors[0].type incorrect");
        NSCAssert([connectors[0].state isEqualToString:@"VO"], @"connectors[0].state incorrect");
        NSCAssert([connectors[0].sealdId isEqualToString:user1AccountInfo.userId], @"connectors[0].sealdId incorrect");
        NSCAssert([connectors[0].value isEqualToString:expectedConnectorValue], @"connectors[0].value incorrect");

        // Retrieve connector by its id
        SealdConnector* retrievedConnector = [sdk1 retrieveConnector:connectors[0].connectorId error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([retrievedConnector.type isEqualToString:@"AP"], @"retrievedConnector.type incorrect ");
        NSCAssert([retrievedConnector.state isEqualToString:@"VO"], @"retrievedConnector.state incorrect");
        NSCAssert([retrievedConnector.sealdId isEqualToString:user1AccountInfo.userId], @"retrievedConnector.sealdId incorrect");
        NSCAssert([retrievedConnector.value isEqualToString:expectedConnectorValue], @"retrievedConnector.value incorrect");

        // Retrieve connectors from a seald id.
        NSArray<SealdConnector*>* connectorsFromSealdId = [sdk1 getConnectorsFromSealdId:user1AccountInfo.userId error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([connectorsFromSealdId count] == 1, @"connectorsFromSealdId count incorrect");
        NSCAssert([connectorsFromSealdId[0].type isEqualToString:@"AP"], @"connectorsFromSealdId[0].type incorrect");
        NSCAssert([connectorsFromSealdId[0].state isEqualToString:@"VO"], @"connectorsFromSealdId[0].state incorrect");
        NSCAssert([connectorsFromSealdId[0].sealdId isEqualToString:user1AccountInfo.userId], @"connectorsFromSealdId[0].sealdId incorrect");
        NSCAssert([connectorsFromSealdId[0].value isEqualToString:expectedConnectorValue], @"connectorsFromSealdId[0].value incorrect");

        // Get sealdId of a user from a connector
        SealdConnectorTypeValue* connectorToSearch = [[SealdConnectorTypeValue alloc] initWithType:@"AP" value:expectedConnectorValue];
        NSArray* sealdIds = [sdk1 getSealdIdsFromConnectors:[NSArray arrayWithObject:connectorToSearch] error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([sealdIds count] == 1, @"sealdIds count incorrect");
        NSCAssert([sealdIds[0] isEqualToString:user1AccountInfo.userId], @"user1AccountInfo.userId incorrect");

        // user1 can remove a connector
        [sdk1 removeConnector:connectors[0].connectorId error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // verify that no connector left
        NSArray<SealdConnector*>* connectorListAfterRevoke = [sdk1 listConnectorsWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([connectorListAfterRevoke count] == 0, @"connectorListAfterRevoke count incorrect");

        // user1 can export its identity
        NSData* exportedIdentity = [sdk1 exportIdentityWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // We can instantiate a new SealdSDK, import the exported identity
        SealdSdk* sdk1Exported = [[SealdSdk alloc] initWithApiUrl:sealdCredentials.apiURL appId:sealdCredentials.appId databasePath:[NSString stringWithFormat:@"%@/inst1Exported", sealdDir] databaseEncryptionKey:databaseEncryptionKey instanceName:@"User1Exported" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        [sdk1Exported importIdentity:exportedIdentity error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // SDK with imported identity can decrypt
        SealdEncryptionSession* es2SDK1Exported = [sdk1Exported retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        NSString* clearMessageExportedIdentity = [es2SDK1Exported decryptMessage:secondEncryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([clearMessageExportedIdentity isEqualToString:anotherMessage], @"clearMessageExportedIdentity incorrect");

        // user1 can create sub identity
        SealdCreateSubIdentityResponse* subIdentity = [sdk1 createSubIdentityWithDeviceName:@"Sub-device" privateKeys:nil expireAfter:365 * 24 * 60 * 60 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(subIdentity.deviceId != nil, @"subIdentity.deviceId invalid");

        // first device needs to reencrypt for the new device
        SealdMassReencryptOptions* massReencryptOpts = [[SealdMassReencryptOptions alloc] init];
        [sdk1 massReencryptWithDeviceId:subIdentity.deviceId options:massReencryptOpts error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // We can instantiate a new SealdSDK, import the sub-device identity
        SealdSdk* sdk1SubDevice = [[SealdSdk alloc] initWithApiUrl:sealdCredentials.apiURL appId:sealdCredentials.appId databasePath:[NSString stringWithFormat:@"%@/inst1SubDevice", sealdDir] databaseEncryptionKey:databaseEncryptionKey instanceName:@"User1SubDevice" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        [sdk1SubDevice importIdentity:subIdentity.backupKey error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // sub device can decrypt
        SealdEncryptionSession* es2SDK1SubDevice = [sdk1SubDevice retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* clearMessageSubdIdentity = [es2SDK1SubDevice decryptMessage:secondEncryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([clearMessageSubdIdentity isEqualToString:anotherMessage], @"clearMessageSubdIdentity invalid");

        // Get and Check sigchain hash
        SealdGetSigchainResponse* user1LastSigchainHash = [sdk1 getSigchainHashWithUserId:user1AccountInfo.userId position:-1 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(user1LastSigchainHash.position == 2, @"user1LastSigchainHash unexpected position");
        SealdGetSigchainResponse* user1FirstSigchainHash = [sdk1 getSigchainHashWithUserId:user1AccountInfo.userId position:0 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(user1FirstSigchainHash.position == 0, @"user1FirstSigchainHash unexpected position");
        SealdCheckSigchainResponse* lastHashCheck = [sdk2 checkSigchainHashWithUserId:user1AccountInfo.userId expectedHash:user1LastSigchainHash.sigchainHash position:-1 error:&error];
        NSCAssert(lastHashCheck.found, @"lastHashCheck not found");
        NSCAssert(lastHashCheck.position == 2, @"lastHashCheck unexpected position");
        NSCAssert(lastHashCheck.lastPosition == 2, @"lastHashCheck unexpected lastPosition");
        SealdCheckSigchainResponse* firstHashCheck = [sdk1 checkSigchainHashWithUserId:user1AccountInfo.userId expectedHash:user1FirstSigchainHash.sigchainHash position:-1 error:&error];
        NSCAssert(firstHashCheck.found, @"firstHashCheck not found");
        NSCAssert(firstHashCheck.position == 0, @"firstHashCheck unexpected position");
        NSCAssert(firstHashCheck.lastPosition == 2, @"firstHashCheck unexpected lastPosition");
        SealdCheckSigchainResponse* badPositionCheck = [sdk2 checkSigchainHashWithUserId:user1AccountInfo.userId expectedHash:user1FirstSigchainHash.sigchainHash position:1 error:&error];
        NSCAssert(badPositionCheck.found == false, @"badPositionCheck unexpected found");
        // For badPositionCheck, position cannot be asserted as it is not set when the hash is not found.
        NSCAssert(badPositionCheck.lastPosition == 2, @"badPositionCheck unexpected lastPosition");

        // Heartbeat can be used to check if proxies and firewalls are configured properly so that the app can reach Seald's servers.
        [sdk1 heartbeatWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // close SDKs
        [sdk1 closeWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);
        [sdk2 closeWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);
        [sdk3 closeWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);

        NSLog(@"SDK tests success!");
        return YES;
    }
    @catch (NSException* exception) {
        NSLog(@"SDK tests failed");
        NSLog(@"Error: %@", exception);
        return NO;
    }
}

@implementation SEALDSDKAppDelegate

- (BOOL)              application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self.testSdkLabel = @"pending...";
    self.testSsksPasswordLabel = @"pending...";
    self.testSsksTmrLabel = @"pending...";

    // The SealdSDK uses a local database. This database should be written to a permanent directory.
    // On iOS, in ObjC, the recommended path is `NSDocumentDirectory`.
    NSArray* paths = NSSearchPathForDirectoriesInDomains
                         (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    NSString* sealdDir = [NSString stringWithFormat:@"%@/seald", documentsDirectory];

    // This demo expects a clean database path to create it's own data, so we need to clean what previous runs left.
    // In a real app, it should never be done.
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = nil;
    if ([fileManager removeItemAtPath:sealdDir error:&error]) {
        NSLog(@"Seald Database removed successfully");
    } else {
        NSLog(@"Error removing Seald database %@", error.userInfo);
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.testSsksTmrLabel = @"running...";
        BOOL res = testSealdSsksTMR();
        self.testSsksTmrLabel = res ? @"success" : @"error";
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.testSsksPasswordLabel = @"running...";
        BOOL res = testSealdSsksPassword();
        self.testSsksPasswordLabel = res ? @"success" : @"error";
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.testSdkLabel = @"running...";
        BOOL res = testSealdSDKWithCredentials(sealdDir);
        self.testSdkLabel = res ? @"success" : @"error";
    });

    return YES;
}

- (void) applicationWillResignActive:(UIApplication*)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void) applicationDidEnterBackground:(UIApplication*)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void) applicationWillEnterForeground:(UIApplication*)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void) applicationDidBecomeActive:(UIApplication*)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void) applicationWillTerminate:(UIApplication*)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
@end
