//
//  SealdSdkWrapper.h
//  SealdSDK_Example
//
//  Created by Mehdi Kouhen on 22/02/2023.
//  Copyright © 2023 Seald SAS. All rights reserved.
//

#ifndef SealdSdkWrapper_h
#define SealdSdkWrapper_h

#import <SealdSdkInternals/SealdSdkInternals.h>

/**
 ClearFile represents a decrypted file.
 */
@interface ClearFile : NSObject
/** The filename of the decrypted file */
@property (nonatomic, strong, readonly) NSString* filename;
/** The ID of the EncryptionSession to which this file belongs */
@property (nonatomic, strong, readonly) NSString* messageId;
/** The content of the decrypted file */
@property (nonatomic, strong, readonly) NSData* fileContent;
- (instancetype)initWithFilename:(NSString*)filename messageId:(NSString*)messageId fileContent:(NSData*)fileContent;
@end

/**
 * An encryption session, with which you can then encrypt / decrypt multiple messages.
 * This should not be created directly, and should be retrieved with [SealdSDK.retrieveEncryptionSession]
 * or [SealdSDK.retrieveEncryptionSessionFromMessage].
 * @property sessionId the ID of this encryptionSession. Read-only.
 */
@interface EncryptionSession : NSObject{
    SealdSdkInternalsMobile_sdkMobileEncryptionSession* encryptionSession;
}
/** the ID of this encryptionSession. Read-only. */
@property (nonatomic, readonly) NSString* sessionId;
- (instancetype) initWithEncryptionSession:(SealdSdkInternalsMobile_sdkMobileEncryptionSession*)es;
/**
 * Encrypt a clear-text string into an encrypted message, for the recipients of this session.
 * @param clearMessage The message to encrypt.
 * @param error The error that occurred while encrypting the message, if any.
 * @return The encrypted message
 */
- (NSString*) encryptMessage:(NSString*)clearMessage
                       error:(NSError**)error;
/**
 * Decrypt an encrypted message string into the corresponding clear-text string.
 * @param encryptedMessage The encrypted message to decrypt.
 * @param error The error that occurred while decrypting the message, if any.
 * @return The decrypted clear-text message.
 */
- (NSString*) decryptMessage:(NSString*)encryptedMessage
                       error:(NSError**)error;
/**
 * Encrypt a clear-text file into an encrypted file, for the recipients of this session.
 * @param clearFile A [NSData*] of the clear-text content of the file to encrypt.
 * @param filename The name of the file to encrypt.
 * @param error The error that occurred while encrypting the file, if any.
 * @return A [NSData*] of the content of the encrypted file.
 */
- (NSData*) encryptFile:(NSData*)clearFile
               filename:(NSString*)filename
                  error:(NSError**)error;
/**
 * Decrypts an encrypted file into the corresponding clear-text file.
 * @param encryptedFile A [NSData*] of the content of the encrypted file to decrypt.
 * @param error The error that occurred while decrypting the file, if any.
 * @return A [ClearFile] instance, containing the filename and the fileContent of the decrypted file.
 */
- (ClearFile *)decryptFile:(NSData*)encryptedFile
                     error:(NSError**)error;
@end

/**
 This is the main class for the Seald SDK. It represents an instance of the Seald SDK.
 */
@interface SealdSdk : NSObject{
    SealdSdkInternalsMobile_sdkMobileSDK *sdkInstance;
}
/**
 Initialize this Seald SDK Instance.
 @param apiUrl The Seald server for this instance to use. This value is given on your Seald dashboard.
 @param appId The ID given by the Seald server to your app. This value is given on your Seald dashboard.
 @param dbPath The path where to store the local Seald database.
 @param dbb64SymKey The encryption key with which to encrypt the local Seald database. This **must** be tthe Base64 string encoding of a cryptographically random buffer of 64 bytes.
 @param instanceName An arbitrary name to give to this Seald instance. Can be useful for debugging when multiple instances are running in parallel, as it is added to logs.
 @param logLevel The minimum level of logs you want. All logs of this level or above will be displayed. `-1`: Trace; `0`: Debug; `1`: Info; `2`: Warn; `3`: Error; `4`: Fatal; `5`: Panic; `6`: NoLevel; `7`: Disabled.
 @param encryptionSessionCacheTTL The duration of cache lifetime in seconds. -1 to cache forever. Default to 0 (no cache).
 @param keySize The Asymmetric key size for newly generated keys. Defaults to 4096. Warning: for security, it is extremely not recommended to lower this value.
 @param error Error pointer.
 */
-(id)                initWithApiUrl:(NSString*)apiUrl
                              appId:(NSString*)appId
                             dbPath:(NSString*)dbPath
                        dbb64SymKey:(NSString*)dbb64SymKey
                       instanceName:(NSString*)instanceName
                           logLevel:(Byte)logLevel
          encryptionSessionCacheTTL:(long)encryptionSessionCacheTTL
                            keySize:(int)keySize
                              error:(NSError**)error;

// Account
/**
 Create a new Seald SDK Account for this Seald SDK instance.
 This function can only be called if the current SDK instance does not have an account yet.
 @param signupJwt The JWT to allow this SDK instance to create an account.
 @param deviceName A name for the device to create. This is metadata, useful on the Seald Dashboard for recognizing this device.
 @param displayName A name for the user to create. This is metadata, useful on the Seald Dashboard for recognizing this user.
 @param error Error pointer.
 @return The Seald ID of the newly created Seald user.
 */
