# Seald SDK demo app iOS Objective-C

This is a basic app, demonstrating use of the Seald SDK for iOS in Objective-C.

You can check the reference documentation at <https://docs.seald.io/sdk/seald-sdk-ios/>.

The main file you could be interested in reading is [`./SealdSDK/SEALDSDKAppDelegate.m`](./SealdSDK/SEALDSDKAppDelegate.m).

Before running the app, you have to install the Cocoapods, with the command `pod install`.

Also, it is recommended to create your own Seald team on <https://www.seald.io/create-sdk>,
and change the values of `appId`, `JWTSharedSecretId`, and `JWTSharedSecret`, that you can get on the `SDK` tab
of the Seald dashboard settings, as well as `ssksBackendAppKey` that you can get on the `SSKS` tab,
in `./SealdSDK/credentials.m`,
so that the example runs in your own Seald team.

Finally, to run the app, open `SealdSDK demo app ios.xcworkspace` in XCode, then run it.
