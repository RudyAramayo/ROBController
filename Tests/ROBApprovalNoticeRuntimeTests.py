#!/usr/bin/env python3
"""Run the production notice lifecycle with inert UI/audio/transport substitutes."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'Consciousness/ConsciousViewController.mm').read_text()
start = source.index('- (void)refreshRobotActionNotice\n')
method = source[start:source.index('- (IBAction)reviewRobotActionNotice:', start)]
fixture = r'''
#import <Foundation/Foundation.h>
#import <math.h>

enum { ROBRobotActionStatePending = 1, ROBRobotActionStateExpired, ROBRobotActionStateAccepted,
       ROBRobotActionStateRejected, ROBRobotActionStateCancelled, ROBRobotActionStateExecuting };
enum { UIApplicationStateActive, UIApplicationStateBackground, UIControlStateNormal,
       UIAccessibilityAnnouncementNotification };
static int announcements = 0;
static void UIAccessibilityPostNotification(int kind, id value) { announcements++; }
@interface UIApplication : NSObject
@property NSInteger applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication { static UIApplication *app; if (!app) app = [self new]; return app; }
@end
@interface FixtureButton : NSObject
@property BOOL hidden;
@property NSString *title;
- (void)setTitle:(NSString *)title forState:(NSInteger)state;
@end
@implementation FixtureButton
- (void)setTitle:(NSString *)title forState:(NSInteger)state { self.title = title; }
@end
@interface FixtureTransport : NSObject
@property BOOL isConnected;
@end
@implementation FixtureTransport
@end
@interface ROBRobotActionMessage : NSObject
@property NSString *senderID;
@property NSString *callID;
@property NSString *action;
@property NSDictionary *arguments;
@property double expiresAtMilliseconds;
@property (readonly) BOOL isExpired;
@end
@implementation ROBRobotActionMessage
- (BOOL)isExpired { return self.expiresAtMilliseconds <= NSDate.date.timeIntervalSince1970 * 1000; }
@end
@interface ConsciousViewController : NSObject
@property ROBRobotActionMessage *currentRobotActionRequest;
@property BOOL robotActionsEnabled;
@property NSInteger currentRobotActionState;
@property FixtureTransport *autoNetClient;
@property FixtureButton *robotActionNoticeBanner;
@property NSTimer *robotActionNoticeTimer;
@property NSString *robotActionNoticeLedgerKey;
@property NSTimeInterval robotActionNoticeStartedAt;
@property BOOL robotActionNoticeReminderPlayed;
@property NSInteger cueCount;
@property NSInteger expiryCount;
- (void)refreshRobotActionNotice;
@end
@implementation ConsciousViewController
- (void)playRobotActionNoticeCue { self.cueCount++; }
- (NSString *)robotActionLedgerKeyForPeerID:(NSString *)peer callID:(NSString *)call { return [@[peer, call] componentsJoinedByString:@"|"]; }
- (void)expirePendingRobotActionRequest:(ROBRobotActionMessage *)request {
    self.expiryCount++;
    self.currentRobotActionState = ROBRobotActionStateExpired;
    [self refreshRobotActionNotice];
}
'''
tests = r'''
@end
#define CHECK(condition) NSCAssert((condition), @#condition)
int main() { @autoreleasepool {
    ConsciousViewController *c = [ConsciousViewController new];
    c.autoNetClient = [FixtureTransport new]; c.autoNetClient.isConnected = YES;
    c.robotActionNoticeBanner = [FixtureButton new];
    c.currentRobotActionRequest = [ROBRobotActionMessage new];
    c.currentRobotActionRequest.callID = @"call-1"; c.currentRobotActionRequest.senderID = @"cerebro";
    c.currentRobotActionRequest.action = @"arm_operation";
    c.currentRobotActionRequest.arguments = @{@"summary": @"Prepare arms"};
    c.currentRobotActionRequest.expiresAtMilliseconds = (NSDate.date.timeIntervalSince1970 + 30) * 1000;
    c.currentRobotActionState = ROBRobotActionStatePending;
    [c refreshRobotActionNotice];
    CHECK(c.cueCount == 0 && c.robotActionNoticeBanner.hidden);
    c.robotActionsEnabled = YES;
    [c refreshRobotActionNotice];
    CHECK(c.cueCount == 1 && announcements == 1 && !c.robotActionNoticeBanner.hidden);
    CHECK([c.robotActionNoticeBanner.title containsString:@"AI APPROVAL REQUESTED"]);
    CHECK([c.robotActionNoticeBanner.title containsString:@"Tap to review arm operation"]);
    NSTimer *firstTimer = c.robotActionNoticeTimer;
    for (int i = 0; i < 100; i++) [c refreshRobotActionNotice];
    CHECK(c.cueCount == 1 && c.robotActionNoticeTimer == firstTimer);
    c.robotActionNoticeStartedAt -= 11;
    for (int i = 0; i < 100; i++) [c refreshRobotActionNotice];
    CHECK(c.cueCount == 2 && announcements == 1);
    for (NSNumber *state in @[@(ROBRobotActionStateAccepted), @(ROBRobotActionStateExecuting),
                             @(ROBRobotActionStateRejected), @(ROBRobotActionStateCancelled), @(ROBRobotActionStateExpired)]) {
        c.currentRobotActionState = state.integerValue;
        [c refreshRobotActionNotice];
        CHECK(c.robotActionNoticeBanner.hidden && c.robotActionNoticeTimer == nil);
        CHECK(c.cueCount == 2);
    }
    CHECK(!firstTimer.valid);
    c.currentRobotActionRequest.callID = @"call-2";
    c.currentRobotActionState = ROBRobotActionStatePending;
    c.currentRobotActionRequest.expiresAtMilliseconds = 1;
    [c refreshRobotActionNotice];
    CHECK(c.cueCount == 2 && c.expiryCount == 1 && c.robotActionNoticeBanner.hidden);
    c.currentRobotActionRequest.expiresAtMilliseconds = (NSDate.date.timeIntervalSince1970 + 30) * 1000;
    c.currentRobotActionState = ROBRobotActionStatePending;
    [c refreshRobotActionNotice];
    CHECK(c.cueCount == 3);
    c.autoNetClient.isConnected = NO;
    [c refreshRobotActionNotice];
    CHECK(c.robotActionNoticeBanner.hidden && c.robotActionNoticeTimer == nil && c.cueCount == 3);
    c.autoNetClient.isConnected = YES;
    UIApplication.sharedApplication.applicationState = UIApplicationStateBackground;
    [c refreshRobotActionNotice];
    CHECK(c.robotActionNoticeBanner.hidden && c.cueCount == 3);
    puts("Approval notice: pending/disabled/expired, duplicate refreshes, one reminder, terminal cleanup, disconnect and background passed; no hardware access");
} return 0; }
'''
with tempfile.TemporaryDirectory(prefix='rob-approval-notice-') as directory:
    path = Path(directory)
    (path / 'fixture.mm').write_text(fixture + method + tests)
    subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-framework', 'Foundation',
                    str(path / 'fixture.mm'), '-o', str(path / 'fixture')], check=True, timeout=60)
    subprocess.run([str(path / 'fixture')], check=True, timeout=10)
