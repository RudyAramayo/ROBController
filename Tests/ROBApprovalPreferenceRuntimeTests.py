#!/usr/bin/env python3
"""Exercise production approval preference recovery with inert transport/UI."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'Consciousness/ConsciousViewController.mm').read_text()
start = source.index('- (void)setRobotActionsEnabled:(BOOL)enabled reason:(NSString *)reason\n')
methods = source[start:source.index('- (void)applicationWillResignActive:', start)]
# Isolate the only persistent dependency in a disposable defaults suite.
methods = methods.replace('NSUserDefaults.standardUserDefaults', 'fixtureDefaults')
registration = next(line.strip() for line in source.splitlines()
                    if 'registerDefaults:@{@"ROBAcceptActionApprovalRequests"' in line)
registration = registration.replace('NSUserDefaults.standardUserDefaults', 'fixtureDefaults')

fixture = r'''
#import <Foundation/Foundation.h>
enum { ROBRobotActionStateNone, ROBRobotActionStatePending, ROBRobotActionStateAccepted,
       ROBRobotActionStateExecuting, ROBRobotActionStateCancelled };
enum { UIApplicationStateActive, UIApplicationStateBackground };
static NSUserDefaults *fixtureDefaults;
@interface UIApplication : NSObject
@property NSInteger applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication { static UIApplication *app; if (!app) app = [self new]; return app; }
@end
@interface FixtureTransport : NSObject
@property BOOL isConnected;
@end
@implementation FixtureTransport
@end
@interface ConsciousViewController : NSObject
@property BOOL robotActionsEnabled;
@property NSInteger currentRobotActionState;
@property id currentRobotActionRequest;
@property NSTimer *robotActionExpiryTimer;
@property BOOL didAnnounceRobotActionConsole;
@property FixtureTransport *autoNetClient;
@property NSMutableArray<NSNumber *> *sentStates;
@property NSInteger helloCount;
- (void)restoreRobotActionRequestPreference;
@end
@implementation ConsciousViewController
- (void)refreshRobotActionConsole {}
- (void)announceRobotActionConsole { self.helloCount++; }
- (void)sendRobotActionStatusForRequest:(id)request state:(NSInteger)state
                                detail:(NSString *)detail result:(NSDictionary *)result {
    [self.sentStates addObject:@(state)];
}
'''
tests = r'''
@end
#define CHECK(condition) NSCAssert((condition), @#condition)
int main() { @autoreleasepool {
    NSString *suite = [@"ROBApprovalPreferenceFixture." stringByAppendingString:NSUUID.UUID.UUIDString];
    fixtureDefaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    REGISTRATION
    ConsciousViewController *c = [ConsciousViewController new];
    c.autoNetClient = [FixtureTransport new]; c.sentStates = [NSMutableArray array];
    CHECK([fixtureDefaults boolForKey:@"ROBAcceptActionApprovalRequests"]);
    [c restoreRobotActionRequestPreference];
    CHECK(!c.robotActionsEnabled && c.helloCount == 0);
    c.autoNetClient.isConnected = YES;
    [c restoreRobotActionRequestPreference];
    CHECK(c.robotActionsEnabled && c.currentRobotActionState == ROBRobotActionStateNone);
    CHECK(c.sentStates.count == 0 && c.helloCount == 1);

    c.currentRobotActionRequest = @"pending-call";
    c.currentRobotActionState = ROBRobotActionStatePending;
    c.autoNetClient.isConnected = NO;
    [c setRobotActionsEnabled:NO reason:@"Disconnected"];
    CHECK(!c.robotActionsEnabled && c.currentRobotActionState == ROBRobotActionStateCancelled);
    CHECK([c.sentStates isEqual:@[@(ROBRobotActionStateCancelled)]]);
    CHECK([fixtureDefaults boolForKey:@"ROBAcceptActionApprovalRequests"]);
    c.autoNetClient.isConnected = YES;
    [c restoreRobotActionRequestPreference];
    CHECK(c.robotActionsEnabled && c.currentRobotActionState == ROBRobotActionStateCancelled);
    CHECK(c.sentStates.count == 1); // Cancelled request is not replayed or accepted.

    UIApplication.sharedApplication.applicationState = UIApplicationStateBackground;
    [c restoreRobotActionRequestPreference];
    CHECK(!c.robotActionsEnabled && [fixtureDefaults boolForKey:@"ROBAcceptActionApprovalRequests"]);
    UIApplication.sharedApplication.applicationState = UIApplicationStateActive;
    [c robotActionConsoleDidBecomeActive:nil];
    CHECK(c.robotActionsEnabled && c.sentStates.count == 1);

    [c toggleRobotActionsEnabled:nil];
    CHECK(!c.robotActionsEnabled && ![fixtureDefaults boolForKey:@"ROBAcceptActionApprovalRequests"]);
    [c restoreRobotActionRequestPreference];
    CHECK(!c.robotActionsEnabled);
    // Relaunch restores an explicit Off instead of overriding it with the default.
    fixtureDefaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    REGISTRATION
    [c robotActionConsoleDidBecomeActive:nil];
    CHECK(!c.robotActionsEnabled);
    // An offline toggle changes preference but cannot advertise readiness.
    c.autoNetClient.isConnected = NO;
    [c toggleRobotActionsEnabled:nil];
    CHECK([fixtureDefaults boolForKey:@"ROBAcceptActionApprovalRequests"] && !c.robotActionsEnabled);
    [c toggleRobotActionsEnabled:nil];
    CHECK(![fixtureDefaults boolForKey:@"ROBAcceptActionApprovalRequests"] && !c.robotActionsEnabled);
    c.autoNetClient.isConnected = YES;
    [c restoreRobotActionRequestPreference];
    CHECK(!c.robotActionsEnabled && c.sentStates.count == 1);
    [c toggleRobotActionsEnabled:nil];
    CHECK(c.robotActionsEnabled && c.currentRobotActionState == ROBRobotActionStateCancelled);
    CHECK(c.sentStates.count == 1);
    [fixtureDefaults removePersistentDomainForName:suite];
    puts("Approval preference: default receipt, authenticated reconnect, foreground recovery, persistent Off, offline toggle and cancelled-request non-replay passed; no hardware access");
} return 0; }
'''.replace('REGISTRATION', registration)
with tempfile.TemporaryDirectory(prefix='rob-approval-preference-') as directory:
    path = Path(directory)
    (path / 'fixture.mm').write_text(fixture + methods + tests)
    subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-framework', 'Foundation',
                    str(path / 'fixture.mm'), '-o', str(path / 'fixture')], check=True, timeout=60)
    subprocess.run([str(path / 'fixture')], check=True, timeout=10)
