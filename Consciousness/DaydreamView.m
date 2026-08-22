//
//  DaydreamView.m
//  ROBController
//

#import "DaydreamView.h"

@interface DaydreamView ()

@property (readwrite, assign) CGPoint currentPointL;
@property (readwrite, assign) CGPoint currentPointR;
@property (readwrite, retain) UITouch *leftTouch;
@property (readwrite, retain) UITouch *rightTouch;
@property (nonatomic, strong) UIPanGestureRecognizer *joystickPanGestureRecognizer;
@property (nonatomic, weak) UIScrollView *coordinatedScrollView;

@end

@implementation DaydreamView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self resetJoysticks];
}

- (void)commonInit
{
    self.multipleTouchEnabled = YES;
    self.backgroundColor = [UIColor clearColor];
    self.contentMode = UIViewContentModeRedraw;
    self.joystickPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(joystickPanDidChange:)];
    self.joystickPanGestureRecognizer.minimumNumberOfTouches = 1;
    self.joystickPanGestureRecognizer.maximumNumberOfTouches = 2;
    self.joystickPanGestureRecognizer.cancelsTouchesInView = NO;
    [self addGestureRecognizer:self.joystickPanGestureRecognizer];
    [self resetJoysticks];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    UIScrollView *scrollView = nil;
    UIView *ancestor = self.superview;
    while (ancestor != nil) {
        if ([ancestor isKindOfClass:[UIScrollView class]]) {
            scrollView = (UIScrollView *)ancestor;
            break;
        }
        ancestor = ancestor.superview;
    }
    if (scrollView != nil && scrollView != self.coordinatedScrollView) {
        [scrollView.panGestureRecognizer requireGestureRecognizerToFail:self.joystickPanGestureRecognizer];
        self.coordinatedScrollView = scrollView;
    }
}

- (void)joystickPanDidChange:(UIPanGestureRecognizer *)gestureRecognizer
{
}

- (void)resetJoysticks
{
    self.currentPointL = CGPointMake(-999, -999);
    self.currentPointR = CGPointMake(-999, -999);
    self.leftJoystick = CGPointMake(-999, -999);
    self.rightJoystick = CGPointMake(-999, -999);
    self.leftTouch = nil;
    self.rightTouch = nil;
    [self setNeedsDisplay];
}

- (BOOL)usesSingleJoystick
{
    UIWindowScene *windowScene = self.window.windowScene;
    if (windowScene != nil && windowScene.interfaceOrientation != UIInterfaceOrientationUnknown) {
        return UIInterfaceOrientationIsPortrait(windowScene.interfaceOrientation);
    }
    return self.bounds.size.height > self.bounds.size.width;
}

- (CGFloat)clampUnit:(CGFloat)value
{
    return MIN(1.0, MAX(-1.0, value));
}

- (CGPoint)clampedPoint:(CGPoint)point center:(CGPoint)center radius:(CGFloat)radius
{
    CGFloat dx = point.x - center.x;
    CGFloat dy = point.y - center.y;
    CGFloat length = hypot(dx, dy);
    if (length > radius && length > 0) {
        CGFloat scale = radius / length;
        return CGPointMake(center.x + dx * scale, center.y + dy * scale);
    }
    return point;
}

- (CGFloat)dualJoystickRadius
{
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    return MAX(1.0, MIN(124.0, MIN(width * 0.16, (height - 44.0) / 2.0)));
}

- (CGPoint)leftDualJoystickCenter
{
    CGFloat radius = [self dualJoystickRadius];
    return CGPointMake(24.0 + radius, CGRectGetHeight(self.bounds) - radius - 26.0);
}

- (CGPoint)rightDualJoystickCenter
{
    CGFloat radius = [self dualJoystickRadius];
    return CGPointMake(CGRectGetWidth(self.bounds) - radius - 24.0,
                       CGRectGetHeight(self.bounds) - radius - 26.0);
}

- (void)updateJoystickValues
{
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width <= 0 || height <= 0) {
        return;
    }

    if ([self usesSingleJoystick]) {
        if (self.currentPointL.x == -999) {
            self.leftJoystick = CGPointMake(-999, -999);
            self.rightJoystick = CGPointMake(-999, -999);
            return;
        }
        CGPoint center = CGPointMake(width / 2.0, height / 2.0);
        CGFloat radius = MAX(1.0, MIN(width, height) / 2.0 - 20.0);
        self.currentPointL = [self clampedPoint:self.currentPointL center:center radius:radius];
        CGFloat turn = [self clampUnit:(self.currentPointL.x - center.x) / radius];
        CGFloat forward = [self clampUnit:(center.y - self.currentPointL.y) / radius];

        // Mix one-handed forward/turn input into independent differential
        // tread values. The legacy transport reads the Y component of each
        // joystick, so X remains zero in portrait mode.
        CGFloat leftTread = forward + turn;
        CGFloat rightTread = forward - turn;
        CGFloat normalization = MAX(1.0, MAX(fabs(leftTread), fabs(rightTread)));
        leftTread /= normalization;
        rightTread /= normalization;
        self.leftJoystick = CGPointMake(0, leftTread);
        self.rightJoystick = CGPointMake(0, rightTread);
        return;
    }

    CGFloat radius = [self dualJoystickRadius];
    CGPoint leftCenter = [self leftDualJoystickCenter];
    CGPoint rightCenter = [self rightDualJoystickCenter];

    if (self.currentPointL.x == -999) {
        self.leftJoystick = CGPointMake(-999, -999);
    } else {
        self.currentPointL = [self clampedPoint:self.currentPointL center:leftCenter radius:radius];
        self.leftJoystick = CGPointMake(
            [self clampUnit:(self.currentPointL.x - leftCenter.x) / radius],
            [self clampUnit:(leftCenter.y - self.currentPointL.y) / radius]
        );
    }

    if (self.currentPointR.x == -999) {
        self.rightJoystick = CGPointMake(-999, -999);
    } else {
        self.currentPointR = [self clampedPoint:self.currentPointR center:rightCenter radius:radius];
        self.rightJoystick = CGPointMake(
            [self clampUnit:(self.currentPointR.x - rightCenter.x) / radius],
            [self clampUnit:(rightCenter.y - self.currentPointR.y) / radius]
        );
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateJoystickValues];
    [self setNeedsDisplay];
}

