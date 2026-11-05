//
//  IslaMediaBridge.m
//  Isla
//
//  A tiny bridge that streams the system "Now Playing" session as JSON lines
//  and accepts transport commands on stdin. It is loaded by isla-media.pl so it
//  runs inside an Apple-signed interpreter, which macOS allows to query the
//  MediaRemote service.
//
//  Protocol
//  --------
//  stdout: one JSON object per line, e.g.
//    {"type":"state","title":"…","artist":"…","playing":true,"bundle":"…", …}
//  stdin:  one command per line:
//    play | pause | toggle | next | previous | seek <seconds> | refresh | quit
//
//  Copyright © 2026 Kyros Solutions RD. MIT License.
//

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <stdio.h>

#define ISLA_EXPORT __attribute__((visibility("default")))

typedef void (*MRGetNowPlayingInfo_t)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRRegisterNotifications_t)(dispatch_queue_t);
typedef void (*MRGetIsPlaying_t)(dispatch_queue_t, void (^)(Boolean));
typedef Boolean (*MRSendCommand_t)(int, CFDictionaryRef);
typedef void (*MRSetElapsedTime_t)(double);
typedef void (*MRGetNowPlayingClient_t)(dispatch_queue_t, void (^)(id));
typedef CFStringRef (*MRClientGetBundleIdentifier_t)(id);

static struct {
    MRGetNowPlayingInfo_t getInfo;
    MRRegisterNotifications_t registerNotifications;
    MRGetIsPlaying_t isPlaying;
    MRSendCommand_t sendCommand;
    MRSetElapsedTime_t setElapsedTime;
    MRGetNowPlayingClient_t getClient;
    MRClientGetBundleIdentifier_t clientBundleIdentifier;
    MRClientGetBundleIdentifier_t clientParentBundleIdentifier;
} MR;

static dispatch_queue_t bridgeQueue;
static uint64_t lastArtworkHash = 0;
static BOOL emitScheduled = NO;
static BOOL forceArtwork = NO;

enum {
    IslaCommandPlay = 0,
    IslaCommandPause = 1,
    IslaCommandToggle = 2,
    IslaCommandNext = 4,
    IslaCommandPrevious = 5,
};

static BOOL IslaLoadMediaRemote(void) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    if (!handle) { return NO; }
    MR.getInfo = (MRGetNowPlayingInfo_t)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
    MR.registerNotifications = (MRRegisterNotifications_t)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    MR.isPlaying = (MRGetIsPlaying_t)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    MR.sendCommand = (MRSendCommand_t)dlsym(handle, "MRMediaRemoteSendCommand");
    MR.setElapsedTime = (MRSetElapsedTime_t)dlsym(handle, "MRMediaRemoteSetElapsedTime");
    MR.getClient = (MRGetNowPlayingClient_t)dlsym(handle, "MRMediaRemoteGetNowPlayingClient");
    MR.clientBundleIdentifier = (MRClientGetBundleIdentifier_t)dlsym(handle, "MRNowPlayingClientGetBundleIdentifier");
    MR.clientParentBundleIdentifier = (MRClientGetBundleIdentifier_t)dlsym(handle, "MRNowPlayingClientGetParentAppBundleIdentifier");
    return MR.getInfo != NULL && MR.registerNotifications != NULL;
}

static uint64_t IslaHash(NSData *data) {
    // FNV-1a over a sparse sample keeps hashing cheap for large artwork.
    uint64_t hash = 1469598103934665603ULL;
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    NSUInteger step = length > 4096 ? length / 4096 : 1;
    for (NSUInteger i = 0; i < length; i += step) {
        hash ^= bytes[i];
        hash *= 1099511628211ULL;
    }
    hash ^= (uint64_t)length;
    return hash;
}

