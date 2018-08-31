//
//  VideoTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "VideoTracker.h"
#import "TrackerAutomat.h"
#import "BackendActions.h"
#import "Vars.h"
#import <NewRelicAgent/NewRelic.h>

// TODO: implement Ads stuff

#define OBSERVATION_TIME        2.0f
#define HEARTBEAT_COUNT         (25.0f / OBSERVATION_TIME)
#define OVERWRITE_STUB          @throw([NSException exceptionWithName:NSGenericException reason:[NSStringFromSelector(_cmd) stringByAppendingString:@": Selector must be overwritten by subclass"] userInfo:nil]);\
                                return nil;

@interface VideoTracker ()

@property (nonatomic) TrackerAutomat *automat;
@property (nonatomic) NSTimer *playerStateObserverTimer;
@property (nonatomic) int heartbeatCounter;
@property (nonatomic) NSString *viewId;
@property (nonatomic) int viewIdIndex;
@property (nonatomic) int numErrors;

@end

@implementation VideoTracker

- (instancetype)init {
    if (self = [super init]) {
        self.automat = [[TrackerAutomat alloc] init];
    }
    return self;
}

#pragma mark - Utils

- (void)playNewVideo {
    if ([NewRelicAgent currentSessionId]) {
        self.viewId = [[NewRelicAgent currentSessionId] stringByAppendingFormat:@"-%d", self.viewIdIndex];
        self.viewIdIndex ++;
        self.numErrors = 0;
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
    }
}

- (void)updateAttributes {
    [self setOptions:@{
                       @"trackerName": [self getTrackerName],
                       @"trackerVersion": [self getTrackerVersion],
                       @"playerVersion": [self getPlayerVersion],
                       @"playerName": [self getPlayerName],
                       @"viewId": [self getViewId],
                       @"numberOfVideos": [self getNumberOfVideos],
                       @"coreVersion": [self getCoreVersion],
                       @"viewSession": [self getViewSession],
                       @"numberOfErrors": [self getNumberOfErrors],
                       @"contentBitrate": [self getBitrate],
                       @"contentRenditionWidth": [self getRenditionWidth],
                       @"contentRenditionHeight": [self getRenditionHeight],
                       @"contentDuration": [self getDuration],
                       @"contentPlayhead": [self getPlayhead],
                       @"contentSrc": [self getSrc],
                       @"contentPlayrate": [self getPlayrate],
                       @"contentFps": [self getFps],
                       @"contentIsLive": [self getIsLive],
                       @"isAd": [self getIsAd],
                       }];
}

#pragma mark - Reset and setup, to be overwritten by subclass

- (void)reset {
    self.heartbeatCounter = 0;
    self.viewId = @"";
    self.viewIdIndex = 0;
    self.numErrors = 0;
    [self playNewVideo];
    [self updateAttributes];
}

- (void)setup {}

#pragma mark - Tracker specific attributers, overwriting by subclass REQUIRED

- (NSString *)getTrackerName { OVERWRITE_STUB }

- (NSString *)getTrackerVersion { OVERWRITE_STUB }

- (NSString *)getPlayerVersion { OVERWRITE_STUB }

- (NSString *)getPlayerName { OVERWRITE_STUB }

#pragma mark - Tracker specific attributers, overwriting by subclass OPTIONAL

// TODO: if not implemented by subclass, should it be included in the attr?

- (NSNumber *)getBitrate { return @0; }

- (NSNumber *)getRenditionWidth { return @0; }

- (NSNumber *)getRenditionHeight { return @0; }

- (NSNumber *)getDuration { return @0; }

- (NSNumber *)getPlayhead { return @0; }

- (NSString *)getSrc { return @""; }

- (NSNumber *)getPlayrate { return @0; }

- (NSNumber *)getFps { return @0; }

- (NSNumber *)getIsLive { return @NO; }

- (NSNumber *)getIsAd { return @NO; }

#pragma mark - Base Tracker attributers

- (NSString *)getViewId {
    return self.viewId;
}

- (NSNumber *)getNumberOfVideos {
    return @(self.viewIdIndex);
}

- (NSString *)getCoreVersion {
    return [Vars stringFromPlist:@"CFBundleShortVersionString"];
}

- (NSString *)getViewSession {
    return [NewRelicAgent currentSessionId];
}

- (NSNumber *)getNumberOfErrors {
    return @(self.numErrors);
}

#pragma mark - Send requests and set options

- (void)preSend {
    [self updateAttributes];
}

- (void)sendRequest {
    [self preSend];
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendStart {
    [self preSend];
    [self.automat transition:TrackerTransitionFrameShown];
}

- (void)sendEnd {
    [self preSend];
    [self.automat transition:TrackerTransitionVideoFinished];
    [self playNewVideo];
}

- (void)sendPause {
    [self preSend];
    [self.automat transition:TrackerTransitionClickPause];
}

- (void)sendResume {
    [self preSend];
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendSeekStart {
    [self preSend];
    [self.automat transition:TrackerTransitionInitDraggingSlider];
}

- (void)sendSeekEnd {
    [self preSend];
    [self.automat transition:TrackerTransitionEndDraggingSlider];
}

- (void)sendBufferStart {
    [self preSend];
    [self.automat transition:TrackerTransitionInitBuffering];
}

- (void)sendBufferEnd {
    [self preSend];
    [self.automat transition:TrackerTransitionEndBuffering];
}

- (void)sendHeartbeat {
    [self preSend];
    [self.automat transition:TrackerTransitionHeartbeat];
}

- (void)sendRenditionChange {
    [self preSend];
    [self.automat transition:TrackerTransitionRenditionChanged];
}

- (void)sendError {
    [self preSend];
    [self.automat transition:TrackerTransitionErrorPlaying];
    self.numErrors ++;
}

- (void)setOptions:(NSDictionary *)opts {
    self.automat.actions.userOptions = opts.mutableCopy;
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    [self.automat.actions.userOptions setObject:value forKey:key];
}

#pragma mark - Timer stuff

- (void)startTimerEvent {
    if (self.playerStateObserverTimer) {
        [self abortTimerEvent];
    }
    
    self.playerStateObserverTimer = [NSTimer scheduledTimerWithTimeInterval:OBSERVATION_TIME
                                                                     target:self
                                                                   selector:@selector(playerObserverMethod:)
                                                                   userInfo:nil
                                                                    repeats:YES];
}

- (void)abortTimerEvent {
    [self.playerStateObserverTimer invalidate];
    self.playerStateObserverTimer = nil;
}

- (void)playerObserverMethod:(NSTimer *)timer {

    [self setOptionKey:@"contentBitrate" value:[self getBitrate]];
    
    if ([(id<VideoTrackerProtocol>)self respondsToSelector:@selector(timeEvent)]) {
        [(id<VideoTrackerProtocol>)self timeEvent];
    }
    
    self.heartbeatCounter ++;
    
    if (self.heartbeatCounter >= HEARTBEAT_COUNT) {
        self.heartbeatCounter = 0;
        [self sendHeartbeat];
    }
}

@end
