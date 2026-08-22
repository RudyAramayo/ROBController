#import <UIKit/UIKit.h>

// RPLidarPolarView is internal Swift and therefore absent from a standalone
// generated Objective-C header. Xcode sees it during the mixed target build;
// this declaration exists only for the ConsciousViewController syntax fixture.
@interface RPLidarPolarView : UIView
@property(nonatomic, copy) NSArray<NSString *> *laserPoints;
@property(nonatomic, assign) float zoomScale;
@end
