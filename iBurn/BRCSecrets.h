NS_ASSUME_NONNULL_BEGIN
extern NSString * const kBRCHockeyBetaIdentifier;
extern NSString * const kBRCHockeyLiveIdentifier;

// I wish we didn't have to put this in here
// This data should be open!
//
// To generate new passcode (without salt):
// $ echo -n passcode | shasum -a 256
extern NSString * const kBRCEmbargoPasscodeSHA256Hash;

/** This URL is secret due to BMorg restrictions on placement data */
extern NSString * const kBRCUpdatesURLString;

extern NSString * const kBRCMapBoxAccessToken;
extern NSString * const kBRCMapBoxStyleURL;
NS_ASSUME_NONNULL_END
