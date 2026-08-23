//
//  SceneDelegate.m
//  ROBController
//

#import "SceneDelegate.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions
{
    if (![scene isKindOfClass:UIWindowScene.class]) {
        return;
    }

    // UIKit creates this window from the UISceneConfiguration storyboard. Keep
    // a defensive fallback so restored sessions still launch if their stored
    // configuration predates the scene migration.
    if (self.window == nil) {
        NSString *storyboardName = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
            ? @"Main"
            : @"Main_iPhone";
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
        self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
        self.window.rootViewController = [storyboard instantiateInitialViewController];
    }
    [self.window makeKeyAndVisible];
}

- (void)sceneDidDisconnect:(UIScene *)scene
{
    // UIKit may release the scene while ROBController remains in memory.
}

- (void)sceneDidBecomeActive:(UIScene *)scene
{
    // Robot connectivity and telemetry timers are owned by the controller.
}

- (void)sceneWillResignActive:(UIScene *)scene
{
    // UIKit also posts UIApplicationWillResignActiveNotification, which the
    // controller uses to revoke AI action opt-in and stop push-to-talk safely.
}

- (void)sceneWillEnterForeground:(UIScene *)scene
{
}

- (void)sceneDidEnterBackground:(UIScene *)scene
{
}

@end