-(NSString*) createAccount:(NSString*)signupJwt
                deviceName:(NSString*)deviceName
               displayName:(NSString*)displayName
                     error:(NSError**)error;

/**
 * Renew the keys of the current device, extending their validity.
 * If the current device has expired, you will need to call [renewKeys] before you are able to do anything else.
 * Warning: if the identity of the current device is stored externally, for example on SSKS,
 * you will want to re-export it and store it again, otherwise the previously stored identity will not be recognized anymore.
 * @param keyExpireAfter The duration during which the renewed device key will be valid without further renewal, in seconds. Optional, defaults to 5 years.
 * @param error Error pointer.
 */
-(void) renewKeys:(long)keyExpireAfter
            error:(NSError**)error;

// Groups
/**
 * Create a group, and returns the created group's ID.
 * [admins] must also be members.
 * [admins] must include yourself.
 * @param groupName A name for the group. This is metadata, useful on the Seald Dashboard for recognizing this user.
 * @param members The Seald IDs of the members to add to the group. Must include yourself.
 * @param admins The Seald IDs of the members to also add as group admins. Must include yourself.
 * @return The ID of the created group.
 */
-(NSString*) createGroup:(NSString*)groupName
                 members:(NSArray<NSString*>*)members
                  admins:(NSArray<NSString*>*)admins
                   error:(NSError**)error;

/**
 * Add members to a group.
 * Can only be done by a group administrator.
 * Can also specify which of these newly added group members should also be admins.
 * @param groupId The group in which to add members.
 * @param membersToAdd The Seald IDs of the members to add to the group.
 * @param adminsToSet The Seald IDs of the newly added members to also set as group admins.
 */
- (void) addGroupMembers:(NSString *)groupId
            membersToAdd:(NSArray<NSString*> *)membersToAdd
             adminsToSet:(NSArray<NSString*> *)adminsToSet
                   error:(NSError**)error;
/**
 * Remove members from the group.
 * Can only be done by a group administrator.
 * You should call [renewGroupKey] after this.
 * @param groupId The group from which to remove members.
 * @param membersToRemove The Seald IDs of the members to remove from the group.
 */
- (void)removeGroupMembers:(NSString *)groupId
           membersToRemove:(NSArray<NSString*> *)membersToRemove
                     error:(NSError**)error;
/**
 * Renew the group's private key.
 * Can only be done by a group administrator.
 * Should be called after removing members from the group.
 * @param groupId The group for which to renew the private key.
 */
- (void)renewGroupKey:(NSString *)groupId
                error:(NSError**)error;

/**
 * Add some existing group members to the group admins, and/or removes admin status from some existing group admins.
 * Can only be done by a group administrator.
 * @param groupId The group for which to set admins.
 * @param addToAdmins The Seald IDs of existing group members to add as group admins.
 * @param removeFromAdmins The Seald IDs of existing group members to remove from group admins.
 */
- (void)setGroupAdmins:(NSString *)groupId
           addToAdmins:(NSArray<NSString*>*)addToAdmins
      removeFromAdmins:(NSArray<NSString*>*)removeFromAdmins
                 error:(NSError**)error;

// EncryptionSession
/**
 * Create an encryption session, and returns the associated [EncryptionSession] instance,
 * with which you can then encrypt / decrypt multiple messages.
 * Warning : if you want to be able to retrieve the session later,
 * you must put your own UserId in the [recipients] argument.
 * @param recipients The Seald IDs of users who should be able to retrieve this session.
 * @param useCache Whether or not to use the cache (if enabled globally).
 * @param error The error that occurred while creating the session, if any.
 * @return The created [EncryptionSession], or null if an error occurred.
 */
- (EncryptionSession *)createEncryptionSession:(NSArray<NSString*> *)recipients
                                      useCache:(BOOL)useCache
                                         error:(NSError**)error;
/**
 * Retrieve an encryption session with the [sessionId], and returns the associated
 * [EncryptionSession] instance, with which you can then encrypt / decrypt multiple messages.
 * @param sessionId The ID of the session to retrieve.
 * @param useCache Whether or not to use the cache (if enabled globally).
 * @param error The error that occurred while retrieving the session, if any.
 * @return The retrieved [EncryptionSession], or null if an error occurred.
 */
- (EncryptionSession *)retrieveEncryptionSession:(NSString *)sessionId
                                        useCache:(BOOL)useCache
                                           error:(NSError**)error;

/**
 * Retrieve an encryption session from a seald message, and returns the associated
 * [EncryptionSession] instance, with which you can then encrypt / decrypt multiple messages.
 * @param message Any message belonging to the session to retrieve.
 * @param useCache Whether or not to use the cache (if enabled globally).
 * @param error The error that occurred while retrieving the session, if any.
 * @return The retrieved [EncryptionSession], or null if an error occurred.
 */
- (EncryptionSession *)retrieveEncryptionSessionFromMessage:(NSString *)message
                                                   useCache:(BOOL)useCache
                                                      error:(NSError**)error;

@end

#endif /* SealdSdkWrapper_h */
