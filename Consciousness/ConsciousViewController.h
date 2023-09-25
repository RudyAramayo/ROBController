//
//  ViewController.h
//  Consciousness
//
//  Created by Rudy Aramayo on 5/13/18.
//  Copyright © 2018 OrbitusRobotics. All rights reserved.
//

#import <UIKit/UIKit.h>
@class EAGLView;

@interface ConsciousViewController : UIViewController
{
    IBOutlet EAGLView       *glview;
}

- (IBAction) languageAction:(id)sender;
- (IBAction) controllerAction:(id)sender;

@end

