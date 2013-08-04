
//
//  NSManagedObject_util.m
//  TrailTracker
//
//  Created by Anna Johnson on 1/15/13.
//
//

#import "NSManagedObject_util.h"

@implementation NSManagedObject (util)

+ (NSArray*) allObjectsForEntity:(NSString*)entityName inManagedObjectContext:(NSManagedObjectContext*)moc {
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
  [fetchRequest setEntity:entity];
  [fetchRequest setPredicate:nil];
  NSError *error;
  NSArray *objects = [moc executeFetchRequest:fetchRequest error:&error];
  if (objects && [objects count] > 0) {
    return objects;
  } else {
    return nil;
  }
}

+ (NSArray*) objectsForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName inManagedObjectContext:(NSManagedObjectContext*)moc {
  
  return [NSManagedObject objectsForKey:key value:value entityName:entityName sortField:nil inManagedObjectContext:moc];
  
}

+ (NSArray*) objectsForKey:(NSString*) key values:(NSArray*)values entityName:(NSString*) entityName sortField:(NSString*)sortField inManagedObjectContext:(NSManagedObjectContext*)moc {
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
  [fetchRequest setEntity:entity];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", key, values];
  
  [fetchRequest setPredicate:predicate];
  if (sortField) {
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc]
                                        initWithKey:sortField ascending:YES];
    NSArray* sortDescriptors = [[NSArray alloc] initWithObjects: sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
  }
  
  NSError *error;
  NSArray *objects = [moc executeFetchRequest:fetchRequest error:&error];
  
  if (objects && [objects count] > 0) {
    return objects;
  } else {
    return nil;
  }
  
}




+ (NSArray*) objectsForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName sortField:(NSString*)sortField inManagedObjectContext:(NSManagedObjectContext*)moc {
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
  [fetchRequest setEntity:entity];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", key, value];
  [fetchRequest setPredicate:predicate];
  
  if (sortField) {
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc]
                                        initWithKey:sortField ascending:YES];
    NSArray* sortDescriptors = [[NSArray alloc] initWithObjects: sortDescriptor, nil];
    [fetchRequest setSortDescriptors:sortDescriptors];
  }
  
  NSError *error;
  NSArray *objects = [moc executeFetchRequest:fetchRequest error:&error];
  
  if (objects && [objects count] > 0) {
    return objects;
  } else {
    return nil;
  }
  
}


+ (NSManagedObject*) objectForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName inManagedObjectContext:(NSManagedObjectContext*)moc {
  NSArray * objects = [NSManagedObject objectsForKey:key value:value entityName:entityName inManagedObjectContext:moc];
  if (objects && [objects count] > 0) {
    return objects[0];
  } else {
    return nil;
  }
}

+ (NSManagedObject*) newOrObjectForKey:(NSString*) key value:(NSObject*)value entityName:(NSString*) entityName inManagedObjectContext:(NSManagedObjectContext*)moc {
  NSManagedObject * object = [NSManagedObject objectForKey:key value:value entityName:entityName inManagedObjectContext:moc];
  if (!object) {
    return [NSEntityDescription insertNewObjectForEntityForName:entityName
                                         inManagedObjectContext:moc];
  }
  
  return object;
}


-(BOOL)isNew
{
  NSDictionary *vals = [self committedValuesForKeys:nil];
  return [vals count] == 0;
}
@end