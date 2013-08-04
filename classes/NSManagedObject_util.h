//
//  NSManagedObject_util.h
//  TrailTracker
//
//  Created by Anna Johnson on 5/17/13.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (util)

+ (NSArray*) allObjectsForEntity:(NSString*)entityName inManagedObjectContext:(NSManagedObjectContext*)moc;

+ (NSArray*) objectsForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName inManagedObjectContext:(NSManagedObjectContext*)moc;

+ (NSManagedObject*) objectForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName inManagedObjectContext:(NSManagedObjectContext*)moc;

+ (NSManagedObject*) newOrObjectForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName inManagedObjectContext:(NSManagedObjectContext*)moc;

+ (NSArray*) objectsForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName sortField:(NSString*)sortField inManagedObjectContext:(NSManagedObjectContext*)moc;

+ (NSArray*) objectsForKey:(NSString*) key values:(NSArray*)values entityName:(NSString*) entityName sortField:(NSString*)sortField inManagedObjectContext:(NSManagedObjectContext*)moc;

-(BOOL)isNew;

@end

