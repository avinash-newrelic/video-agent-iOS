//
//  NREventAttributesValueSanitizationTests.m
//  NewRelicVideoCoreTests
//
//  Regression tests for the JSON-safe value sanitization at the
//  setAttribute: storage boundary.
//
//  Background: setAttribute: accepts `id<NSCopying>` for value, but the
//  harvest pipeline serializes via NSJSONSerialization, which only accepts
//  NSString / NSNumber / NSArray / NSDictionary / NSNull. Before this fix,
//  passing NSDate, NSURL, custom objects, or nested containers holding any
//  of those would crash the harvest queue asynchronously — far from the
//  offending callsite, with no link back to source.
//
//  Sanitization runs at NREventAttributes.setAttribute: and either
//    (a) converts the value (NSDate → epoch-seconds NSNumber)
//    (b) passes it through (NSString, NSNumber, NSNull, JSON-safe containers)
//    (c) for NSArray/NSDictionary: strips unsanitizable elements/entries (logged)
//        and keeps the rest — partial data is better than losing the whole container
//    (d) drops the entire value with a log (top-level unsanitizable type)
//

@import XCTest;
#import "NREventAttributes.h"

@interface NREventAttributes (Testing)
- (nullable id)sanitizedValueForJSON:(id)value;
- (NSMutableDictionary *)generateAttributes:(NSString *)action append:(nullable NSDictionary *)attributes;
@end

@interface NREventAttributesValueSanitizationTests : XCTestCase

@property (nonatomic) NREventAttributes *attrs;

@end

@implementation NREventAttributesValueSanitizationTests

- (void)setUp {
    [super setUp];
    self.attrs = [[NREventAttributes alloc] init];
}

- (void)tearDown {
    self.attrs = nil;
    [super tearDown];
}

#pragma mark - sanitizedValueForJSON: pure conversion behaviour

- (void)testStringPassesThroughUnchanged {
    XCTAssertEqualObjects([self.attrs sanitizedValueForJSON:@"hello"], @"hello");
}

- (void)testNumberPassesThroughUnchanged {
    XCTAssertEqualObjects([self.attrs sanitizedValueForJSON:@(42)], @(42));
    XCTAssertEqualObjects([self.attrs sanitizedValueForJSON:@(3.14)], @(3.14));
    XCTAssertEqualObjects([self.attrs sanitizedValueForJSON:@YES], @YES);
}

- (void)testNSNullPassesThrough {
    XCTAssertEqual([self.attrs sanitizedValueForJSON:[NSNull null]], [NSNull null]);
}

- (void)testNSDateConvertsToEpochSeconds {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1700000000.5];
    id result = [self.attrs sanitizedValueForJSON:date];
    XCTAssertTrue([result isKindOfClass:[NSNumber class]]);
    XCTAssertEqualWithAccuracy([(NSNumber *)result doubleValue], 1700000000.5, 0.001);
}

- (void)testFlatJSONSafeDictionaryPassesThrough {
    NSDictionary *input = @{ @"k1": @"string", @"k2": @(7), @"k3": [NSNull null] };
    id result = [self.attrs sanitizedValueForJSON:input];
    XCTAssertEqualObjects(result, input);
}

- (void)testFlatJSONSafeArrayPassesThrough {
    NSArray *input = @[ @"a", @(1), @YES, [NSNull null] ];
    id result = [self.attrs sanitizedValueForJSON:input];
    XCTAssertEqualObjects(result, input);
}

- (void)testNestedDictionaryWithDateIsRecursivelyConverted {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1000];
    NSDictionary *input = @{ @"label": @"x", @"when": date };
    id result = [self.attrs sanitizedValueForJSON:input];
    XCTAssertTrue([result isKindOfClass:[NSDictionary class]]);
    XCTAssertEqualObjects(result[@"label"], @"x");
    XCTAssertEqualObjects(result[@"when"], @(1000));
}

