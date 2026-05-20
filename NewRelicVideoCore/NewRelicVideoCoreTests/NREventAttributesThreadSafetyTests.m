//
//  NREventAttributesThreadSafetyTests.m
//  NewRelicVideoCoreTests
//
//  Reproduces and prevents regression of the race condition that crashed
//  Bell/DeltaTre's tvOS production app with:
//    *** Collection <__NSDictionaryM> was mutated while being enumerated.
//
//  Stack trace had:
//    NREventAttributes generateAttributes:append:
//      ↑ NRVideoTracker getAttributes:attributes:
//      ↑ NRTrackerAVPlayer sendBufferStart
//      ↑ NRTrackerAVPlayer observeValueForKeyPath:ofObject:change:context:
//
//  Root cause: setAttribute: mutated NREventAttributes.attributeBuckets while
//  generateAttributes: enumerated it on another thread (AVPlayer KVO thread,
//  heartbeat timer, harvest queue).
//

@import XCTest;
#import "NREventAttributes.h"

@interface NREventAttributesThreadSafetyTests : XCTestCase

@property (nonatomic) NREventAttributes *eventAttributes;

@end

@implementation NREventAttributesThreadSafetyTests

- (void)setUp {
    [super setUp];
    self.eventAttributes = [[NREventAttributes alloc] init];
}

- (void)tearDown {
    self.eventAttributes = nil;
    [super tearDown];
}

#pragma mark - Concurrent access tests

/// Many threads reading at the same time. No mutation. Should never crash.
- (void)testConcurrentReads {
    NSLog(@"🧪 Testing concurrent reads...");

    for (int i = 0; i < 10; i++) {
        [self.eventAttributes setAttribute:[NSString stringWithFormat:@"key_%d", i]
                                     value:@(i)
                                    filter:nil];
    }

    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent reads complete"];
    expectation.expectedFulfillmentCount = 200;

    for (int i = 0; i < 200; i++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSMutableDictionary *out = [self.eventAttributes generateAttributes:@"ANY_ACTION" append:nil];
            XCTAssertEqual(out.count, (NSUInteger)10);
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        XCTAssertNil(error);
        NSLog(@"✅ Concurrent reads passed");
    }];
}

/// Many threads writing simultaneously. Should never crash and the final
/// dictionary should be in a coherent state.
- (void)testConcurrentWrites {
    NSLog(@"🧪 Testing concurrent writes...");

    NSInteger writerCount = 8;
    NSInteger writesPerWorker = 1000;
    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent writes complete"];
    expectation.expectedFulfillmentCount = (NSUInteger)writerCount;

    for (NSInteger w = 0; w < writerCount; w++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            for (NSInteger i = 0; i < writesPerWorker; i++) {
                [self.eventAttributes setAttribute:[NSString stringWithFormat:@"w%ld_k%ld", (long)w, (long)i]
                                             value:@(i)
                                            filter:nil];
            }
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:30.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Concurrent writes hung or crashed: %@", error);
    }];

    NSMutableDictionary *out = [self.eventAttributes generateAttributes:@"ANY_ACTION" append:nil];
    XCTAssertEqual(out.count, (NSUInteger)(writerCount * writesPerWorker));
    NSLog(@"✅ Concurrent writes passed (%lu keys)", (unsigned long)out.count);
}

/// THE CRITICAL TEST: concurrent readers + writers, mirroring the production
/// scenario. With the un-synchronized version of NREventAttributes this crashes
/// within ~1 second. With @synchronized + snapshot it runs to completion.
- (void)testConcurrentReadsAndWritesMirrorsProductionRace {
    NSLog(@"🧪 Testing concurrent reads + writes (production race repro)...");

    NSInteger writerCount = 4;
    NSInteger readerCount = 4;
    NSTimeInterval durationSeconds = 2.0;

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:durationSeconds];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent r/w complete"];
    expectation.expectedFulfillmentCount = (NSUInteger)(writerCount + readerCount);

    // Writers — keep mutating attributeBuckets until the deadline.
    for (NSInteger w = 0; w < writerCount; w++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSInteger i = 0;
            while ([deadline timeIntervalSinceNow] > 0) {
                [self.eventAttributes setAttribute:[NSString stringWithFormat:@"writer_%ld_key_%ld", (long)w, (long)(i % 50)]
                                             value:@(i)
                                            filter:nil];
                i++;
            }
            [expectation fulfill];
        });
    }

    // Readers — keep enumerating attributeBuckets until the deadline.
    // generateAttributes:append: is the exact code path the production crash hit.
    for (NSInteger r = 0; r < readerCount; r++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            while ([deadline timeIntervalSinceNow] > 0) {
                [self.eventAttributes generateAttributes:@"CONTENT_BUFFER_START" append:nil];
            }
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:durationSeconds + 5.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Race test hung or crashed: %@", error);
    }];

    NSLog(@"✅ Concurrent r/w passed — no mid-enumeration mutation");
}

