//
//  NREventAttributes.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import "NREventAttributes.h"
#import "NRVALog.h"

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

// Convert any value the caller passed into something the harvest pipeline can
// safely serialize via NSJSONSerialization. Returns nil for values that can't
// be made JSON-safe — caller drops them with a log instead of letting the
// async harvest crash deep inside the dispatch queue with no link to source.
//
//   NSString / NSNumber / NSNull → passed through
//   NSDate                       → epoch-seconds NSNumber
//   NSArray / NSDictionary       → recursively sanitized; nil if any element
//                                  is unsanitizable
//   anything else                → nil (caller logs and drops)
- (nullable id)sanitizedValueForJSON:(id)value {
    if (value == nil || value == [NSNull null]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return @([(NSDate *)value timeIntervalSince1970]);
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *cleaned = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
        for (id element in (NSArray *)value) {
            id clean = [self sanitizedValueForJSON:element];
            if (clean == nil) return nil;
            [cleaned addObject:clean];
        }
        return cleaned;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *src = (NSDictionary *)value;
        NSMutableDictionary *cleaned = [NSMutableDictionary dictionaryWithCapacity:src.count];
        for (id k in src) {
            if (![k isKindOfClass:[NSString class]]) return nil;
            id clean = [self sanitizedValueForJSON:src[k]];
            if (clean == nil) return nil;
            cleaned[k] = clean;
        }
        return cleaned;
    }
    return nil;
}

- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value filter:(nullable NSString *)regexp {
    // If no filter defined, use universal filter that matches any action name
    if (!regexp) {
        regexp = @"[A-Z_]+";
    }

    id sanitized = [self sanitizedValueForJSON:value];
    if (sanitized == nil) {
        NRVA_ERROR_LOG(@"setAttribute dropped key '%@' — value of type %@ is not JSON-safe (only NSString, NSNumber, NSDate, NSNull, NSArray, NSDictionary are accepted; nested containers are sanitized recursively).",
                       key, NSStringFromClass([(NSObject *)value class]));
        return;
    }

    @synchronized (self) {
        NSMutableDictionary *bucket = self.attributeBuckets[regexp];
        if (!bucket) {
            bucket = [NSMutableDictionary dictionary];
            self.attributeBuckets[regexp] = bucket;
        }
        bucket[key] = sanitized;
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
