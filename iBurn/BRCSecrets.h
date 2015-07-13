extern NSString * const kBRCHockeyBetaIdentifier;
extern NSString * const kBRCHockeyLiveIdentifier;

// I wish we didn't have to put this in here
// This data should be open!
//
// To generate new passcode (without salt):
// $ echo -n passcode | sha256sum
extern NSString * const kBRCEmbargoPasscodeSHA256Hash;

/** This URL is secret due to BMorg restrictions on placement data */
extern NSString * const kBRCUpdatesURLString;

extern NSString * const kBRCParseApplicationId;
extern NSString * const kBRCParseClientKey;