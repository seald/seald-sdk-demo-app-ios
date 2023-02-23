//
//  SealdSdkWrapper.m
//  SealdSDK_Example
//
//  Created by Mehdi Kouhen on 22/02/2023.
//  Copyright © 2023 Seald SAS. All rights reserved.
//

#import "SealdSdkWrapper.h"

Mobile_sdkStringArray* arrayToStringArray(NSArray<NSString*>* stringArray) {
    Mobile_sdkStringArray* resultArray = [[Mobile_sdkStringArray alloc] init];
    
    for (NSString* string in stringArray) {
        [resultArray add:string];
    }
    
    return resultArray;
}

@implementation ClearFile
- (instancetype)initWithFilename:(NSString *)filename messageId:(NSString *)messageId fileContent:(NSData *)fileContent {
    self = [super init];
    if (self) {
        _filename = filename;
        _messageId = messageId;
        _fileContent = fileContent;
    }
    return self;
}
@end

@implementation EncryptionSession
- (instancetype) initWithEncryptionSession:(Mobile_sdkMobileEncryptionSession*)es {
    self = [super init];
    if (self) {
        encryptionSession = es;
    }
    return self;
}
- (NSString*) sessionId {
    return encryptionSession.id_;
}
// TODO: skipped method MobileEncryptionSession.AddRecipients with unsupported parameter or return types
//- (void)addRecipients:(NSArray<NSString*>*)recipients {
//    [encryptionSession addRecipients];
//}
//- (void)revokeRecipients:(NSArray<NSString *> *)recipients {
//    [encryptionSession revokeRecipientsWithRecipients:[recipients arrayByMappingObjectsUsingBlock:^id _Nullable(id  _Nonnull obj, NSUInteger idx) {
//        return [obj sealdSdk_stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
//    }]];
//}
//- (void)revokeAll {
//    [encryptionSession revokeAll];
//}
//- (void)revokeOthers {
//    [encryptionSession revokeOthers];
//}
- (NSString*) encryptMessage:(NSString*)clearMessage
                       error:(NSError**)error
{
    return [encryptionSession encryptMessage:clearMessage error:error];
}
- (NSString*) decryptMessage:(NSString*)encryptedMessage
                       error:(NSError**)error
{
    return [encryptionSession decryptMessage:encryptedMessage error:error];
}
- (NSData*) encryptFile:(NSData*)clearFile
               filename:(NSString*)filename
                  error:(NSError**)error
{
    return [encryptionSession encryptFile:clearFile filename:filename error:error];
}
- (ClearFile *)decryptFile:(NSData*)encryptedFile
                     error:(NSError**)error
{
    Common_modelsClearFile* clearFile = [encryptionSession decryptFile:encryptedFile error:error];
    return [[ClearFile alloc] initWithFilename:clearFile.filename messageId:clearFile.messageId fileContent:clearFile.fileContent];
}
@end