- (void)testArrayWithDateIsRecursivelyConverted {
    NSArray *input = @[ @"first", [NSDate dateWithTimeIntervalSince1970:500], @(99) ];
    NSArray *result = [self.attrs sanitizedValueForJSON:input];
    XCTAssertEqual(result.count, 3);
    XCTAssertEqualObjects(result[0], @"first");
    XCTAssertEqualObjects(result[1], @(500));
    XCTAssertEqualObjects(result[2], @(99));
}

- (void)testURLIsRejected {
    XCTAssertNil([self.attrs sanitizedValueForJSON:[NSURL URLWithString:@"https://example.com"]]);
}

- (void)testDataIsRejected {
    XCTAssertNil([self.attrs sanitizedValueForJSON:[NSData dataWithBytes:"x" length:1]]);
}

- (void)testCustomObjectIsRejected {
    XCTAssertNil([self.attrs sanitizedValueForJSON:[[NSObject alloc] init]]);
}

- (void)testDictionaryWithNonStringKeyDropsEntryKeepsRest {
    // Numeric key is not JSON-safe — that entry is dropped, but other valid entries survive.
    NSMutableDictionary *bad = [NSMutableDictionary dictionary];
    [bad setObject:@"good_value" forKey:@"valid_key"];
    bad[@(1)] = @"numeric_key_value";  // non-string key — dropped
    NSDictionary *result = [self.attrs sanitizedValueForJSON:bad];
    XCTAssertNotNil(result, @"dict is not nil — valid entries are kept");
    XCTAssertEqualObjects(result[@"valid_key"], @"good_value");
    XCTAssertEqual(result.count, 1, @"only the valid entry survives");
}

- (void)testDictionaryContainingURLDropsEntryKeepsRest {
    NSDictionary *mixed = @{ @"ok": @"keep_me", @"link": [NSURL URLWithString:@"https://example.com"] };
    NSDictionary *result = [self.attrs sanitizedValueForJSON:mixed];
    XCTAssertNotNil(result, @"dict is not nil — valid entries are kept");
    XCTAssertEqualObjects(result[@"ok"], @"keep_me");
    XCTAssertNil(result[@"link"], @"NSURL entry must be stripped");
    XCTAssertEqual(result.count, 1);
}

- (void)testArrayContainingURLDropsElementKeepsRest {
    NSArray *mixed = @[ @"ok", [NSURL URLWithString:@"https://example.com"], @(42) ];
    NSArray *result = [self.attrs sanitizedValueForJSON:mixed];
    XCTAssertNotNil(result, @"array is not nil — valid elements are kept");
    XCTAssertEqual(result.count, 2, @"URL element is stripped, the other two survive");
    XCTAssertEqualObjects(result[0], @"ok");
    XCTAssertEqualObjects(result[1], @(42));
}

- (void)testArrayWithAllUnsanitizableElementsReturnsEmptyArray {
    NSArray *allBad = @[ [NSURL URLWithString:@"x"], [NSData data] ];
    NSArray *result = [self.attrs sanitizedValueForJSON:allBad];
    XCTAssertNotNil(result, @"returns empty array, not nil");
    XCTAssertEqual(result.count, 0);
}

#pragma mark - setAttribute integration

- (void)testSetAttributeStoresStringValue {
    [self.attrs setAttribute:@"k" value:@"v" filter:nil];
    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];
    XCTAssertEqualObjects(result[@"k"], @"v");
}

- (void)testSetAttributeConvertsDate {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:2000];
    [self.attrs setAttribute:@"when" value:(id<NSCopying>)date filter:nil];
    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];
    XCTAssertEqualObjects(result[@"when"], @(2000));
}

- (void)testSetAttributeDropsURLAndLeavesPriorValue {
    [self.attrs setAttribute:@"k" value:@"original" filter:nil];
    [self.attrs setAttribute:@"k"
                       value:(id<NSCopying>)[NSURL URLWithString:@"https://example.com"]
                      filter:nil];
    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];
    XCTAssertEqualObjects(result[@"k"], @"original",
                          @"unsanitizable value must be dropped — prior value preserved");
}

