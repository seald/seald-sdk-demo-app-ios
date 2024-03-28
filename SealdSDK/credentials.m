//
//  credentials.m
//  SealdSDK demo app ios_Example
//
//  Created by Mehdi on 21/02/2024.
//  Copyright © 2024 Seald SAS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "credentials.h"

// Seald account infos:
// First step with Seald: https://docs.seald.io/en/sdk/guides/1-quick-start.html
// Create a team here: https://www.seald.io/create-sdk
SealdCredentials const sealdCredentials = {
    .apiURL = @"https://api.staging-0.seald.io/",
    .appId = @"d0cc7576-bdf6-4983-b025-532d4fb01ed2",
    .JWTSharedSecretId = @"67e15895-ec9e-4566-beb8-356b6b20ed2f",
    .JWTSharedSecret = @"l43dNb1rYY8y6XWr8qbz0aZjGbwTWMXJ7ZA2rzZDq7rWFpY18WrvrEq9MWNhNPfw",
    .ssksURL = @"https://ssks.staging-0.seald.io/",
    .ssksBackendAppKey = @"e63747c1-03d3-4f3b-9cec-178d0133491b",
    .ssksTMRChallenge = @"aaaaaaaa"
};

