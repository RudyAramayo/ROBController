//
//  DaydreamView.h
//  MCDemo
//
//

#import <UIKit/UIKit.h>

@interface DaydreamView : UIView

@property (readwrite, assign) CGPoint leftJoystick;
@property (readwrite, assign) CGPoint rightJoystick;
/// Fires synchronously from the touch handler after either tread value changes.
/// Consumers should coalesce movement updates, but must send begin/end edges
/// immediately so motor control never waits for an unrelated sensor callback.
@property (nonatomic, copy) void (^joystickValuesDidChange)(CGPoint left, CGPoint right);

@end
