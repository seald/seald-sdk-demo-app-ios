//
//  SEALDSDKAppDelegate.m
//  SealdSDK
//
//  Created by clement on 02/13/2023.
//  Copyright (c) 2023 Seald SAS. All rights reserved.
//

#import "SEALDSDKAppDelegate.h"
#import <SealdSdk/SealdSdk.h>
#import <JWT/JWT.h>
#import "JWTBuilder.h"

@implementation SEALDSDKAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Seald account infos:
    // First step with Seald: https://docs.seald.io/en/sdk/guides/1-quick-start.html
    // Create a team here: https://www.seald.io/create-sdk
    NSString *apiURL = @"https://api.staging-0.seald.io/";
    NSString *appId = @"1e2600a5-417e-4333-93a6-2b196781b0de";
    NSString *JWTSharedSecretId = @"32b4e3db-300b-4916-90e6-0020639c3df0";
    NSString *JWTSharedSecret = @"VstlqoxvQPAxRTDa6cAzWiQiqcgETNP8yYnNyhGWXaI6uS7X5t8csh1xYeLTjTTO";
    
    // The Seald SDK uses a local database that will persist on disk.
    // When instantiating a SealdSDK, it is highly recommended to set a symmetric key to encrypt this database.
    // This demo will use a fixed key. It should be generated at signup, and retrieved from your backend at login.
    NSString *databaseEncryptionKeyB64 = @"V4olGDOE5bAWNa9HDCvOACvZ59hUSUdKmpuZNyl1eJQnWKs5/l+PGnKUv4mKjivL3BtU014uRAIF2sOl83o6vQ";
    
    // Find database Path
    NSArray *paths = NSSearchPathForDirectoriesInDomains
                (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *sealdDir = [NSString stringWithFormat:@"%@/seald", documentsDirectory];
    
    // Delete local database from previous run
    NSLog(@"Deleting local database from previous run...");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fileManager removeItemAtPath:sealdDir error:&error]) {
       NSLog(@"Seald Database removed successfully");
    } else {
        NSLog(@"Error removing Seald database %@", error.userInfo);
    }
    
    // Seald uses JWT to manage licenses and identity.
    // JWTs should be generated by your backend, and sent to the user at signup.
    // The JWT secretId and secret can be generated from your administration dashboard. They should NEVER be on client side.
    // However, as this is a demo without a backend, we will use them on the frontend.
    // JWT documentation: https://docs.seald.io/en/sdk/guides/jwt.html
    // identity documentation: https://docs.seald.io/en/sdk/guides/4-identities.html
    DemoAppJWTBuilder *jwtbuilder = [[DemoAppJWTBuilder alloc] initWithJWTSharedSecretId:JWTSharedSecretId JWTSharedSecret:JWTSharedSecret];

    // let's instantiate 3 SealdSDK. They will correspond to 3 users that will exchange messages.
    SealdSdk *sdk1 = [[SealdSdk alloc] initWithApiUrl:apiURL appId:appId dbPath:[NSString stringWithFormat:@"%@/inst1", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    SealdSdk *sdk2 = [[SealdSdk alloc] initWithApiUrl:apiURL appId:appId dbPath:[NSString stringWithFormat:@"%@/inst2", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User2" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    SealdSdk *sdk3 = [[SealdSdk alloc] initWithApiUrl:apiURL appId:appId dbPath:[NSString stringWithFormat:@"%@/inst3", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User3" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    SealdAccountInfo *retrieveNoAccount = [sdk1 getCurrentAccountInfo];
    NSAssert(retrieveNoAccount == nil, @"retrieveNoAccount not nil");
    
    // Create the 3 accounts. Again, the signupJWT should be generated by your backend
    SealdAccountInfo* user1AccountInfo = [sdk1 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser1" displayName:@"User1" expireAfter:0 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    SealdAccountInfo* user2AccountInfo = [sdk2 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser2" displayName:@"User2" expireAfter:0 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    SealdAccountInfo* user3AccountInfo = [sdk3 createAccountWithSignupJwt:[jwtbuilder signupJWT] deviceName:@"deviceNameUser3" displayName:@"User3" expireAfter:0 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // retrieve info about current user before creating a user should return null
    SealdAccountInfo *retrieveAccountInfo = [sdk1 getCurrentAccountInfo];
    NSAssert([retrieveAccountInfo.userId isEqualToString:user1AccountInfo.userId], @"retrieveAccountInfo.userId incorrect");
    NSAssert([retrieveAccountInfo.deviceId isEqualToString:user1AccountInfo.deviceId],  @"retrieveAccountInfo.deviceId incorrect");
    
    // Create group: https://docs.seald.io/sdk/guides/5-groups.html
    NSArray<NSString*>* members = [NSArray arrayWithObject:user1AccountInfo.userId];
    NSArray<NSString*>* admins = [NSArray arrayWithObject:user1AccountInfo.userId];
    NSString* groupId = [sdk1 createGroup:@"group-1" members:members admins:admins error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // Manage group members and admins
    [sdk1 addGroupMembersWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user2AccountInfo.userId] adminsToSet:[NSArray new] error:&error]; // Add user2 as group member
    NSAssert(error == nil, [error localizedDescription]);
    [sdk1 addGroupMembersWithGroupId:groupId membersToAdd:[NSArray arrayWithObject:user3AccountInfo.userId] adminsToSet:[NSArray arrayWithObject:user3AccountInfo.userId] error:&error]; // user1 adds user3 as group member and group admin
    NSAssert(error == nil, [error localizedDescription]);
    [sdk3 removeGroupMembersWithGroupId:groupId membersToRemove:[NSArray arrayWithObject:user2AccountInfo.userId] error:&error];
    NSAssert(error == nil, [error localizedDescription]); // user3 can remove user2
    [sdk3 setGroupAdminsWithGroupId:groupId addToAdmins:[NSArray new] removeFromAdmins:[NSArray arrayWithObject:user1AccountInfo.userId] error:&error]; // user3 can remove user1 from admins
    NSAssert(error == nil, [error localizedDescription]);
    
    // Create encryption session: https://docs.seald.io/sdk/guides/6-encryption-sessions.html
    NSArray<NSString*>* recipients = [NSArray arrayWithObjects:user1AccountInfo.userId, user2AccountInfo.userId, groupId, nil];
    SealdEncryptionSession *es1SDK1 = [sdk1 createEncryptionSessionWithRecipients:recipients useCache:@YES error:&error]; // user1, user2, and group as recipients
    NSAssert(error == nil, [error localizedDescription]);
    
    // The SealdEncryptionSession object can encrypt and decrypt for user1
    NSString *initialString = @"a message that needs to be encrypted!";
    NSString *encryptedMessage = [es1SDK1 encryptMessage:initialString error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *decryptedMessage = [es1SDK1 decryptMessage:encryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([decryptedMessage isEqualToString:initialString], @"decryptedMessage incorrect");
    
    // Create a test file on disk that we will encrypt/decrypt
    NSString *filename = @"testfile.txt";
    NSString *fileContent = @"File clear data.";
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", sealdDir, filename];
    [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSAssert(error == nil, [error localizedDescription]);

    // Encrypt the test file. Resulting file will be written alongside the source file, with `.seald` extension added
    NSString *encryptedFileURI = [es1SDK1 encryptFileFromURI:filePath error:&error];

    // User1 can retrieve the encryptionSession directly from the encrypted file
    SealdEncryptionSession *es1SDK1FromFile = [sdk1 retrieveEncryptionSessionFromFile:encryptedFileURI useCache:YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // The retrieved session can decrypt the file.
    // The decrypted file will be named with the name it has at encryption. Any renaming of the encrypted file will be ignored.
    // NOTE: In this example, the decrypted file will have `(1)` suffix to avoid overwriting the original clear file.
    NSString *decryptedFileURI = [es1SDK1FromFile decryptFileFromURI:encryptedFileURI error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([decryptedFileURI hasSuffix:@"testfile (1).txt"], @"decryptedFileURI incorrect");
    NSString *decryptedFileContent = [NSString stringWithContentsOfFile:decryptedFileURI encoding:NSUTF8StringEncoding error:&error];
    NSAssert([fileContent isEqualToString:decryptedFileContent], @"decryptedFileContent incorrect");

    // user1 can retrieve the EncryptionSession from the encrypted message
    SealdEncryptionSession *es1SDK1RetrieveFromMess = [sdk1 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:@YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *decryptedMessageFromMess = [es1SDK1RetrieveFromMess decryptMessage:encryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([decryptedMessageFromMess isEqualToString:initialString], @"decryptedMessageFromMess incorrect");

    // user2 and user3 can retrieve the encryptionSession (from the encrypted message or the session ID).
    SealdEncryptionSession *es1SDK2 = [sdk2 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:@YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *decryptedMessageSDK2 = [es1SDK2 decryptMessage:encryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([decryptedMessageSDK2 isEqualToString:initialString], @"decryptedMessageSDK2 incorrect");
    
    SealdEncryptionSession *es1SDK3FromGroup = [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:@YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *decryptedMessageSDK3 = [es1SDK3FromGroup decryptMessage:encryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([decryptedMessageSDK3 isEqualToString:initialString], @"decryptedMessageSDK3 incorrect");
    
    // user3 removes all members of "group-1". A group without member is deleted.
    [sdk3 removeGroupMembersWithGroupId:groupId membersToRemove:[NSArray arrayWithObjects:user1AccountInfo.userId, user3AccountInfo.userId, nil] error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // user3 could retrieve the previous encryption session only because "group-1" was set as recipient.
    // As the group was deleted, it can no longer access it.
    // user3 still has the encryption session in its cache, but we can disable it.
    [sdk3 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:@YES error:&error];
    NSAssert(error != nil, @"expected error");
    NSRange range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSAssert(range.location != NSNotFound, @"invalid error");
    error = nil;
    
    NSArray<SealdActionStatus *> *respRevokeBefore = [es1SDK2 revokeRecipients:@[user3AccountInfo.userId] error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert(respRevokeBefore.count == 1, @"Unexpected response count.");
    NSAssert([user3AccountInfo.userId isEqualToString:respRevokeBefore[0].userId], @"User ID mismatch.");
    NSAssert([respRevokeBefore[0].status isEqualToString:@"ko"], @"Unexpected status.");
    
    // user2 adds user3 as recipient of the encryption session.
    NSArray<SealdActionStatus *> *respAdd = [es1SDK2 addRecipients:[NSArray arrayWithObject:user3AccountInfo.userId] error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert(respAdd.count == 1, @"Unexpected response count.");
    NSAssert([user3AccountInfo.deviceId isEqualToString:respAdd[0].userId], @"User ID mismatch.");
    NSAssert([respAdd[0].status isEqualToString:@"ok"], @"Unexpected status.");

    // user3 can now retrieve it.
    SealdEncryptionSession *es1SDK3 = [sdk3 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:@NO error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *decryptedMessageAfterAdd = [es1SDK3 decryptMessage:encryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([decryptedMessageAfterAdd isEqualToString:initialString], @"decryptedMessageAfterAdd incorrect");

    // user2 revokes user3 from the encryption session.
    NSArray<SealdActionStatus *> *respRevoke = [es1SDK2 revokeRecipients:[NSArray arrayWithObject:user3AccountInfo.userId] error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert(respRevoke.count == 1, @"Unexpected response count.");
    NSAssert([user3AccountInfo.userId isEqualToString:respRevoke[0].userId], @"User ID mismatch.");
    NSAssert([respAdd[0].status isEqualToString:@"ok"], @"Unexpected status.");

    // user3 cannot retrieve the session anymore
    [sdk3 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:@NO error:&error];
    NSAssert(error != nil, @"expected error");
    range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSAssert(range.location != NSNotFound, @"invalid error");
    error = nil;
    
    // user1 revokes all other recipients from the session
    NSArray<SealdActionStatus *> *respOther = [es1SDK1 revokeOthers:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert(respOther.count == 3, @"Unexpected response count.");
    for (SealdActionStatus *el in respOther) {
        NSAssert([el.status isEqualToString:@"ok"], @"Unexpected status.");
    }
    
    // user2 cannot retrieve the session anymore
    [sdk2 retrieveEncryptionSessionFromMessage:encryptedMessage useCache:@NO error:&error];
    NSAssert(error != nil, @"expected error");
    range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSAssert(range.location != NSNotFound, @"invalid error");
    error = nil;
    
    // user1 revokes all. It can no longer retrieve it.
    NSArray<SealdActionStatus *> *respRevokeAll = [es1SDK1 revokeAll:&error];
    NSAssert(error == nil, [error localizedDescription]);
    for (SealdActionStatus *el in respRevokeAll) {
        NSAssert([el.status isEqualToString:@"ok"], @"Unexpected status.");
    }
    
    [sdk1 retrieveEncryptionSessionWithSessionId:es1SDK1.sessionId useCache:@NO error:&error];
    NSAssert(error != nil, @"expected error");
    range = [error.localizedDescription rangeOfString:@"status: 404"];
    NSAssert(range.location != NSNotFound, @"invalid error");
    error = nil;

    // Create additional data for user1
    SealdEncryptionSession *es2SDK1 = [sdk1 createEncryptionSessionWithRecipients:[NSArray arrayWithObject:user1AccountInfo.userId] useCache:@YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *anotherMessage = @"Nobody should read that!";
    NSString *secondEncryptedMessage = [es2SDK1 encryptMessage:anotherMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // user1 can renew its key, and still decrypt old messages
    [sdk1 renewKeysWithExpireAfter:5 * 365 * 24 * 60 * 60 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    SealdEncryptionSession *es2SDK1AfterRenew = [sdk1 retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:@YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *decryptedMessageAfterRenew = [es2SDK1AfterRenew decryptMessage:secondEncryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([decryptedMessageAfterRenew isEqualToString:anotherMessage], @"invalid error");
    
    // CONNECTORS https://docs.seald.io/en/sdk/guides/jwt.html#adding-a-userid

    // we can add a custom userId using a JWT
    NSString *customConnectorJWTValue = @"user1-custom-id";
    NSString *addConnectorJWT = [jwtbuilder connectorJWTWithCustomUserId:customConnectorJWTValue appId:appId];
    [sdk1 pushJWT:addConnectorJWT error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // we can list a user connectors
    NSArray<SealdConnector *> *connectors = [sdk1 listConnectorsWithError:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *expectedConnectorValue = [NSString stringWithFormat:@"%@@%@", customConnectorJWTValue, appId];
    NSAssert([connectors count] == 1, @"connectors count incorrect");
    NSAssert([connectors[0].type isEqualToString:@"AP"], @"connectors[0].type incorrect");
    NSAssert([connectors[0].state isEqualToString:@"VO"], @"connectors[0].state incorrect");
    NSAssert([connectors[0].sealdId isEqualToString:user1AccountInfo.userId], @"connectors[0].sealdId incorrect");
    NSAssert([connectors[0].value isEqualToString: expectedConnectorValue], @"connectors[0].value incorrect");
    
    // Retrieve connector by its id
    SealdConnector *retrievedConnector = [sdk1 retrieveConnector:connectors[0].connectorId error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([retrievedConnector.type isEqualToString:@"AP"], @"retrievedConnector.type incorrect ");
    NSAssert([retrievedConnector.state isEqualToString:@"VO"], @"retrievedConnector.state incorrect");
    NSAssert([retrievedConnector.sealdId isEqualToString:user1AccountInfo.userId], @"retrievedConnector.sealdId incorrect");
    NSAssert([retrievedConnector.value isEqualToString:expectedConnectorValue], @"retrievedConnector.value incorrect");
    
    // Retrieve connectors from a user id.
    NSArray<SealdConnector *> *connectorsFromSealdId = [sdk1 getConnectorsFromSealdId:user1AccountInfo.userId error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([connectorsFromSealdId count] == 1, @"connectorsFromSealdId count incorrect");
    NSAssert([connectorsFromSealdId[0].type isEqualToString:@"AP"], @"connectorsFromSealdId[0].type incorrect");
    NSAssert([connectorsFromSealdId[0].state isEqualToString:@"VO"], @"connectorsFromSealdId[0].state incorrect");
    NSAssert([connectorsFromSealdId[0].sealdId isEqualToString:user1AccountInfo.userId], @"connectorsFromSealdId[0].sealdId incorrect");
    NSAssert([connectorsFromSealdId[0].value isEqualToString: expectedConnectorValue], @"connectorsFromSealdId[0].value incorrect");

    // Get sealdId of a user from a connector
    SealdConnectorTypeValue *connectorToSearch = [[SealdConnectorTypeValue alloc] initWithType:@"AP" value:expectedConnectorValue];
    NSArray *sealdIds = [sdk1 getSealdIdsFromConnectors:[NSArray arrayWithObject:connectorToSearch] error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([sealdIds count] == 1, @"sealdIds count incorrect");
    NSAssert([sealdIds[0] isEqualToString:user1AccountInfo.userId], @"user1AccountInfo.userId incorrect");
    
    // user1 can remove a connector
    [sdk1 removeConnector:connectors[0].connectorId error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // verify that only no connector left
    NSArray<SealdConnector *> *connectorListAfterRevoke = [sdk1 listConnectorsWithError:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([connectorListAfterRevoke count] == 0, @"connectorListAfterRevoke count incorrect");
    
    // user1 can export its identity
    NSData *exportedIdentity = [sdk1 exportIdentityWithError:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // We can instantiate a new SealdSDK, import the exported identity
    SealdSdk *sdk1Exported = [[SealdSdk alloc] initWithApiUrl:apiURL appId:appId dbPath:[NSString stringWithFormat:@"%@/inst1Exported", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1Exported" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    [sdk1Exported importIdentity:exportedIdentity error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // SDK with imported identity can decrypt
    SealdEncryptionSession *es2SDK1Exported = [sdk1Exported retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:@YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *clearMessageExportedIdentity = [es2SDK1Exported decryptMessage:secondEncryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([clearMessageExportedIdentity isEqualToString:anotherMessage], @"clearMessageExportedIdentity incorrect");

    // user1 can create sub identity
    SealdCreateSubIdentityResponse *subIdentity = [sdk1 createSubIdentityWithDeviceName:@"Sub-device" expireAfter:365 * 24 * 60 * 60 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert(subIdentity.deviceId != nil, @"subIdentity.deviceId invalid");
    
    // first device needs to reencrypt for the new device
    SealdMassReencryptOptions *massReencryptOpts = [[SealdMassReencryptOptions alloc] init];
    [sdk1 massReencryptWithDeviceId:subIdentity.deviceId options:massReencryptOpts error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // We can instantiate a new SealdSDK, import the sub-device identity
    SealdSdk *sdk1SubDevice = [[SealdSdk alloc] initWithApiUrl:apiURL appId:appId dbPath:[NSString stringWithFormat:@"%@/inst1SubDevice", sealdDir] dbb64SymKey:databaseEncryptionKeyB64 instanceName:@"User1SubDevice" logLevel:0 logNoColor:true encryptionSessionCacheTTL:0 keySize:4096 error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    [sdk1SubDevice importIdentity:subIdentity.backupKey error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // sub device can decrypt
    SealdEncryptionSession *es2SDK1SubDevice = [sdk1SubDevice retrieveEncryptionSessionFromMessage:secondEncryptedMessage useCache:@YES error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSString *clearMessageSubdIdentity = [es2SDK1SubDevice decryptMessage:secondEncryptedMessage error:&error];
    NSAssert(error == nil, [error localizedDescription]);
    NSAssert([clearMessageSubdIdentity isEqualToString:anotherMessage], @"clearMessageSubdIdentity invalid");
    
    // users can send heartbeat
    [sdk1 heartbeatWithError:&error];
    NSAssert(error == nil, [error localizedDescription]);
    
    // close SDKs
    [sdk1 closeWithError:&error];
    NSAssert(error == nil, [error localizedDescription]);
    [sdk2 closeWithError:&error];
    NSAssert(error == nil, [error localizedDescription]);
    [sdk3 closeWithError:&error];
    NSAssert(error == nil, [error localizedDescription]);
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