- (void)testSetAttributeDropsURLAndLeavesKeyAbsent {
    [self.attrs setAttribute:@"never_set" value:(id<NSCopying>)[NSURL URLWithString:@"x"] filter:nil];
    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];
    XCTAssertNil(result[@"never_set"], @"unsanitizable value on first write must not create the key");
}

- (void)testSetAttributeWithNilValueIsSilentlyDropped {
    // nil should be silently dropped (no error log, no crash, key stays absent)
    [self.attrs setAttribute:@"k" value:nil filter:nil];
    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];
    XCTAssertNil(result[@"k"], @"nil value must be silently dropped without creating the key");
}

- (void)testSetAttributeArrayWithMixedTypesKeepsValidElements {
    // Partial container fix: array stores valid elements, strips the NSURL.
    NSArray *mixed = @[ @"title", [NSURL URLWithString:@"x"], @(99) ];
    [self.attrs setAttribute:@"arr" value:(id<NSCopying>)mixed filter:nil];
    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];
    NSArray *stored = result[@"arr"];
    XCTAssertNotNil(stored);
    XCTAssertEqual(stored.count, 2, @"only the two valid elements survive");
    XCTAssertEqualObjects(stored[0], @"title");
    XCTAssertEqualObjects(stored[1], @(99));
}

- (void)testSetAttributeDictWithMixedValuesKeepsValidEntries {
    // Partial container fix: dict stores valid entries, strips the NSURL value.
    NSDictionary *mixed = @{ @"label": @"keep", @"link": [NSURL URLWithString:@"x"] };
    [self.attrs setAttribute:@"meta" value:(id<NSCopying>)mixed filter:nil];
    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];
    NSDictionary *stored = result[@"meta"];
    XCTAssertNotNil(stored);
    XCTAssertEqual(stored.count, 1);
    XCTAssertEqualObjects(stored[@"label"], @"keep");
    XCTAssertNil(stored[@"link"]);
}

/**
 The end-to-end claim of the fix: any value that survives setAttribute must be
 JSON-serializable. If this passes, the harvest pipeline will not crash on it.
 */
- (void)testStoredAttributesAreAlwaysJSONSerializable {
    [self.attrs setAttribute:@"str" value:@"x" filter:nil];
    [self.attrs setAttribute:@"num" value:@(7) filter:nil];
    [self.attrs setAttribute:@"date" value:(id<NSCopying>)[NSDate date] filter:nil];
    [self.attrs setAttribute:@"nested"
                       value:@{ @"inner_date": [NSDate dateWithTimeIntervalSince1970:0] }
                      filter:nil];
    [self.attrs setAttribute:@"array" value:@[ @(1), @"two", @(3.0) ] filter:nil];
    // Mixed array: NSURL stripped, valid elements kept — result must still be JSON-safe.
    NSArray *mixed = @[ @"good", [NSURL URLWithString:@"x"], @(5) ];
    [self.attrs setAttribute:@"mixed_array" value:(id<NSCopying>)mixed filter:nil];

    // These top-level unsanitizable values are dropped entirely, never reach storage:
    [self.attrs setAttribute:@"url" value:(id<NSCopying>)[NSURL URLWithString:@"x"] filter:nil];
    [self.attrs setAttribute:@"data" value:(id<NSCopying>)[NSData data] filter:nil];

    NSDictionary *result = [self.attrs generateAttributes:@"ANY_ACTION" append:nil];

    NSError *err = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:result options:0 error:&err];
    XCTAssertNotNil(json, @"every stored value must be JSON-serializable");
    XCTAssertNil(err);

    XCTAssertNil(result[@"url"], @"NSURL must have been dropped");
    XCTAssertNil(result[@"data"], @"NSData must have been dropped");

    NSArray *storedMixed = result[@"mixed_array"];
    XCTAssertEqual(storedMixed.count, 2, @"valid elements from mixed array survive");
}

@end