- (void)drawPadInContext:(CGContextRef)context center:(CGPoint)center radius:(CGFloat)radius title:(NSString *)title
{
    CGRect padRect = CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0);
    UIColor *consoleSurface = [UIColor colorWithRed:0.035 green:0.047 blue:0.055 alpha:0.94];
    UIColor *consoleAmber = [UIColor colorWithRed:0.94 green:0.66 blue:0.25 alpha:1.0];
    CGContextSetFillColorWithColor(context, consoleSurface.CGColor);
    CGContextFillEllipseInRect(context, padRect);
    CGContextSetStrokeColorWithColor(context, consoleAmber.CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextStrokeEllipseInRect(context, padRect);

    CGContextSetStrokeColorWithColor(context, [consoleAmber colorWithAlphaComponent:0.28].CGColor);
    CGContextSetLineWidth(context, 1.0);
    CGContextMoveToPoint(context, center.x - radius * 0.78, center.y);
    CGContextAddLineToPoint(context, center.x + radius * 0.78, center.y);
    CGContextMoveToPoint(context, center.x, center.y - radius * 0.78);
    CGContextAddLineToPoint(context, center.x, center.y + radius * 0.78);
    CGContextStrokePath(context);

    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: [consoleAmber colorWithAlphaComponent:0.86]
    };
    CGSize size = [title sizeWithAttributes:attributes];
    [title drawAtPoint:CGPointMake(center.x - size.width / 2.0, center.y + radius + 5.0)
          withAttributes:attributes];
}

- (void)drawKnobInContext:(CGContextRef)context point:(CGPoint)point
{
    if (point.x == -999) {
        return;
    }
    CGRect knobRect = CGRectMake(point.x - 28.0, point.y - 28.0, 56.0, 56.0);
    UIColor *consoleAmber = [UIColor colorWithRed:0.94 green:0.66 blue:0.25 alpha:1.0];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeZero, 12.0, [consoleAmber colorWithAlphaComponent:0.72].CGColor);
    CGContextSetFillColorWithColor(context, consoleAmber.CGColor);
    CGContextFillEllipseInRect(context, knobRect);
    CGContextRestoreGState(context);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == nil) {
        return;
    }

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    if ([self usesSingleJoystick]) {
        CGPoint center = CGPointMake(width / 2.0, height / 2.0);
        CGFloat radius = MAX(1.0, MIN(width, height) / 2.0 - 20.0);
        [self drawPadInContext:context center:center radius:radius title:@"ONE-HAND DRIVE • turn + speed"];
        [self drawKnobInContext:context point:self.currentPointL];
        return;
    }

    CGFloat radius = [self dualJoystickRadius];
    CGPoint leftCenter = [self leftDualJoystickCenter];
    CGPoint rightCenter = [self rightDualJoystickCenter];
    [self drawPadInContext:context center:leftCenter radius:radius title:@"LEFT TREAD"];
    [self drawPadInContext:context center:rightCenter radius:radius title:@"RIGHT TREAD"];
    [self drawKnobInContext:context point:self.currentPointL];
    [self drawKnobInContext:context point:self.currentPointR];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if ([self usesSingleJoystick]) {
        CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        CGFloat radius = MAX(1.0, MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) / 2.0 - 20.0);
        return hypot(point.x - center.x, point.y - center.y) <= radius + 28.0;
    }

    CGFloat radius = [self dualJoystickRadius] + 28.0;
    CGPoint leftCenter = [self leftDualJoystickCenter];
    CGPoint rightCenter = [self rightDualJoystickCenter];
    return hypot(point.x - leftCenter.x, point.y - leftCenter.y) <= radius ||
           hypot(point.x - rightCenter.x, point.y - rightCenter.y) <= radius;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if ([self usesSingleJoystick]) {
        UITouch *touch = touches.anyObject;
        self.leftTouch = touch;
        self.currentPointL = [touch locationInView:self];
    } else {
        CGFloat middle = CGRectGetMidX(self.bounds);
        for (UITouch *touch in touches) {
            CGPoint point = [touch locationInView:self];
            if (point.x <= middle && self.leftTouch == nil) {
                self.leftTouch = touch;
                self.currentPointL = point;
            } else if (point.x > middle && self.rightTouch == nil) {
                self.rightTouch = touch;
                self.currentPointR = point;
            }
        }
    }
    [self updateJoystickValues];
    [self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        if (touch == self.leftTouch) {
            self.currentPointL = [touch locationInView:self];
        } else if (touch == self.rightTouch) {
            self.currentPointR = [touch locationInView:self];
        }
    }
    [self updateJoystickValues];
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        if (touch == self.leftTouch) {
            self.leftTouch = nil;
            self.currentPointL = CGPointMake(-999, -999);
        }
        if (touch == self.rightTouch) {
            self.rightTouch = nil;
            self.currentPointR = CGPointMake(-999, -999);
        }
    }
    if ([self usesSingleJoystick]) {
        [self resetJoysticks];
    } else {
        [self updateJoystickValues];
        [self setNeedsDisplay];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self resetJoysticks];
}

@end