@implementation SealdSdk
-(id)                initWithApiUrl:(NSString*)apiUrl
                              appId:(NSString*)appId
                             dbPath:(NSString*)dbPath
                        dbb64SymKey:(NSString*)dbb64SymKey
                       instanceName:(NSString*)instanceName
                           logLevel:(Byte)logLevel
          encryptionSessionCacheTTL:(long)encryptionSessionCacheTTL
                            keySize:(int)keySize
                              error:(NSError**)error
{
    // TODO: throw if already initialized
    if (keySize == 0){
        keySize = 4096;
    }
    self = [super init];
    if (self) {
        Mobile_sdkInitializeOptions *initOpts = [[Mobile_sdkInitializeOptions alloc] init];
        initOpts.appId = appId;
        initOpts.apiURL = apiUrl;
        initOpts.databaseEncryptionKeyB64 = dbb64SymKey;
        initOpts.dbPath = dbPath;
        initOpts.instanceName = instanceName;
        
        sdkInstance = Mobile_sdkInitialize(initOpts, error);
        if (*error != nil)
        {
            return nil;
        }
    }
    return self;
}
// Account
-(NSString*) createAccount:(NSString*)signupJwt
                deviceName:(NSString*)deviceName
               displayName:(NSString*)displayName
                     error:(NSError**)error
{
    // TODO: throw if not initialized
    Common_modelsCreateAccountOptions *createAccountOpts = [[Common_modelsCreateAccountOptions alloc] init];
    createAccountOpts.signupJWT = signupJwt;
    createAccountOpts.deviceName = deviceName;
    createAccountOpts.displayName = displayName;
    
    Common_modelsAccountInfo *user1AccountInfo = [sdkInstance createAccount:createAccountOpts error:error];
    if (*error != nil)
    {
        return nil;
    }
    NSLog(@"Mobile_sdkInitialize user1AccountInfo %@", user1AccountInfo);
    return user1AccountInfo.userId;
}
-(void) renewKeys:(long)keyExpireAfter
            error:(NSError**)error
{
    if (keyExpireAfter == 0){
        keyExpireAfter = 5 * 365 * 24 * 60 * 60;
    }
    [sdkInstance renewKeys:keyExpireAfter error:error];
}
// Groups
-(NSString*) createGroup:(NSString*)groupName
                 members:(NSArray<NSString*>*)members
                  admins:(NSArray<NSString*>*)admins
                   error:(NSError**)error
{
    NSString *id = [sdkInstance createGroup:groupName members:arrayToStringArray(members) admins:arrayToStringArray(admins) error:error];
    return id;
}
- (void) addGroupMembers:(NSString *)groupId
            membersToAdd:(NSArray<NSString*> *)membersToAdd
             adminsToSet:(NSArray<NSString*> *)adminsToSet
                   error:(NSError**)error
{
    [sdkInstance addGroupMembers:groupId membersToAdd:arrayToStringArray(membersToAdd) adminsToSet:arrayToStringArray(adminsToSet) error:error];
}
- (void)removeGroupMembers:(NSString *)groupId
           membersToRemove:(NSArray<NSString*> *)membersToRemove
                     error:(NSError**)error
{
    [sdkInstance removeGroupMembers:groupId membersToRemove:arrayToStringArray(membersToRemove) error:error];
}
- (void)renewGroupKey:(NSString *)groupId
                error:(NSError**)error
{
    [sdkInstance renewGroupKey:groupId error:error];
}
- (void)setGroupAdmins:(NSString *)groupId
           addToAdmins:(NSArray<NSString*>*)addToAdmins
      removeFromAdmins:(NSArray<NSString*>*)removeFromAdmins
                 error:(NSError**)error
{
    [sdkInstance setGroupAdmins:groupId addToAdmins:arrayToStringArray(addToAdmins) removeFromAdmins:arrayToStringArray(removeFromAdmins) error:error];
}
// EncryptionSession
- (EncryptionSession *)createEncryptionSession:(NSArray<NSString*> *)recipients
                                      useCache:(BOOL)useCache
                                         error:(NSError**)error
{
    NSError *createError = nil;
    Mobile_sdkMobileEncryptionSession *es = [sdkInstance createEncryptionSession:arrayToStringArray(recipients) useCache:useCache error:&createError];
    if (createError) {
        *error = createError;
        return nil;
    }
    return [[EncryptionSession alloc] initWithEncryptionSession:es];
}
- (EncryptionSession *)retrieveEncryptionSession:(NSString *)sessionId
                                        useCache:(BOOL)useCache
                                           error:(NSError**)error
{
    NSError *retrieveError = nil;
    Mobile_sdkMobileEncryptionSession *es = [sdkInstance retrieveEncryptionSession:sessionId useCache:useCache error:&retrieveError];
    if (retrieveError) {
        *error = retrieveError;
        return nil;
    }
    return [[EncryptionSession alloc] initWithEncryptionSession:es];
}
- (EncryptionSession *)retrieveEncryptionSessionFromMessage:(NSString *)message
                                                   useCache:(BOOL)useCache
                                                      error:(NSError**)error
{
    NSError *retrieveError = nil;
    Mobile_sdkMobileEncryptionSession *es = [sdkInstance retrieveEncryptionSessionFromMessage:message useCache:useCache error:&retrieveError];
    if (retrieveError) {
        *error = retrieveError;
        return nil;
    }
    return [[EncryptionSession alloc] initWithEncryptionSession:es];
}
@end
