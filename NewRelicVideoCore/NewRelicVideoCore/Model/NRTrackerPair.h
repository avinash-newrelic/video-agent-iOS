//
//  NRTrackerPair.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 16/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NRTracker;

/**
 Tracker pair model.
 */
@interface NRTrackerPair : NSObject

/**
 Init a NSTrackerPair with two trackers.
 
 @param first First tracker.
 @param second Second tracker.
 @return Tracker pair instance.
 */
- (instancetype)initWithFirst:(nullable NRTracker *)first second:(nullable NRTracker *)second;

/**
 Get first tracker, or nil if none was provided at init time.

 @return First tracker, or nil.
 */
- (nullable NRTracker *)first;

/**
 Get second tracker, or nil if none was provided at init time.

 @return Second tracker, or nil.
 */
- (nullable NRTracker *)second;

@end

NS_ASSUME_NONNULL_END
