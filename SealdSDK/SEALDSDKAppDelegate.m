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

BOOL testSealdSsksTMR(const SealdCredentials* sealdCredentials)
{
    @try {
        NSError* error = nil;

        NSData* rawTMRKey = randomData(64);

        DemoAppSsksBackend* ssksBackend = [[DemoAppSsksBackend alloc] initWithSsksURL:sealdCredentials->ssksURL AppId:sealdCredentials->ssksBackendAppId AppKey:sealdCredentials->ssksBackendAppKey];

        // Simulating a Seald identity with random data, for a simpler example.
        NSString* rand = randomString(10);
        NSString* userId = [NSString stringWithFormat:@"user-%@", rand];
        NSString* userEM = [NSString stringWithFormat:@"user-%@@test.com", rand];
        NSData* userIdentity = randomData(64); // should be: [sealdSDKInstance exportIdentity]

        SealdSsksTMRPlugin* ssksTMR = [[SealdSsksTMRPlugin alloc] initWithSsksURL:sealdCredentials->ssksURL appId:sealdCredentials->appId instanceName:@"SsksTmr" logLevel:-1 logNoColor:YES];

        SealdSsksAuthFactor* authFactor = [[SealdSsksAuthFactor alloc] initWithValue:userEM type:@"EM"];

        // The app backend creates a session to save the identity.
        // This is the first time that this email is storing an identity, so `must_authenticate` is false.
        SealdSsksBackendChallengeResponse* authSessionSave = [ssksBackend challengeSendWithUserId:userId authFactor:authFactor createUser:YES forceAuth:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionSave.mustAuthenticate == NO, @"unexpected mustAuthenticate value 1");

        // Saving the identity. No challenge necessary because `must_authenticate` is false.
        [ssksTMR saveIdentity:authSessionSave.sessionId authFactor:authFactor challenge:@"" rawTMRSymKey:rawTMRKey identity:userIdentity error:&error];

        // The app backend creates another session to retrieve the identity.
        // The identity is already saved, so `must_authenticate` is true.
        SealdSsksBackendChallengeResponse* authSessionRetrieve = [ssksBackend challengeSendWithUserId:userId authFactor:authFactor createUser:YES forceAuth:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionRetrieve.mustAuthenticate == YES, @"unexpected mustAuthenticate value 2");

        // Retrieving identity. Challenge is necessary for this.
        SealdSsksRetrieveIdentityResponse* retrieveResp = [ssksTMR retrieveIdentity:authSessionRetrieve.sessionId authFactor:authFactor challenge:sealdCredentials->ssksTMRChallenge rawTMRSymKey:rawTMRKey error:&error]; // on this test server, the challenge is fixed. In an actual app, this will be the challenge recieved by the user by email or SMS.
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([userIdentity isEqualToData:retrieveResp.identity], @"invalid retrieved identity TMR1");
        NSCAssert(retrieveResp.shouldRenewKey == YES, @"invalid should renew key value 1");

        // If initial key has been saved without being fully authenticated, you should renew the user's private key, and save it again.
        // sdk.renewKeys(Duration.ofDays(365 * 5))

        // Let's simulate the renew with another random identity
        NSData* identitySecondKey = randomData(64); // should be: [sealdSDKInstance exportIdentity]
        [ssksTMR saveIdentity:retrieveResp.authenticatedSessionId authFactor:authFactor challenge:@"" rawTMRSymKey:rawTMRKey identity:identitySecondKey error:&error]; // to save the newly renewed identity on the server, you can use the `authenticatedSessionId` from the response to `retrieveIdentity`, with no challenge
        NSCAssert(error == nil, error.localizedDescription);

        // And now let's retrieve this new saved identity
        SealdSsksBackendChallengeResponse* authSessionRetrieve2 = [ssksBackend challengeSendWithUserId:userId authFactor:authFactor createUser:YES forceAuth:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionRetrieve2.mustAuthenticate == YES, @"unexpected mustAuthenticate value 3");
        SealdSsksRetrieveIdentityResponse* retrieveResp2 = [ssksTMR retrieveIdentity:authSessionRetrieve2.sessionId authFactor:authFactor challenge:sealdCredentials->ssksTMRChallenge rawTMRSymKey:rawTMRKey error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([identitySecondKey isEqualToData:retrieveResp2.identity], @"invalid retrieved identity TMR2");
        NSCAssert(retrieveResp2.shouldRenewKey == NO, @"invalid should renew key value 2"); // this time, the identity was saved with a challenge : no need to renew

        // Try retrieving with another SealdSsksTMRPlugin instance
        SealdSsksTMRPlugin* ssksTMR2 = [[SealdSsksTMRPlugin alloc] initWithSsksURL:sealdCredentials->ssksURL appId:sealdCredentials->appId instanceName:@"SsksTmr2" logLevel:-1 logNoColor:YES];
        SealdSsksBackendChallengeResponse* authSessionRetrieve3 = [ssksBackend challengeSendWithUserId:userId authFactor:authFactor createUser:YES forceAuth:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(authSessionRetrieve2.mustAuthenticate == YES, @"unexpected mustAuthenticate value 4");
        SealdSsksRetrieveIdentityResponse* retrieveResp3 = [ssksTMR2 retrieveIdentity:authSessionRetrieve3.sessionId authFactor:authFactor challenge:sealdCredentials->ssksTMRChallenge rawTMRSymKey:rawTMRKey error:&error];
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

BOOL testSealdSsksPassword(const SealdCredentials* sealdCredentials)
{
    @try {
        NSError* error = nil;

        // Simulating a Seald identity with random data, for a simpler example.
        NSString* rand = randomString(10);
        NSString* userId = [NSString stringWithFormat:@"user-%@", rand];
        NSData* userIdentity = randomData(64); // should be: [sealdSDKInstance exportIdentity]

        SealdSsksPasswordPlugin* ssksPassword = [[SealdSsksPasswordPlugin alloc] initWithSsksURL:sealdCredentials->ssksURL appId:sealdCredentials->appId instanceName:@"SsksPassword" logLevel:-1 logNoColor:YES];

        // Test with password
        NSString* userPassword = randomString(10);

        // Saving the identity with a password
        [ssksPassword saveIdentityWithUserId:userId password:userPassword identity:userIdentity error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // Retrieving the identity with the password
        NSData* retrieveResp = [ssksPassword retrieveIdentityWithUserId:userId password:userPassword error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([userIdentity isEqualToData:retrieveResp], @"invalid retrieved identity Pass1");

        // Changing the password
        NSString* newPassword = @"a new password";
        [ssksPassword changeIdentityPasswordWithUserId:userId currentPassword:userPassword newPassword:newPassword error:&error];
        NSCAssert(error == nil, error.localizedDescription);

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
        [ssksPassword saveIdentityWithUserId:userId rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey identity:userIdentity error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // Retrieving the identity with raw keys
        NSData* retrieveIdentityRawKeys = [ssksPassword retrieveIdentityWithUserId:userId rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([userIdentity isEqualToData:retrieveIdentityRawKeys], @"invalid retrieved identity Pass3");

        // Deleting the identity by saving an empty `Data`
        NSData* emptyData = [NSData data];
        [ssksPassword saveIdentityWithUserId:userId rawStorageKey:rawStorageKey rawEncryptionKey:rawEncryptionKey identity:emptyData error:&error];
        NSCAssert(error == nil, error.localizedDescription);

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

BOOL testSealdSDKWithCredentials(const SealdCredentials* sealdCredentials, const NSString* sealdDir)
{
    @try {
        NSError* error = nil;

        // The Seald SDK uses a local database that will persist on disk.
        // When instantiating a SealdSDK, it is highly recommended to set a symmetric key to encrypt this database.
        // This demo will use a fixed key.
        // In an actual app, it should be generated at signup,
        // either on the server and retrieved from your backend at login,
        // or on the client-side directly and stored in the system's keychain.
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
        NSCAssert(error == nil, error.localizedDescription);
        SealdSdk* sdk2 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst2", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User2" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdSdk* sdk3 = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst3", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User3" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        SealdAccountInfo* retrieveNoAccount = [sdk1 getCurrentAccountInfo];
        NSCAssert(retrieveNoAccount == nil, @"retrieveNoAccount not nil");

        // Create the 3 accounts. Again, the signupJWT should be generated by your backend
        SealdAccountInfo* user1AccountInfo = [sdk1 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser1" displayName:@"User1" expireAfter:0 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdAccountInfo* user2AccountInfo = [sdk2 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser2" displayName:@"User2" expireAfter:0 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdAccountInfo* user3AccountInfo = [sdk3 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser3" displayName:@"User3" expireAfter:0 error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // retrieve info about current user before creating a user should return null
        SealdAccountInfo* retrieveAccountInfo = [sdk1 getCurrentAccountInfo];
        NSCAssert([retrieveAccountInfo.userId isEqualToString:user1AccountInfo.userId], @"retrieveAccountInfo.userId incorrect");
        NSCAssert([retrieveAccountInfo.deviceId isEqualToString:user1AccountInfo.deviceId],  @"retrieveAccountInfo.deviceId incorrect");

        // Create group: https://docs.seald.io/sdk/guides/5-groups.html
        NSArray<NSString*>* members = [NSArray arrayWithObject:user1AccountInfo.userId];
        NSArray<NSString*>* admins = [NSArray arrayWithObject:user1AccountInfo.userId];
        NSString* groupId = [sdk1 createGroupWithGroupName:@"group-1" members:members admins:admins error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // Manage group members and admins
        [sdk1 addGroupMembersWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user2AccountInfo.userId] adminsToSet:[NSArray new] error:&error]; // Add user2 as group member
        NSCAssert(error == nil, error.localizedDescription);
        [sdk1 addGroupMembersWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user3AccountInfo.userId] adminsToSet:[NSArray arrayWithObject:user3AccountInfo.userId] error:&error]; // user1 adds user3 as group member and group admin
        NSCAssert(error == nil, error.localizedDescription);
        [sdk3 removeGroupMembersWithGroupId:groupId membersToRemove:[NSArray arrayWithObject:user2AccountInfo.userId] error:&error];
        NSCAssert(error == nil, error.localizedDescription); // user3 can remove user2
        [sdk3 setGroupAdminsWithGroupId:groupId addToAdmins:[NSArray new] removeFromAdmins:[NSArray arrayWithObject:user1AccountInfo.userId] error:&error]; // user3 can remove user1 from admins
        NSCAssert(error == nil, error.localizedDescription);

        // Create encryption session: https://docs.seald.io/sdk/guides/6-encryption-sessions.html
        SealdRecipientRights* allRights = [[SealdRecipientRights alloc] initWithRead:YES forward:YES revoke:YES];
        NSArray<SealdRecipientWithRights*>* recipients = [NSArray arrayWithObjects:[[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId rights:allRights], [[SealdRecipientWithRights alloc] initWithRecipientId:user2AccountInfo.userId rights:allRights], [[SealdRecipientWithRights alloc] initWithRecipientId:groupId rights:allRights], nil];
        SealdEncryptionSession* es1SDK1 = [sdk1 createEncryptionSessionWithRecipients:recipients useCache:YES error:&error]; // user1, user2, and group as recipients
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(es1SDK1.retrievalDetails.flow == SealdEncryptionSessionRetrievalCreated, @"unexpected flow");

        // Create proxy sessions
        NSArray<SealdRecipientWithRights*>* proxy1Recipients = [NSArray arrayWithObjects:
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId rights:allRights], // user1 needs to be a recipient of this session in order to be able to add it as a proxy session
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user3AccountInfo.userId rights:allRights],
                                                                nil];
        SealdEncryptionSession* proxySession1 = [sdk1 createEncryptionSessionWithRecipients:proxy1Recipients
                                                                                   useCache:YES
                                                                                      error:&error
                                                ];
        NSCAssert(error == nil, error.localizedDescription);

        [es1SDK1 addProxySession:proxySession1.sessionId rights:allRights error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        NSArray<SealdRecipientWithRights*>* proxy2Recipients = [NSArray arrayWithObjects:
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId rights:allRights], // user1 needs to be a recipient of this session in order to be able to add it as a proxy session
                                                                [[SealdRecipientWithRights alloc] initWithRecipientId:user2AccountInfo.userId rights:allRights],
                                                                nil];
        SealdEncryptionSession* proxySession2 = [sdk1 createEncryptionSessionWithRecipients:proxy2Recipients
                                                                                   useCache:YES
                                                                                      error:&error
                                                ];
        NSCAssert(error == nil, error.localizedDescription);
        [es1SDK1 addProxySession:proxySession2.sessionId rights:allRights error:&error];
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
        NSCAssert([error.userInfo[@"status"] isEqualToNumber:@404], @"invalid error");
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
        [sdk3 removeGroupMembersWithGroupId:groupId membersToRemove:[NSArray arrayWithObjects:user1AccountInfo.userId, user3AccountInfo.userId, nil] error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // user3 could retrieve the previous encryption session only because "group-1" was set as recipient.
        // As the group was deleted, it can no longer access it.
        // user3 still has the encryption session in its cache, but we can disable it.
        [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:NO lookupProxyKey:NO lookupGroupKey:YES error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"status"] isEqualToNumber:@404], @"invalid error");
        error = nil;

        // user3 can still retrieve the session via proxy.
        SealdEncryptionSession* es1SDK3FromProxy = [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:YES lookupProxyKey:YES lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(es1SDK3FromProxy.retrievalDetails.flow == SealdEncryptionSessionRetrievalViaProxy, @"unexpected flow");
        NSCAssert([es1SDK3FromProxy.retrievalDetails.proxySessionId isEqualToString:proxySession1.sessionId], @"es1SDK3FromProxy.retrievalDetails.proxySessionId incorrect");
        NSCAssert([es1SDK3FromProxy.retrievalDetails.proxySessionId isEqualToString:proxySession1.sessionId], @"es1SDK3FromProxy.retrievalDetails.proxySessionId incorrect");

        // user2 adds user3 as recipient of the encryption session.
        NSArray<SealdRecipientWithRights*>* recipientsToAdd = [NSArray arrayWithObjects:[[SealdRecipientWithRights alloc] initWithRecipientId:user3AccountInfo.userId rights:allRights], nil];
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
        NSCAssert([error.userInfo[@"status"] isEqualToNumber:@404], @"invalid error");
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
        NSCAssert([error.userInfo[@"status"] isEqualToNumber:@404], @"invalid error");
        error = nil;

        // user1 revokes all. It can no longer retrieve it.
        SealdRevokeResult* respRevokeAll = [es1SDK1 revokeAll:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(respRevokeAll.recipients.count == 1, @"Unexpected response recipients count %lu", (unsigned long)respRevokeAll.recipients.count);
        NSCAssert(respRevokeAll.recipients[user1AccountInfo.userId].success == YES, @"Unexpected status.");
        NSCAssert(respRevokeAll.proxySessions.count == 0, @"Unexpected response proxies count %lu", (unsigned long)respRevokeAll.proxySessions.count);

        [sdk1 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:NO lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error != nil, @"expected error");
        NSCAssert([error.userInfo[@"status"] isEqualToNumber:@404], @"invalid error");
        error = nil;

        // Create additional data for user1
        NSArray<SealdRecipientWithRights*>* recipientsES2 = [NSArray arrayWithObject:[[SealdRecipientWithRights alloc] initWithRecipientId:user1AccountInfo.userId rights:allRights]];
        SealdEncryptionSession* es2SDK1 = [sdk1 createEncryptionSessionWithRecipients:recipientsES2 useCache:YES error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* anotherMessage = @"Nobody should read that!";
        NSString* secondEncryptedMessage = [es2SDK1 encryptMessage:anotherMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // user1 can renew its key, and still decrypt old messages
        [sdk1 renewKeysWithExpireAfter:5 * 365 * 24 * 60 * 60 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        SealdEncryptionSession* es2SDK1AfterRenew = [sdk1 retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* decryptedMessageAfterRenew = [es2SDK1AfterRenew decryptMessage:secondEncryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([decryptedMessageAfterRenew isEqualToString:anotherMessage], @"invalid error");

        // CONNECTORS https://docs.seald.io/en/sdk/guides/jwt.html#adding-a-userid

        // we can add a custom userId using a JWT
        NSString* customConnectorJWTValue = @"user1-custom-id";
        NSString* addConnectorJWT = [jwtbuilder connectorJWTWithCustomUserId:customConnectorJWTValue appId:sealdCredentials->appId];
        [sdk1 pushJWT:addConnectorJWT error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // we can list a user connectors
        NSArray<SealdConnector*>* connectors = [sdk1 listConnectorsWithError:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* expectedConnectorValue = [NSString stringWithFormat:@"%@@%@", customConnectorJWTValue, sealdCredentials->appId];
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
        SealdSdk* sdk1Exported = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst1Exported", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1Exported" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
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
        SealdCreateSubIdentityResponse* subIdentity = [sdk1 createSubIdentityWithDeviceName:@"Sub-device" expireAfter:365 * 24 * 60 * 60 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert(subIdentity.deviceId != nil, @"subIdentity.deviceId invalid");

        // first device needs to reencrypt for the new device
        SealdMassReencryptOptions* massReencryptOpts = [[SealdMassReencryptOptions alloc] init];
        [sdk1 massReencryptWithDeviceId:subIdentity.deviceId options:massReencryptOpts error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // We can instantiate a new SealdSDK, import the sub-device identity
        SealdSdk* sdk1SubDevice = [[SealdSdk alloc] initWithApiUrl:sealdCredentials->apiURL appId:sealdCredentials->appId dbPath:[NSString stringWithFormat:@"%@/inst1SubDevice", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1SubDevice" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        [sdk1SubDevice importIdentity:subIdentity.backupKey error:&error];
        NSCAssert(error == nil, error.localizedDescription);

        // sub device can decrypt
        SealdEncryptionSession* es2SDK1SubDevice = [sdk1SubDevice retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:YES lookupProxyKey:NO lookupGroupKey:NO error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSString* clearMessageSubdIdentity = [es2SDK1SubDevice decryptMessage:secondEncryptedMessage error:&error];
        NSCAssert(error == nil, error.localizedDescription);
        NSCAssert([clearMessageSubdIdentity isEqualToString:anotherMessage], @"clearMessageSubdIdentity invalid");

        // users can send heartbeat
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
        self.testSsksTmrLabel = @"running...";
        BOOL res = testSealdSsksTMR(&sealdCredentials);
        self.testSsksTmrLabel = res ? @"success" : @"error";
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.testSsksPasswordLabel = @"running...";
        BOOL res = testSealdSsksPassword(&sealdCredentials);
        self.testSsksPasswordLabel = res ? @"success" : @"error";
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        self.testSdkLabel = @"running...";
        BOOL res = testSealdSDKWithCredentials(&sealdCredentials, sealdDir);
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