/// Multiple filter buckets, concurrent access. Verifies that adding new bucket
/// keys (not just overwriting existing ones) is also safe — that's the case
/// that most reliably trips Cocoa's mutation guard.
- (void)testConcurrentFilterBucketAdditions {
    NSLog(@"🧪 Testing concurrent filter bucket additions...");

    NSInteger workerCount = 8;
    NSInteger filtersPerWorker = 200;
    NSTimeInterval testDuration = 1.5;

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:testDuration];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Bucket additions complete"];
    expectation.expectedFulfillmentCount = (NSUInteger)workerCount;

    // Half writers (each on its own filter pattern → growing bucket map),
    // half readers (enumerating the filter map).
    for (NSInteger w = 0; w < workerCount / 2; w++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            for (NSInteger i = 0; i < filtersPerWorker; i++) {
                NSString *uniqueFilter = [NSString stringWithFormat:@"FILTER_%ld_%ld", (long)w, (long)i];
                [self.eventAttributes setAttribute:@"key" value:@(i) filter:uniqueFilter];
            }
            [expectation fulfill];
        });
    }
    for (NSInteger r = 0; r < workerCount / 2; r++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            while ([deadline timeIntervalSinceNow] > 0) {
                [self.eventAttributes generateAttributes:@"FILTER_0_0" append:nil];
            }
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:testDuration + 5.0 handler:^(NSError *error) {
        XCTAssertNil(error, @"Bucket addition test hung or crashed: %@", error);
    }];

    NSLog(@"✅ Concurrent filter bucket additions passed");
}

#pragma mark - Correctness tests

/// After concurrent writes settle, every key should be readable with its last value.
- (void)testWritesAreReadableAfterConcurrentLoad {
    NSLog(@"🧪 Testing writes survive concurrent load...");

    NSInteger workers = 4;
    NSInteger writesPerWorker = 500;

    dispatch_group_t group = dispatch_group_create();
    for (NSInteger w = 0; w < workers; w++) {
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            for (NSInteger i = 0; i < writesPerWorker; i++) {
                [self.eventAttributes setAttribute:[NSString stringWithFormat:@"key_%ld", (long)i]
                                             value:@(w * 10000 + i)
                                            filter:nil];
            }
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    NSMutableDictionary *out = [self.eventAttributes generateAttributes:@"ANY" append:nil];
    XCTAssertEqual(out.count, (NSUInteger)writesPerWorker, @"All keys should be present after writes");
    NSLog(@"✅ %lu keys survived concurrent writes", (unsigned long)out.count);
}

/// generateAttributes: must include both the appended dictionary and the bucket attributes.
- (void)testAppendedAttributesIncludedInResult {
    [self.eventAttributes setAttribute:@"trackerKey" value:@"trackerValue" filter:nil];

    NSMutableDictionary *out = [self.eventAttributes generateAttributes:@"ACTION"
                                                                 append:@{@"appendedKey": @"appendedValue"}];

    XCTAssertEqualObjects(out[@"trackerKey"], @"trackerValue");
    XCTAssertEqualObjects(out[@"appendedKey"], @"appendedValue");
}

/// Filter expressions must still be honored after the thread-safety changes.
- (void)testFilterExpressionStillFiltersBucket {
    [self.eventAttributes setAttribute:@"contentKey" value:@"v1" filter:@"CONTENT_.*"];
    [self.eventAttributes setAttribute:@"adKey" value:@"v2" filter:@"AD_.*"];

    NSMutableDictionary *contentOut = [self.eventAttributes generateAttributes:@"CONTENT_START" append:nil];
    XCTAssertEqualObjects(contentOut[@"contentKey"], @"v1");
    XCTAssertNil(contentOut[@"adKey"], @"adKey should be filtered out for CONTENT_ events");

    NSMutableDictionary *adOut = [self.eventAttributes generateAttributes:@"AD_START" append:nil];
    XCTAssertEqualObjects(adOut[@"adKey"], @"v2");
    XCTAssertNil(adOut[@"contentKey"], @"contentKey should be filtered out for AD_ events");
}

@end
