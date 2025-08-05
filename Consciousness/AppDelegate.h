//
//  AppDelegate.h
//  Consciousness
//
//  Created by Rudy Aramayo on 5/13/18.
//  Copyright © 2018 OrbitusRobotics. All rights reserved.
//

#import <UIKit/UIKit.h>
@class EAGLView;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    IBOutlet EAGLView       *view;
}
@property (strong, nonatomic) UIWindow      *window;
@property (nonatomic, retain) EAGLView      *view;


@end

