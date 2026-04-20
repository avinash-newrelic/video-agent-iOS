//
//  NRVAObfuscationRulesTests.m
//  NewRelicVideoCoreTests
//

@import XCTest;
#import "NRVAHarvestManager.h"
#import "NRVAVideoConfiguration.h"

@interface NRVAHarvestManager (ObfuscationTesting)
- (NSArray<NSDictionary<NSString *, id> *> *)applyObfuscationRules:(NSArray<NSDictionary<NSString *, id> *> *)events;
@property (nonatomic, strong, readonly) NSArray<NSArray *> *compiledObfuscationRules;
@end

@interface NRVAObfuscationRulesTests : XCTestCase
@end

@implementation NRVAObfuscationRulesTests

- (NRVAHarvestManager *)managerWithRules:(NSArray<NSDictionary *> *)rules {
    NRVAVideoConfiguration *config = [[[[NRVAVideoConfiguration builder]
                                        withApplicationToken:@"test-token"]
                                       withObfuscationRules:rules]
                                      build];
    return [[NRVAHarvestManager alloc] initWithConfiguration:config];
}

- (NRVAHarvestManager *)managerWithNoRules {
    NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
                                       withApplicationToken:@"test-token"]
                                      build];
    return [[NRVAHarvestManager alloc] initWithConfiguration:config];
}

#pragma mark - Configuration

- (void)testNoRulesCompilesEmptyList {
    NRVAHarvestManager *manager = [self managerWithNoRules];
    XCTAssertEqual(manager.compiledObfuscationRules.count, 0);
}

- (void)testValidRulesAreCompiled {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"account-\\d+", @"replacement": @"ACCOUNT_ID" },
        @{ @"regex": @"token=[^&]+",  @"replacement": @"token=REDACTED" },
    ]];
    XCTAssertEqual(manager.compiledObfuscationRules.count, 2);
}

- (void)testInvalidRegexThrowsAtConfigTime {
    XCTAssertThrowsSpecificNamed(
        [self managerWithRules:@[ @{ @"regex": @"[invalid", @"replacement": @"X" } ]],
        NSException,
        NSInvalidArgumentException
    );
}

#pragma mark - Basic Masking

- (void)testMatchingValueIsReplaced {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"account-\\d+", @"replacement": @"ACCOUNT_ID" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"contentId": @"account-12345" }
    ]];
    XCTAssertEqualObjects(result[0][@"contentId"], @"ACCOUNT_ID");
}

- (void)testNonMatchingValueIsUnchanged {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"account-\\d+", @"replacement": @"ACCOUNT_ID" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"contentTitle": @"My Video" }
    ]];
    XCTAssertEqualObjects(result[0][@"contentTitle"], @"My Video");
}

- (void)testPartialMatchWithinString {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"\\d+", @"replacement": @"NUM" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"src": @"https://cdn.example.com/video/12345/manifest.m3u8" }
    ]];
    XCTAssertEqualObjects(result[0][@"src"], @"https://cdn.example.com/video/NUM/manifest.mNUmu");
}

- (void)testEmptyReplacementDeletesMatch {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"secret", @"replacement": @"" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"label": @"my secret value" }
    ]];
    XCTAssertEqualObjects(result[0][@"label"], @"my  value");
}

#pragma mark - Non-String Attributes

- (void)testNumericAttributeIsUntouched {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"\\d+", @"replacement": @"NUM" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"bufferLength": @42 }
    ]];
    XCTAssertEqualObjects(result[0][@"bufferLength"], @42);
}

- (void)testBoolAttributeIsUntouched {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @".", @"replacement": @"X" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"isLive": @YES }
    ]];
    XCTAssertEqualObjects(result[0][@"isLive"], @YES);
}

#pragma mark - Rule Ordering

- (void)testRulesApplyInOrder {
    // First rule turns "secret" into "HIDDEN", second rule targets "HIDDEN"
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"secret",  @"replacement": @"HIDDEN" },
        @{ @"regex": @"HIDDEN",  @"replacement": @"REDACTED" },
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"value": @"secret" }
    ]];
    XCTAssertEqualObjects(result[0][@"value"], @"REDACTED");
}

#pragma mark - Multiple Events

- (void)testRulesApplyToAllEvents {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"token=[^&]+", @"replacement": @"token=REDACTED" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"src": @"https://cdn.example.com?token=abc123" },
        @{ @"src": @"https://cdn.example.com?token=xyz789" },
    ]];
    XCTAssertEqualObjects(result[0][@"src"], @"https://cdn.example.com?token=REDACTED");
    XCTAssertEqualObjects(result[1][@"src"], @"https://cdn.example.com?token=REDACTED");
}

- (void)testAllStringAttributesInEventAreScanned {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @"pii", @"replacement": @"***" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[
        @{ @"contentTitle": @"video-pii-title", @"contentId": @"pii-id-001", @"bitrate": @1500 }
    ]];
    XCTAssertEqualObjects(result[0][@"contentTitle"], @"video-***-title");
    XCTAssertEqualObjects(result[0][@"contentId"],    @"***-id-001");
    XCTAssertEqualObjects(result[0][@"bitrate"],      @1500);
}

#pragma mark - No Rules

- (void)testNoRulesReturnsEventsUnmodified {
    NRVAHarvestManager *manager = [self managerWithNoRules];
    NSArray *events = @[ @{ @"contentSrc": @"https://cdn.example.com/video.m3u8" } ];
    NSArray *result = [manager applyObfuscationRules:events];
    XCTAssertEqualObjects(result, events);
}

- (void)testNoRulesReturnsIdenticalPointer {
    // With no rules, the original array is returned as-is (no copy made)
    NRVAHarvestManager *manager = [self managerWithNoRules];
    NSArray *events = @[ @{ @"key": @"value" } ];
    NSArray *result = [manager applyObfuscationRules:events];
    XCTAssertTrue(result == events);
}

- (void)testEmptyEventsArrayReturnsEmpty {
    NRVAHarvestManager *manager = [self managerWithRules:@[
        @{ @"regex": @".*", @"replacement": @"X" }
    ]];
    NSArray *result = [manager applyObfuscationRules:@[]];
    XCTAssertEqual(result.count, 0);
}

@end
