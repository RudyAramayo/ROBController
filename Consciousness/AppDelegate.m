//
//  AppDelegate.m
//  Consciousness
//
//  Created by Rudy Aramayo on 5/13/18.
//  Copyright © 2018 OrbitusRobotics. All rights reserved.
//

#import "AppDelegate.h"
#import "SceneDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // ROB is a persistent operator console; do not dim while it is supervising
    // a connected robot.
    application.idleTimerDisabled = YES;
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                               options:(UISceneConnectionOptions *)options
{
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc]
        initWithName:@"Default Configuration"
        sessionRole:connectingSceneSession.role];
    configuration.sceneClass = UIWindowScene.class;
    configuration.delegateClass = SceneDelegate.class;

    // Preserve the established device-specific storyboards while allowing the
    // UIWindow itself to be owned by SceneDelegate.
    NSString *storyboardName = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
        ? @"Main"
        : @"Main_iPhone";
    configuration.storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
    return configuration;
}

- (void)application:(UIApplication *)application
didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions
{
    // ROBController currently supports one operator scene. There is no
    // scene-specific persisted state to discard.
}

@end
