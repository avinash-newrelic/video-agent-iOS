//
//  NREventAttributes.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import "NREventAttributes.h"

@interface NREventAttributes ()

@property (nonatomic) NSMutableDictionary<NSString *, NSMutableDictionary *> *attributeBuckets;

@end

@implementation NREventAttributes

- (instancetype)init {
    if (self = [super init]) {
        self.attributeBuckets = @{}.mutableCopy;
    }
    return self;
}

- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value filter:(nullable NSString *)regexp {
    // If no filter defined, use universal filter that matches any action name
    if (!regexp) {
        regexp = @"[A-Z_]+";
    }

    @synchronized (self) {
        NSMutableDictionary *bucket = self.attributeBuckets[regexp];
        if (!bucket) {
            bucket = [NSMutableDictionary dictionary];
            self.attributeBuckets[regexp] = bucket;
        }
        bucket[key] = value;
    }
}

- (NSMutableDictionary *)generateAttributes:(NSString *)action append:(nullable NSDictionary *)attributes {
    NSMutableDictionary *attr = [NSMutableDictionary dictionary];

    if (attributes) {
        [attr addEntriesFromDictionary:attributes];
    }

    // Snapshot the buckets under the lock so iteration is over data that cannot
    // change underneath us. Each inner bucket is also copied because callers
    // (and this method) iterate them.
    NSDictionary<NSString *, NSDictionary *> *snapshot;
    @synchronized (self) {
        NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithCapacity:self.attributeBuckets.count];
        for (NSString *filter in self.attributeBuckets) {
            copy[filter] = [self.attributeBuckets[filter] copy];
        }
        snapshot = copy;
    }

    for (NSString *filter in snapshot) {
        if ([self checkFilter:filter withAction:action]) {
            NSDictionary *bucket = snapshot[filter];
            for (NSString *attribute in bucket) {
                attr[attribute] = bucket[attribute];
            }
        }
    }

    return attr;
}

- (BOOL)checkFilter:(NSString *)filter withAction:(NSString *)action {
    NSError  *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:filter options:0 error:&error];
    NSRange range = [regex rangeOfFirstMatchInString:action options:0 range:NSMakeRange(0, action.length)];
    return (range.location == 0 && range.length == action.length);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NREventAttributes: %@>", self.attributeBuckets];
}

@end
