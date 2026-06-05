//
//  NRTrackerPair.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 16/12/2020.
//

#import "NRTrackerPair.h"
#import "NRTracker.h"

@interface NRTrackerPair ()

@property (nonatomic) NSArray<NRTracker *> *pair;

@end

@implementation NRTrackerPair

// NSArray cannot hold nil, so a missing tracker is stored internally as NSNull.
// That sentinel is an implementation detail — `first` and `second` translate
// it back to nil so callers always see nil-or-tracker, never NSNull.
- (instancetype)initWithFirst:(nullable NRTracker *)first second:(nullable NRTracker *)second {
    if (self = [super init]) {
        if (first == nil) {
            first = (NRTracker *)[NSNull null];
        }
        if (second == nil) {
            second = (NRTracker *)[NSNull null];
        }
        self.pair = @[first, second];
    }
    return self;
}

- (nullable NRTracker *)first {
    id value = self.pair[0];
    return value == [NSNull null] ? nil : value;
}

- (nullable NRTracker *)second {
    id value = self.pair[1];
    return value == [NSNull null] ? nil : value;
}

@end