static void IslaWriteJSON(NSDictionary *object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (!data) { return; }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static id IslaValue(NSDictionary *info, NSString *key) {
    id value = info[key];
    return value == [NSNull null] ? nil : value;
}

static void IslaEmitNow(void) {
    MR.getInfo(bridgeQueue, ^(CFDictionaryRef cfInfo) {
        NSDictionary *info = (__bridge NSDictionary *)cfInfo ?: @{};
        void (^finish)(BOOL, NSString *) = ^(BOOL playing, NSString *bundle) {
            NSMutableDictionary *out = [NSMutableDictionary dictionary];
            out[@"type"] = @"state";
            out[@"playing"] = @(playing);
            if (bundle.length) { out[@"bundle"] = bundle; }

            id title = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoTitle");
            id artist = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoArtist");
            id album = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoAlbum");
            id duration = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoDuration");
            id elapsed = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoElapsedTime");
            id rate = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoPlaybackRate");
            id timestamp = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoTimestamp");
            id artwork = IslaValue(info, @"kMRMediaRemoteNowPlayingInfoArtworkData");

            if ([title isKindOfClass:NSString.class]) { out[@"title"] = title; }
            if ([artist isKindOfClass:NSString.class]) { out[@"artist"] = artist; }
            if ([album isKindOfClass:NSString.class]) { out[@"album"] = album; }
            if ([duration isKindOfClass:NSNumber.class]) { out[@"duration"] = duration; }
            if ([elapsed isKindOfClass:NSNumber.class]) { out[@"elapsed"] = elapsed; }
            if ([rate isKindOfClass:NSNumber.class]) { out[@"rate"] = rate; }
            if ([timestamp isKindOfClass:NSDate.class]) {
                out[@"timestamp"] = @([(NSDate *)timestamp timeIntervalSince1970]);
            } else {
                out[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
            }

            if ([artwork isKindOfClass:NSData.class] && [(NSData *)artwork length] > 0) {
                uint64_t hash = IslaHash(artwork);
                out[@"artworkId"] = [NSString stringWithFormat:@"%016llx", hash];
                if (hash != lastArtworkHash || forceArtwork) {
                    out[@"artwork"] = [(NSData *)artwork base64EncodedStringWithOptions:0];
                    lastArtworkHash = hash;
                }
            } else if (out[@"title"]) {
                out[@"artworkId"] = @"none";
                lastArtworkHash = 0;
            }
            forceArtwork = NO;
            IslaWriteJSON(out);
        };

        MR.isPlaying(bridgeQueue, ^(Boolean playing) {
            if (MR.getClient && MR.clientBundleIdentifier) {
                MR.getClient(bridgeQueue, ^(id client) {
                    NSString *bundle = nil;
                    if (client) {
                        if (MR.clientParentBundleIdentifier) {
                            bundle = (__bridge NSString *)MR.clientParentBundleIdentifier(client);
                        }
                        if (bundle.length == 0) {
                            bundle = (__bridge NSString *)MR.clientBundleIdentifier(client);
                        }
                    }
                    finish(playing, bundle);
                });
            } else {
                finish(playing, nil);
            }
        });
    });
}

static void IslaScheduleEmit(void) {
    dispatch_async(bridgeQueue, ^{
        if (emitScheduled) { return; }
        emitScheduled = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(80 * NSEC_PER_MSEC)), bridgeQueue, ^{
            emitScheduled = NO;
            IslaEmitNow();
        });
    });
}

static void IslaHandleCommand(NSString *line) {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) { return; }
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@" "];
    NSString *command = parts.firstObject.lowercaseString;

    if ([command isEqualToString:@"quit"]) { exit(0); }
    if ([command isEqualToString:@"refresh"]) {
        dispatch_async(bridgeQueue, ^{ forceArtwork = YES; });
        IslaScheduleEmit();
        return;
    }
    if ([command isEqualToString:@"seek"] && parts.count > 1 && MR.setElapsedTime) {
        MR.setElapsedTime(parts[1].doubleValue);
        IslaScheduleEmit();
        return;
    }
    if (!MR.sendCommand) { return; }
    int code = -1;
    if ([command isEqualToString:@"play"]) { code = IslaCommandPlay; }
    else if ([command isEqualToString:@"pause"]) { code = IslaCommandPause; }
    else if ([command isEqualToString:@"toggle"]) { code = IslaCommandToggle; }
    else if ([command isEqualToString:@"next"]) { code = IslaCommandNext; }
    else if ([command isEqualToString:@"previous"]) { code = IslaCommandPrevious; }
    if (code >= 0) {
        MR.sendCommand(code, NULL);
        IslaScheduleEmit();
    }
}

static void IslaStartInputReader(void) {
    NSThread *reader = [[NSThread alloc] initWithBlock:^{
        char buffer[1024];
        while (fgets(buffer, sizeof(buffer), stdin) != NULL) {
            NSString *line = [NSString stringWithUTF8String:buffer];
            if (line) { IslaHandleCommand(line); }
        }
        // The host app went away: shut down with it.
        exit(0);
    }];
    reader.name = @"isla.media.input";
    [reader start];
}

ISLA_EXPORT void isla_media_stream(void) {
    @autoreleasepool {
        if (!IslaLoadMediaRemote()) {
            IslaWriteJSON(@{ @"type": @"error", @"message": @"MediaRemote unavailable" });
            exit(2);
        }
        bridgeQueue = dispatch_queue_create("isla.media.bridge", DISPATCH_QUEUE_SERIAL);
        MR.registerNotifications(bridgeQueue);

        NSArray<NSString *> *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            @"kMRMediaRemoteNowPlayingPlaybackQueueChangedNotification",
        ];
        for (NSString *name in names) {
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
                IslaScheduleEmit();
            }];
        }

        IslaWriteJSON(@{ @"type": @"ready" });
        IslaStartInputReader();
        IslaScheduleEmit();

        // Periodic resync keeps elapsed time honest for players that rarely notify.
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, bridgeQueue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), 5 * NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{ IslaEmitNow(); });
        dispatch_resume(timer);

        CFRunLoopRun();
    }
}
