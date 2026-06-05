//
//  NRTrackerPairTests.m
//  NewRelicVideoCoreTests
//
//  Regression tests for NRTrackerPair's nil/NSNull handling.
//
//  NRTrackerPair stores [NSNull null] internally in place of a missing tracker
//  because NSArray cannot hold nil. That sentinel must not leak out of the
//  class — `first` and `second` are declared as nullable and must translate
//  NSNull back to nil. A regression here causes content-only integrations
//  (no ad tracker) to crash with `unrecognized selector sent to NSNull`
//  the first time a caller does `if (pair.second) { [pair.second ...]; }`.
//

@import XCTest;
#import "NRTrackerPair.h"
#import "NRTracker.h"

@interface NRTrackerPairTests : XCTestCase
@end

@implementation NRTrackerPairTests

- (void)testBothNilReturnsNilForBothGetters {
    NRTrackerPair *pair = [[NRTrackerPair alloc] initWithFirst:nil second:nil];
    XCTAssertNil(pair.first, @"first must be nil when constructed with nil");
    XCTAssertNil(pair.second, @"second must be nil when constructed with nil");
}

- (void)testNilFirstNeverLeaksAsNSNull {
    NRTracker *adTracker = [[NRTracker alloc] init];
    NRTrackerPair *pair = [[NRTrackerPair alloc] initWithFirst:nil second:adTracker];

    XCTAssertNil(pair.first, @"first must be nil — must not leak NSNull");
    XCTAssertFalse([pair.first isEqual:[NSNull null]], @"first must not be NSNull");
    XCTAssertEqual(pair.second, adTracker);
}

- (void)testNilSecondNeverLeaksAsNSNull {
    NRTracker *contentTracker = [[NRTracker alloc] init];
    NRTrackerPair *pair = [[NRTrackerPair alloc] initWithFirst:contentTracker second:nil];

    XCTAssertEqual(pair.first, contentTracker);
    XCTAssertNil(pair.second, @"second must be nil — must not leak NSNull");
    XCTAssertFalse([pair.second isEqual:[NSNull null]], @"second must not be NSNull");
}

- (void)testBothPresentReturnsBoth {
    NRTracker *contentTracker = [[NRTracker alloc] init];
    NRTracker *adTracker = [[NRTracker alloc] init];
    NRTrackerPair *pair = [[NRTrackerPair alloc] initWithFirst:contentTracker second:adTracker];

    XCTAssertEqual(pair.first, contentTracker);
    XCTAssertEqual(pair.second, adTracker);
}

/**
 The original Bell/DeltaTre crash signature: a content-only integration calls
 setUserId / setGlobalAttribute, the loop body does `if (pair.second)` (which
 used to pass for NSNull), then sends a message to NSNull. With first/second
 returning nil correctly, the standard truthy check now skips correctly.
 */
- (void)testContentOnlyPairIsTruthyCheckable {
    NRTracker *contentTracker = [[NRTracker alloc] init];
    NRTrackerPair *pair = [[NRTrackerPair alloc] initWithFirst:contentTracker second:nil];

    XCTAssertTrue((BOOL)pair.first, @"content tracker should be truthy");
    XCTAssertFalse((BOOL)pair.second, @"missing ad tracker must be falsy (was the bug — NSNull is truthy)");
}

@end
