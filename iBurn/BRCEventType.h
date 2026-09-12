//
//  BRCEventType.h
//  iBurn
//
//  Event category enum. Formerly declared in BRCEventObject.h, which went away with
//  the Mantle/YapDatabase model family; the enum itself is still the app's event-type
//  vocabulary (filters, map pins, PlayaDB code mapping).
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BRCEventType) {
    BRCEventTypeUnknown,
    BRCEventTypeNone,
    BRCEventTypeWorkshop,
    BRCEventTypePerformance,
    BRCEventTypeSupport,
    BRCEventTypeParty,
    BRCEventTypeCeremony,
    BRCEventTypeGame,
    BRCEventTypeFire,
    BRCEventTypeAdult,
    BRCEventTypeKid,
    BRCEventTypeParade,
    BRCEventTypeOther,
    BRCEventTypeFood,
    BRCEventTypeCrafts,
    BRCEventTypeCoffee,
    BRCEventTypeHealing,
    BRCEventTypeLGBT,
    BRCEventTypeLiveMusic,
    BRCEventTypeRIDE,
    BRCEventTypeRepair,
    BRCEventTypeSustainability,
    BRCEventTypeMeditation,
};
