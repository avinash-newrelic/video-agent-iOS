//
//  NRVAHarvestManagerQoETests.m
//  NewRelicVideoCoreTests
//
//  Unit tests for NRVAHarvestManager's QoE harvest integration.
//
//  Architecture note: in the current design (post-aa761f8), the per-cycle
//  QoE machinery — multiplier gate, dirty-KPI check, pending-final QoE,
//  cycle counting — lives on NRVideoTracker (generateQoeEventIfNeeded /
//  qoeAttributesChangedFrom:to:). NRVAHarvestManager is just the collector
//  that walks active trackers and aggregates their results. Tests for the
//  per-cycle gating belong on NRVideoTracker, not here. Tests for KPI
//  computation belong on NRQoEAggregator (already covered).
//
//  These tests cover what the harvest manager actually owns now:
//  empty-tracker behavior and exception isolation across trackers.
//

@import XCTest;
#import "NRVAHarvestManager.h"
#import "NRVAVideoConfiguration.h"

// Expose internal QoE collection method for testing.
@interface NRVAHarvestManager (Testing)
- (NSArray<NSDictionary *> *)collectAllActiveQoeEvents;
@end

@interface NRVAHarvestManagerQoETests : XCTestCase

@property (nonatomic) NRVAHarvestManager *harvestManager;

@end

@implementation NRVAHarvestManagerQoETests

- (void)setUp {
    [super setUp];
    NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
                                        withApplicationToken:@"test-token"]
                                       build];
    self.harvestManager = [[NRVAHarvestManager alloc] initWithConfiguration:config];
}

- (void)tearDown {
    self.harvestManager = nil;
    [super tearDown];
}

#pragma mark - collectAllActiveQoeEvents

/**
 With no NRVAVideo instance and no registered trackers, collection must
 return an empty (non-nil) array — never crash, never nil.
 */
- (void)testCollectReturnsEmptyArrayWhenNoActiveTrackers {
    NSArray<NSDictionary *> *result = [self.harvestManager collectAllActiveQoeEvents];
    XCTAssertNotNil(result, @"collectAllActiveQoeEvents must never return nil");
    XCTAssertEqual(result.count, 0, @"With no active trackers, result must be empty");
}

/**
 Repeated calls to collectAllActiveQoeEvents must be safe and idempotent
 when there's no underlying state. Defends against any future caching that
 might assume first-call behavior.
 */
- (void)testCollectIsIdempotentWithNoActiveTrackers {
    NSArray *first  = [self.harvestManager collectAllActiveQoeEvents];
    NSArray *second = [self.harvestManager collectAllActiveQoeEvents];
    NSArray *third  = [self.harvestManager collectAllActiveQoeEvents];
    XCTAssertEqual(first.count, 0);
    XCTAssertEqual(second.count, 0);
    XCTAssertEqual(third.count, 0);
}

@end
