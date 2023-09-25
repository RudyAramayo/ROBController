//
//  DaydreamView.m
//  MCDemo
//
//

#import "DaydreamView.h"

@interface DaydreamView ()

@property (readwrite, assign) CGPoint currentPointL;
@property (readwrite, assign) CGPoint currentPointR;

@property (readwrite, retain) UITouch *leftTouch;
@property (readwrite, retain) UITouch *rightTouch;

@end

@implementation DaydreamView

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.currentPointL = CGPointMake(-999, -999);
    self.currentPointR = CGPointMake(-999, -999);
    [self setJoysticks];
}

- (void) setJoysticks {
    //normalize according to the frame
    self.leftJoystick = [self normalize:self.currentPointL];
    self.rightJoystick = [self normalize:CGPointMake(self.currentPointR.x - self.frame.size.width/2.0, self.currentPointR.y)];
}

- (CGPoint) normalize:(CGPoint) point {
    if (point.y == -999)
        return point;
    float x = ((point.x - self.frame.size.width/4.0) / (self.frame.size.width/4.0));
    float y = ((self.frame.size.height/2.0 - point.y) / (self.frame.size.height/2.0));
    NSLog(@"normalizedPoint %f,%f", x, y);
    return CGPointMake(x, y);
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetRGBStrokeColor(context, 0.1, 0.2, 1.0, 1.0);
    CGContextSetLineWidth(context, 2.0);
    CGContextStrokeEllipseInRect(context, CGRectMake(0, 0, self.frame.size.width/2.0, self.frame.size.height));
    CGContextStrokeEllipseInRect(context, CGRectMake(self.frame.size.width/2.0, 0, self.frame.size.width/2.0, self.frame.size.height));
    
    //[self clampCurrentPoints];
    
    if (self.currentPointL.x != -999)
    {
        CGRect borderRect = CGRectMake(self.currentPointL.x - 30.0, self.currentPointL.y - 30.0, 60.0, 60.0);
        CGContextSetRGBFillColor(context, 0.5, 0.5, 0.5, 1.0);
        CGContextFillEllipseInRect (context, borderRect);
        
        CGContextFillPath(context);
    }
    if (self.currentPointR.y != -999)
    {
        CGRect borderRect = CGRectMake(self.currentPointR.x - 30.0, self.currentPointR.y - 30.0, 60.0, 60.0);
        CGContextSetRGBFillColor(context, 0.5, 0.5, 0.5, 1.0);
        CGContextFillEllipseInRect (context, borderRect);
        
        CGContextFillPath(context);
    }
}


- (void) clampCurrentPoints
{
    if (self.currentPointL.x > self.frame.size.width/2.0)
        self.currentPointL = CGPointMake(self.frame.size.width/2.0, self.currentPointL.y);
    if (self.currentPointR.x < self.frame.size.width/2.0)
        self.currentPointR = CGPointMake(self.frame.size.width/2.0, self.currentPointR.y );
    [self setJoysticks];
}


- (void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    //assign any left and right touches
    for (id touch in touches) {
        CGPoint currentPoint = [touch locationInView:self];
        if (currentPoint.x <= self.frame.size.width/2.0) {
            self.leftTouch = touch;
        } else {
            self.rightTouch = touch;
        }
    }
    
    [self clampCurrentPoints];
    [self setNeedsDisplay];
}

- (void) touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        if (touch == self.leftTouch) {
            self.currentPointL = [touch locationInView:self];
        }
        if (touch == self.rightTouch) {
            self.currentPointR = [touch locationInView:self];
        }
    }
    [self clampCurrentPoints];
    [self setNeedsDisplay];
}

- (void) touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.currentPointL = CGPointMake(-999, -999);
    self.currentPointR = CGPointMake(-999, -999);
    [self clampCurrentPoints];
    [self setNeedsDisplay];
}



@end
