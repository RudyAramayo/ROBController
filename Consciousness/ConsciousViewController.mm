//
//  ViewController.m
//  Consciousness
//
//  Created by Rudy Aramayo on 5/13/18.
//  Copyright © 2018 OrbitusRobotics. All rights reserved.
//

#import "ConsciousViewController.h"
#import "EAGLView.h"
#import "DaydreamView.h"

#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <CoreMotion/CoreMotion.h>
#import <MapKit/MapKit.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import "ROBController-Swift.h"

@interface ConsciousViewController () <AVAudioPlayerDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVSpeechSynthesizerDelegate, SFSpeechRecognizerDelegate, SFSpeechRecognitionTaskDelegate, UITableViewDelegate, UITableViewDataSource, AutoNetClientDataDelegate, CLLocationManagerDelegate, ROBOpenStreetMapViewDelegate>
{
    AVCaptureSession *session;
    AVCaptureDevice *inputDevice;
    AVCaptureDeviceInput *deviceInput;
    
}
@property (readwrite, assign) bool isAnimating;
@property (readwrite, assign) bool isAnimatingControllerMenu;

@property (readwrite, assign) bool flipper_FORWARD_isDown;
@property (readwrite, assign) bool flipper_RELAX_isDown;
@property (readwrite, assign) bool flipper_BACKWARD_isDown;
@property (readwrite, assign) bool flipper_BRAKELOCK;
@property (readwrite, assign) bool tred_BRAKELOCK;

@property (readwrite, assign) bool lact_BACK_isDown;
@property (readwrite, assign) bool lact_GRAVITY_toggle;
@property (readwrite, assign) bool lact_FRONT_isDown;

@property (readwrite, assign) bool speed_ForwardReverse_toggle;
@property (readwrite, assign) bool speed_PlayPause_toggle;

@property (readwrite, assign) IBOutlet NSLayoutConstraint *controlTrailingSpace;
@property (readwrite, assign) IBOutlet NSLayoutConstraint *languageLeadingSpace;

@property (readwrite, assign) float speed;
@property (readwrite, retain) IBOutlet UISlider *speedSlider;

@property (readwrite, retain) NSMutableArray *startTimes;
@property (nonatomic) unsigned long numberOfResults;
@property (retain, nonatomic) NSArray *results;
@property (weak, nonatomic) IBOutlet UILabel *fpsLabel;
@property (readwrite, retain) IBOutlet DaydreamView *daydreamView;
@property (nonatomic, strong) AVCaptureSession *capture;
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *speechRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *task;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioInputNode *speechInputNode;
@property (nonatomic, assign) BOOL speechInputTapInstalled;
@property (nonatomic, assign) NSUInteger speechRecognitionGeneration;
@property (nonatomic, strong) AVSpeechSynthesizer *speechSynthesizer;
@property (nonatomic, strong) AVAudioPlayer *microphoneStartCuePlayer;
@property (nonatomic, strong) AVAudioPlayer *microphoneEndCuePlayer;
@property (nonatomic, assign) BOOL microphoneButtonHeld;
@property (nonatomic, assign) BOOL isSpeaking;
@property (atomic, assign) BOOL safeToStartRecording;

@property (nonatomic, retain) IBOutlet UITableView * languageTableView;
@property (readwrite, retain) IBOutlet RPLidarPolarView *rpLidarPolarView;
@property (readwrite, retain) IBOutlet UIStackView *commandSheetStackView;
@property (nonatomic, retain) IBOutlet UITextView * textView;
@property (atomic, retain) NSString *currentUserVerbalQueryString;
@property (nonatomic, retain) IBOutlet UILabel * locationLabel;
@property (nonatomic, retain) IBOutlet UILabel * rotationLabel;

@property (readwrite, retain) CLLocationManager *locationManager;
@property (readwrite, retain) CMMotionManager *motionManager;
@property (readwrite, retain) CMAttitude *referenceAttitude;
@property (readwrite, assign) float yaw;
@property (readwrite, assign) float pitch;
@property (readwrite, assign) float roll;

@property (nonatomic, strong) UITabBarController *robotTabBarController;
@property (nonatomic, strong) ROBOpenStreetMapView *openStreetMapView;
@property (nonatomic, strong) UIView *persistentControlOverlay;
@property (nonatomic, strong) UILabel *connectionStatusLabel;
@property (nonatomic, strong) UIButton *microphoneButton;
@property (nonatomic, strong) UIView *microphoneGlowView;
@property (nonatomic, strong) UIVisualEffectView *microphoneBlurView;
@property (nonatomic, strong) UIView *iPadCommandDeck;
@property (nonatomic, strong) UIView *iPadNarrativePanel;
@property (nonatomic, strong) UIView *iPadManualPanel;
@property (nonatomic, strong) NSLayoutConstraint *iPadCommandMapHeightConstraint;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *iPadLandscapeCommandConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *iPadPortraitCommandConstraints;
@property (nonatomic, assign) BOOL iPadCommandUsesLandscapeLayout;

@property (readwrite, retain) NSMutableArray *localeArray;
@property (readwrite, assign) int selectedLocaleIndex;

@property(nonatomic, strong) AutoNetClient *autoNetClient;
@property(nonatomic, strong) ROBWatchRelay *watchRelay;
@property(nonatomic, strong) NSTimer *treadControlHeartbeatTimer;
@property(nonatomic, assign) NSTimeInterval lastTreadControlSendUptime;
@property(nonatomic, assign) BOOL lastTreadInputWasActive;
@property(nonatomic, assign) BOOL lastLeftTreadInputWasActive;
@property(nonatomic, assign) BOOL lastRightTreadInputWasActive;
@property(nonatomic, assign) uint64_t treadControlSequence;
@property (readwrite, retain) IBOutlet UIView *chatConnectionStatus;
@property (weak, nonatomic) IBOutlet UIButton *pairControllerButton;
@property (weak, nonatomic) IBOutlet UIButton *autonomyModeButton;
@property (weak, nonatomic) IBOutlet UILabel *autonomyStatusLabel;
@property (nonatomic, strong) NSString *autonomySessionID;
@property (nonatomic, assign) uint64_t autonomySequence;
@property (nonatomic, assign) ROBAutonomySessionState autonomySessionState;
@property (nonatomic, strong) ROBAutonomySessionMessage *pendingAutonomyCommand;
@property (nonatomic, copy) NSString *autonomyStatusDetail;
@property (nonatomic, assign) BOOL autonomyStartRequested;
@property (nonatomic, assign) BOOL autonomyHasAuthorizedDestination;
@property (nonatomic, assign) double autonomyDestinationLatitude;
@property (nonatomic, assign) double autonomyDestinationLongitude;
@property (nonatomic, copy) NSString *autonomyDestinationName;
@property (nonatomic, assign) NSTimeInterval lastOpenStreetMapSearchUptime;
// Gemini may propose a bounded, high-level action, but this controller is only
// an operator approval/status console. These controls never drive hardware.
@property (weak, nonatomic) IBOutlet UIView *robotActionPanel;
@property (weak, nonatomic) IBOutlet UILabel *robotActionSafetyLabel;
@property (weak, nonatomic) IBOutlet UILabel *robotActionTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *robotActionDetailLabel;
@property (weak, nonatomic) IBOutlet UIButton *robotActionsEnabledButton;
@property (weak, nonatomic) IBOutlet UIButton *robotActionApproveButton;
@property (weak, nonatomic) IBOutlet UIButton *robotActionRejectButton;
@property (weak, nonatomic) IBOutlet UIButton *robotActionCompleteButton;
@property (weak, nonatomic) IBOutlet UIButton *robotActionFailedButton;
@property (weak, nonatomic) IBOutlet UIButton *robotActionCancelButton;
@property (nonatomic, strong) ROBRobotActionMessage *currentRobotActionRequest;
@property (nonatomic, assign) ROBRobotActionState currentRobotActionState;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ROBRobotActionMessage *> *robotActionLastStatusByLedgerKey;
@property (nonatomic, strong) NSMutableArray<NSString *> *robotActionStatusLedgerKeyOrder;
@property (nonatomic, strong) NSTimer *robotActionExpiryTimer;
@property (nonatomic, strong) NSTimer *robotActionHelloTimer;
@property (nonatomic, assign) BOOL didAnnounceRobotActionConsole;
@property (nonatomic, assign) BOOL robotActionsEnabled;

- (IBAction)toggleRobotActionsEnabled:(id)sender;
- (IBAction)approveRobotAction:(id)sender;
- (IBAction)rejectRobotAction:(id)sender;
- (IBAction)completeRobotAction:(id)sender;
- (IBAction)failRobotAction:(id)sender;
- (IBAction)cancelRobotAction:(id)sender;
- (IBAction)pairCerebroController:(id)sender;
- (IBAction)toggleAutonomySession:(id)sender;
- (BOOL)sendRobotActionMessage:(ROBRobotActionMessage *)message;
- (void)handleRobotActionMessage:(ROBRobotActionMessage *)message;
- (BOOL)sendAutonomyMessage:(ROBAutonomySessionMessage *)message;
- (void)handleAutonomyMessage:(ROBAutonomySessionMessage *)message;
- (void)retransmitPendingAutonomyCommand;
- (void)refreshAutonomyConsole;
- (void)presentAutonomyModeChoice;
- (void)presentDestinationSearch;
- (void)searchOpenStreetMapForDestination:(NSString *)query;
- (void)startDestinationSessionWithLatitude:(double)latitude
                                  longitude:(double)longitude
                                       name:(NSString *)name;
- (void)refreshRobotActionConsole;
- (void)announceRobotActionConsole;
- (void)setRobotActionsEnabled:(BOOL)enabled reason:(NSString *)reason;
- (ROBRobotActionMessage *)sendRobotActionStatusForRequest:(ROBRobotActionMessage *)request
                                                     state:(ROBRobotActionState)state
                                                    detail:(NSString *)detail
                                                    result:(NSDictionary *)result;
- (void)presentControllerNoticeWithTitle:(NSString *)title message:(NSString *)message;
- (void)beginSpeechRecognitionForGeneration:(NSUInteger)generation;
- (void)stopSpeechRecognition;
- (void)prepareMicrophoneCuePlayers;
- (BOOL)activateSpeechAudioSessionWithMode:(AVAudioSessionMode)mode;
- (void)installTabbedInterface;
- (void)setMicrophoneActiveAppearance:(BOOL)active;
- (void)updateIPadCommandLayoutForSize:(CGSize)size;
- (void)treadInputDidChangeLeft:(CGPoint)left right:(CGPoint)right;
- (void)sendTreadControlSnapshot;
- (void)sendTreadControlSnapshotImmediately;
- (void)refreshTreadControlHeartbeat;

@property (readwrite, assign) IBOutlet UIImageView *rpLidarMapView;
@property (readwrite, retain) RPLidarMapController *rpLidarMapController;

@end

@implementation ConsciousViewController

- (BOOL)usesIPadCommandConsole
{
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIColor *)consoleBackgroundColor
{
    return [UIColor colorWithRed:0.020 green:0.027 blue:0.031 alpha:1.0];
}

- (UIColor *)consoleSurfaceColor
{
    return [UIColor colorWithRed:0.043 green:0.055 blue:0.063 alpha:1.0];
}

- (UIColor *)consoleAmberColor
{
    return [UIColor colorWithRed:0.94 green:0.66 blue:0.25 alpha:1.0];
}

- (void)styleConsolePanel:(UIView *)panel
{
    panel.backgroundColor = [self consoleSurfaceColor];
    panel.layer.cornerRadius = 3.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [[self consoleAmberColor] colorWithAlphaComponent:0.28].CGColor;
}

- (UILabel *)consoleCaptionWithText:(NSString *)text
{
    UILabel *label = [UILabel new];
    label.text = text.uppercaseString;
    label.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightSemibold];
    label.textColor = [self consoleAmberColor];
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    return label;
}

- (UILabel *)sectionLabelWithText:(NSString *)text
{
    UILabel *label = [UILabel new];
    label.text = text;
    if ([self usesIPadCommandConsole]) {
        label.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightSemibold];
        label.textColor = [self consoleAmberColor];
        label.text = text.uppercaseString;
    } else {
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        label.textColor = UIColor.labelColor;
    }
    label.numberOfLines = 0;
    return label;
}

- (UIButton *)controlButtonWithTitle:(NSString *)title
                             selector:(SEL)selector
                               events:(UIControlEvents)events
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.72;
    if ([self usesIPadCommandConsole]) {
        button.titleLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
        button.backgroundColor = [[self consoleAmberColor] colorWithAlphaComponent:0.09];
        button.tintColor = [self consoleAmberColor];
        [button setTitleColor:[self consoleAmberColor] forState:UIControlStateNormal];
        button.layer.cornerRadius = 3.0;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [[self consoleAmberColor] colorWithAlphaComponent:0.36].CGColor;
    } else {
        button.backgroundColor = UIColor.tertiarySystemFillColor;
        button.layer.cornerRadius = 10.0;
    }
    [button addTarget:self action:selector forControlEvents:events];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return button;
}

- (UIStackView *)equalRowWithViews:(NSArray<UIView *> *)views
{
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentFill;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 8;
    return row;
}

- (UIViewController *)tabControllerWithTitle:(NSString *)title systemImage:(NSString *)systemImage
{
    UIViewController *controller = [UIViewController new];
    controller.title = title;
    controller.view.backgroundColor = [self usesIPadCommandConsole] ? [self consoleBackgroundColor] : UIColor.systemBackgroundColor;
    controller.tabBarItem = [[UITabBarItem alloc] initWithTitle:title
                                                          image:[UIImage systemImageNamed:systemImage]
                                                            tag:0];
    return controller;
}

- (UIStackView *)scrollingStackInController:(UIViewController *)controller
{
    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [controller.view addSubview:scrollView];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 12;
    stack.layoutMargins = UIEdgeInsetsMake(14, 16, 22, 16);
    stack.layoutMarginsRelativeArrangement = YES;
    [scrollView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:controller.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor]
    ]];
    return stack;
}

- (UIViewController *)buildMapTab
{
    UIViewController *controller = [self tabControllerWithTitle:@"Map" systemImage:@"map.fill"];
    self.openStreetMapView = [ROBOpenStreetMapView new];
    self.openStreetMapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.openStreetMapView.mapDelegate = self;
    [controller.view addSubview:self.openStreetMapView];

    // RPLidarMapController keeps its legacy UIImageView sink while also
    // forwarding each decoded occupancy image into the geographic map overlay.
    UIImageView *mapImageSink = [UIImageView new];
    mapImageSink.hidden = YES;
    [controller.view addSubview:mapImageSink];
    self.rpLidarMapView = mapImageSink;
    self.rpLidarPolarView = [RPLidarPolarView new];

    [NSLayoutConstraint activateConstraints:@[
        [self.openStreetMapView.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [self.openStreetMapView.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [self.openStreetMapView.topAnchor constraintEqualToAnchor:controller.view.topAnchor],
        [self.openStreetMapView.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor]
    ]];
    return controller;
}

- (UIButton *)momentaryButtonWithTitle:(NSString *)title
                                  down:(SEL)downSelector
                                    up:(SEL)upSelector
{
    UIButton *button = [self controlButtonWithTitle:title
                                           selector:downSelector
                                             events:UIControlEventTouchDown];
    [button addTarget:self
               action:upSelector
     forControlEvents:(UIControlEventTouchUpInside |
                       UIControlEventTouchUpOutside |
                       UIControlEventTouchCancel)];
    return button;
}

- (UIViewController *)buildControlsTab
{
    UIViewController *controller = [self tabControllerWithTitle:@"Controls" systemImage:@"gamecontroller.fill"];
    UIStackView *stack = [self scrollingStackInController:controller];
    [stack addArrangedSubview:[self sectionLabelWithText:@"Tread control"]];

    UILabel *driveHint = [UILabel new];
    driveHint.text = @"Landscape: independent dual joysticks  •  Portrait: one-hand speed + turn";
    driveHint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    driveHint.textColor = UIColor.secondaryLabelColor;
    driveHint.textAlignment = NSTextAlignmentCenter;
    driveHint.numberOfLines = 0;
    [stack addArrangedSubview:driveHint];

    DaydreamView *joystick = [DaydreamView new];
    joystick.translatesAutoresizingMaskIntoConstraints = NO;
    joystick.layer.cornerRadius = 16;
    joystick.layer.borderWidth = 1;
    joystick.layer.borderColor = UIColor.separatorColor.CGColor;
    joystick.backgroundColor = UIColor.secondarySystemBackgroundColor;
    [joystick.heightAnchor constraintEqualToConstant:280].active = YES;
    self.daydreamView = joystick;
    [stack addArrangedSubview:joystick];

    [stack addArrangedSubview:[self sectionLabelWithText:@"Drive speed and direction"]];
    UISlider *speedSlider = [UISlider new];
    speedSlider.minimumValue = 0;
    speedSlider.maximumValue = 100;
    speedSlider.value = self.speed;
    [speedSlider addTarget:self action:@selector(speed_slider_action:) forControlEvents:UIControlEventValueChanged];
    self.speedSlider = speedSlider;

    UIButton *minus = [self controlButtonWithTitle:@"−" selector:@selector(speed_reduce:) events:UIControlEventTouchUpInside];
    UIButton *plus = [self controlButtonWithTitle:@"+" selector:@selector(speed_increase:) events:UIControlEventTouchUpInside];
    UIStackView *speedRow = [[UIStackView alloc] initWithArrangedSubviews:@[minus, speedSlider, plus]];
    speedRow.axis = UILayoutConstraintAxisHorizontal;
    speedRow.alignment = UIStackViewAlignmentCenter;
    speedRow.spacing = 10;
    [minus.widthAnchor constraintEqualToConstant:52].active = YES;
    [plus.widthAnchor constraintEqualToConstant:52].active = YES;
    [stack addArrangedSubview:speedRow];

    [stack addArrangedSubview:[self equalRowWithViews:@[
        [self controlButtonWithTitle:@"Forward" selector:@selector(speed_FORWARD_toggle:) events:UIControlEventTouchUpInside],
        [self controlButtonWithTitle:@"Reverse" selector:@selector(speed_REVERSE_toggle:) events:UIControlEventTouchUpInside],
        [self controlButtonWithTitle:@"Run / Stop" selector:@selector(speed_playpause_action:) events:UIControlEventTouchUpInside],
        [self controlButtonWithTitle:@"Tread Brake" selector:@selector(tred_brakelock:) events:UIControlEventTouchUpInside]
    ]]];

    [stack addArrangedSubview:[self sectionLabelWithText:@"Manual movement"]];
    [stack addArrangedSubview:[self equalRowWithViews:@[
        [self momentaryButtonWithTitle:@"Flipper Forward" down:@selector(flipper_FORWARD_touchdown:) up:@selector(flipper_FORWARD_touchup:)],
        [self momentaryButtonWithTitle:@"Flipper Relax" down:@selector(flipper_RELAX_touchdown:) up:@selector(flipper_RELAX_touchup:)],
        [self momentaryButtonWithTitle:@"Flipper Back" down:@selector(flipper_BACKWARD_touchdown:) up:@selector(flipper_BACKWARD_touchup:)],
        [self controlButtonWithTitle:@"Flipper Brake" selector:@selector(flipper_brakelock:) events:UIControlEventTouchUpInside]
    ]]];
    [stack addArrangedSubview:[self equalRowWithViews:@[
        [self momentaryButtonWithTitle:@"Lift Front" down:@selector(lact_FRONT_touchdown:) up:@selector(lact_FRONT_touchup:)],
        [self controlButtonWithTitle:@"Lift Gravity" selector:@selector(lact_GRAVITY_toggle:) events:UIControlEventTouchUpInside],
        [self momentaryButtonWithTitle:@"Lift Back" down:@selector(lact_BACK_touchdown:) up:@selector(lact_BACK_touchup:)],
        [self controlButtonWithTitle:@"10% Speed" selector:@selector(speed_10Percent:) events:UIControlEventTouchUpInside]
    ]]];
    self.commandSheetStackView = stack;
    return controller;
}

- (UIView *)buildMicrophonePanel
{
    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = UIColor.secondarySystemBackgroundColor;
    panel.layer.cornerRadius = 18;
    [panel.heightAnchor constraintEqualToConstant:190].active = YES;

    UIView *glow = [UIView new];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.78];
    glow.layer.cornerRadius = 76;
    glow.layer.shadowColor = UIColor.systemRedColor.CGColor;
    glow.layer.shadowOffset = CGSizeZero;
    glow.layer.shadowRadius = 30;
    glow.layer.shadowOpacity = 0.95;
    glow.alpha = 0.16;
    [panel addSubview:glow];
    self.microphoneGlowView = glow;

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    blur.userInteractionEnabled = NO;
    blur.layer.cornerRadius = 70;
    blur.layer.masksToBounds = YES;
    blur.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.16];
    blur.alpha = 0.12;
    [panel addSubview:blur];
    self.microphoneBlurView = blur;

    UIButton *microphone = [UIButton buttonWithType:UIButtonTypeSystem];
    microphone.translatesAutoresizingMaskIntoConstraints = NO;
    microphone.accessibilityLabel = @"Hold to speak";
    microphone.backgroundColor = UIColor.systemGray5Color;
    microphone.tintColor = UIColor.labelColor;
    microphone.layer.cornerRadius = 58;
    microphone.layer.borderWidth = 2;
    microphone.layer.borderColor = UIColor.systemRedColor.CGColor;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:52 weight:UIImageSymbolWeightSemibold];
    [microphone setImage:[UIImage systemImageNamed:@"mic.fill" withConfiguration:symbolConfig]
                forState:UIControlStateNormal];
    [microphone addTarget:self action:@selector(microphoneTouchDown:) forControlEvents:UIControlEventTouchDown];
    [microphone addTarget:self
                   action:@selector(microphoneTouchReleased:)
         forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
    [panel addSubview:microphone];
    self.microphoneButton = microphone;

    UILabel *hint = [UILabel new];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.text = @"Hold to speak with ROB's AI";
    hint.textAlignment = NSTextAlignmentCenter;
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    hint.textColor = UIColor.secondaryLabelColor;
    [panel addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [glow.widthAnchor constraintEqualToConstant:152],
        [glow.heightAnchor constraintEqualToConstant:152],
        [glow.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
        [glow.centerYAnchor constraintEqualToAnchor:panel.centerYAnchor constant:-8],
        [blur.widthAnchor constraintEqualToConstant:140],
        [blur.heightAnchor constraintEqualToConstant:140],
        [blur.centerXAnchor constraintEqualToAnchor:glow.centerXAnchor],
        [blur.centerYAnchor constraintEqualToAnchor:glow.centerYAnchor],
        [microphone.widthAnchor constraintEqualToConstant:116],
        [microphone.heightAnchor constraintEqualToConstant:116],
        [microphone.centerXAnchor constraintEqualToAnchor:glow.centerXAnchor],
        [microphone.centerYAnchor constraintEqualToAnchor:glow.centerYAnchor],
        [hint.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
        [hint.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-8]
    ]];
    return panel;
}

- (UIView *)buildRobotActionPanel
{
    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = UIColor.secondarySystemBackgroundColor;
    panel.layer.cornerRadius = 14;
    panel.layoutMargins = UIEdgeInsetsMake(12, 12, 12, 12);

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    [panel addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:panel.layoutMarginsGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:panel.layoutMarginsGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:panel.layoutMarginsGuide.bottomAnchor]
    ]];

    UILabel *safety = [UILabel new];
    safety.text = @"PER-ACTION APPROVAL DOES NOT DIRECTLY ACTUATE HARDWARE";
    safety.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    safety.textColor = UIColor.systemOrangeColor;
    safety.textAlignment = NSTextAlignmentCenter;
    safety.numberOfLines = 0;
    self.robotActionSafetyLabel = safety;
    [stack addArrangedSubview:safety];

    UILabel *title = [self sectionLabelWithText:@"Robot action: No pending request"];
    title.textAlignment = NSTextAlignmentCenter;
    self.robotActionTitleLabel = title;
    [stack addArrangedSubview:title];

    UILabel *detail = [UILabel new];
    detail.text = @"Incoming AI actions require an explicit operator decision.";
    detail.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    detail.textColor = UIColor.secondaryLabelColor;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.numberOfLines = 0;
    self.robotActionDetailLabel = detail;
    [stack addArrangedSubview:detail];

    UIButton *enabled = [self controlButtonWithTitle:@"AI Actions: OFF" selector:@selector(toggleRobotActionsEnabled:) events:UIControlEventTouchUpInside];
    self.robotActionsEnabledButton = enabled;
    [stack addArrangedSubview:enabled];

    UIButton *approve = [self controlButtonWithTitle:@"Approve" selector:@selector(approveRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *reject = [self controlButtonWithTitle:@"Reject" selector:@selector(rejectRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *complete = [self controlButtonWithTitle:@"Complete" selector:@selector(completeRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *failed = [self controlButtonWithTitle:@"Failed" selector:@selector(failRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *cancel = [self controlButtonWithTitle:@"Cancel" selector:@selector(cancelRobotAction:) events:UIControlEventTouchUpInside];
    self.robotActionApproveButton = approve;
    self.robotActionRejectButton = reject;
    self.robotActionCompleteButton = complete;
    self.robotActionFailedButton = failed;
    self.robotActionCancelButton = cancel;
    [stack addArrangedSubview:[self equalRowWithViews:@[approve, reject, cancel]]];
    [stack addArrangedSubview:[self equalRowWithViews:@[complete, failed]]];
    self.robotActionPanel = panel;
    return panel;
}

- (UIViewController *)buildAutoTab
{
    UIViewController *controller = [self tabControllerWithTitle:@"Auto" systemImage:@"brain.head.profile"];
    UIStackView *stack = [self scrollingStackInController:controller];
    UILabel *title = [self sectionLabelWithText:@"AI interaction"];
    title.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:title];
    [stack addArrangedSubview:[self buildMicrophonePanel]];

    UITextView *transcript = [UITextView new];
    transcript.translatesAutoresizingMaskIntoConstraints = NO;
    transcript.editable = NO;
    transcript.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    transcript.textColor = UIColor.labelColor;
    transcript.backgroundColor = UIColor.secondarySystemBackgroundColor;
    transcript.layer.cornerRadius = 12;
    transcript.textAlignment = NSTextAlignmentCenter;
    transcript.text = @"Speech transcript";
    [transcript.heightAnchor constraintEqualToConstant:72].active = YES;
    self.textView = transcript;
    [stack addArrangedSubview:transcript];

    UIButton *shutUp = [self controlButtonWithTitle:@"Stop ROB Speaking" selector:@selector(shutUpDroid) events:UIControlEventTouchUpInside];
    [stack addArrangedSubview:shutUp];

    [stack addArrangedSubview:[self sectionLabelWithText:@"Autonomy"]];
    UILabel *autonomyStatus = [UILabel new];
    autonomyStatus.numberOfLines = 0;
    autonomyStatus.textAlignment = NSTextAlignmentCenter;
    autonomyStatus.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    autonomyStatus.textColor = UIColor.secondaryLabelColor;
    self.autonomyStatusLabel = autonomyStatus;
    [stack addArrangedSubview:autonomyStatus];
    UIButton *autonomyButton = [self controlButtonWithTitle:@"Start Autonomy…" selector:@selector(toggleAutonomySession:) events:UIControlEventTouchUpInside];
    self.autonomyModeButton = autonomyButton;
    [stack addArrangedSubview:autonomyButton];
    [stack addArrangedSubview:[self buildRobotActionPanel]];
    return controller;
}

- (UIView *)buildIPadMicrophoneModule
{
    UIView *module = [UIView new];
    module.translatesAutoresizingMaskIntoConstraints = NO;
    [self styleConsolePanel:module];

    UILabel *caption = [self consoleCaptionWithText:@"Voice link"];
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    caption.textAlignment = NSTextAlignmentCenter;
    [module addSubview:caption];

    UIView *glow = [UIView new];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.76];
    glow.layer.cornerRadius = 50;
    glow.layer.shadowColor = UIColor.systemRedColor.CGColor;
    glow.layer.shadowOffset = CGSizeZero;
    glow.layer.shadowRadius = 26;
    glow.layer.shadowOpacity = 0.92;
    glow.alpha = 0.14;
    [module addSubview:glow];
    self.microphoneGlowView = glow;

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    blur.userInteractionEnabled = NO;
    blur.layer.cornerRadius = 45;
    blur.layer.masksToBounds = YES;
    blur.alpha = 0.10;
    [module addSubview:blur];
    self.microphoneBlurView = blur;

    UIButton *microphone = [UIButton buttonWithType:UIButtonTypeSystem];
    microphone.translatesAutoresizingMaskIntoConstraints = NO;
    microphone.accessibilityLabel = @"Hold to speak with ROB";
    microphone.backgroundColor = [self consoleBackgroundColor];
    microphone.tintColor = UIColor.whiteColor;
    microphone.layer.cornerRadius = 36;
    microphone.layer.borderWidth = 1.5;
    microphone.layer.borderColor = UIColor.systemRedColor.CGColor;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:31 weight:UIImageSymbolWeightMedium];
    [microphone setImage:[UIImage systemImageNamed:@"mic.fill" withConfiguration:symbolConfig]
                forState:UIControlStateNormal];
    [microphone addTarget:self action:@selector(microphoneTouchDown:) forControlEvents:UIControlEventTouchDown];
    [microphone addTarget:self
                   action:@selector(microphoneTouchReleased:)
         forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
    [module addSubview:microphone];
    self.microphoneButton = microphone;

    UILabel *hint = [self consoleCaptionWithText:@"Hold / transmit"];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.62];
    [module addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [caption.leadingAnchor constraintEqualToAnchor:module.leadingAnchor constant:6],
        [caption.trailingAnchor constraintEqualToAnchor:module.trailingAnchor constant:-6],
        [caption.topAnchor constraintEqualToAnchor:module.topAnchor constant:7],
        [glow.widthAnchor constraintEqualToConstant:100],
        [glow.heightAnchor constraintEqualToConstant:100],
        [glow.centerXAnchor constraintEqualToAnchor:module.centerXAnchor],
        [glow.centerYAnchor constraintEqualToAnchor:module.centerYAnchor constant:2],
        [blur.widthAnchor constraintEqualToConstant:90],
        [blur.heightAnchor constraintEqualToConstant:90],
        [blur.centerXAnchor constraintEqualToAnchor:glow.centerXAnchor],
        [blur.centerYAnchor constraintEqualToAnchor:glow.centerYAnchor],
        [microphone.widthAnchor constraintEqualToConstant:72],
        [microphone.heightAnchor constraintEqualToConstant:72],
        [microphone.centerXAnchor constraintEqualToAnchor:glow.centerXAnchor],
        [microphone.centerYAnchor constraintEqualToAnchor:glow.centerYAnchor],
        [hint.leadingAnchor constraintEqualToAnchor:module.leadingAnchor constant:6],
        [hint.trailingAnchor constraintEqualToAnchor:module.trailingAnchor constant:-6],
        [hint.bottomAnchor constraintEqualToAnchor:module.bottomAnchor constant:-7]
    ]];
    return module;
}

- (UIView *)buildIPadNarrativeChannel
{
    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self styleConsolePanel:panel];

    UIStackView *row = [UIStackView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentFill;
    row.spacing = 8;
    row.layoutMargins = UIEdgeInsetsMake(7, 7, 7, 7);
    row.layoutMarginsRelativeArrangement = YES;
    [panel addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:panel.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor]
    ]];

    UIView *microphoneModule = [self buildIPadMicrophoneModule];
    [microphoneModule.widthAnchor constraintEqualToConstant:128].active = YES;
    [row addArrangedSubview:microphoneModule];

    UIStackView *conversation = [UIStackView new];
    conversation.axis = UILayoutConstraintAxisVertical;
    conversation.spacing = 4;
    [conversation.widthAnchor constraintGreaterThanOrEqualToConstant:210].active = YES;
    [row addArrangedSubview:conversation];

    [conversation addArrangedSubview:[self consoleCaptionWithText:@"Narrative channel / ROB"]];
    UITextView *transcript = [UITextView new];
    transcript.translatesAutoresizingMaskIntoConstraints = NO;
    transcript.editable = NO;
    transcript.scrollEnabled = YES;
    transcript.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    transcript.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.88];
    transcript.backgroundColor = [self consoleBackgroundColor];
    transcript.layer.cornerRadius = 2;
    transcript.text = @"Speech transcript / narrative response";
    [transcript.heightAnchor constraintGreaterThanOrEqualToConstant:34].active = YES;
    self.textView = transcript;
    [conversation addArrangedSubview:transcript];

    UILabel *autonomyStatus = [UILabel new];
    autonomyStatus.numberOfLines = 2;
    autonomyStatus.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    autonomyStatus.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.58];
    self.autonomyStatusLabel = autonomyStatus;
    [conversation addArrangedSubview:autonomyStatus];

    UIButton *shutUp = [self controlButtonWithTitle:@"Silence ROB" selector:@selector(shutUpDroid) events:UIControlEventTouchUpInside];
    UIButton *autonomyButton = [self controlButtonWithTitle:@"Begin Autonomy…" selector:@selector(toggleAutonomySession:) events:UIControlEventTouchUpInside];
    self.autonomyModeButton = autonomyButton;
    [conversation addArrangedSubview:[self equalRowWithViews:@[shutUp, autonomyButton]]];

    UIView *actionPanel = [UIView new];
    actionPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self styleConsolePanel:actionPanel];
    [actionPanel.widthAnchor constraintGreaterThanOrEqualToConstant:360].active = YES;
    [row addArrangedSubview:actionPanel];

    UIStackView *actions = [UIStackView new];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = 4;
    actions.layoutMargins = UIEdgeInsetsMake(6, 7, 6, 7);
    actions.layoutMarginsRelativeArrangement = YES;
    [actionPanel addSubview:actions];
    [NSLayoutConstraint activateConstraints:@[
        [actions.leadingAnchor constraintEqualToAnchor:actionPanel.leadingAnchor],
        [actions.trailingAnchor constraintEqualToAnchor:actionPanel.trailingAnchor],
        [actions.topAnchor constraintEqualToAnchor:actionPanel.topAnchor],
        [actions.bottomAnchor constraintEqualToAnchor:actionPanel.bottomAnchor]
    ]];

    UILabel *safety = [self consoleCaptionWithText:@"AI action gate / operator authorization required"];
    safety.textColor = UIColor.systemOrangeColor;
    self.robotActionSafetyLabel = safety;
    [actions addArrangedSubview:safety];

    UILabel *actionTitle = [UILabel new];
    actionTitle.text = @"NO PENDING ACTION";
    actionTitle.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightSemibold];
    actionTitle.textColor = UIColor.whiteColor;
    actionTitle.numberOfLines = 1;
    self.robotActionTitleLabel = actionTitle;
    [actions addArrangedSubview:actionTitle];

    UILabel *detail = [UILabel new];
    detail.text = @"Incoming narrative actions remain inert until explicitly approved.";
    detail.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    detail.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.58];
    detail.numberOfLines = 2;
    self.robotActionDetailLabel = detail;
    [actions addArrangedSubview:detail];

    UIButton *enabled = [self controlButtonWithTitle:@"AI Actions: OFF" selector:@selector(toggleRobotActionsEnabled:) events:UIControlEventTouchUpInside];
    UIButton *approve = [self controlButtonWithTitle:@"Approve" selector:@selector(approveRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *reject = [self controlButtonWithTitle:@"Reject" selector:@selector(rejectRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *cancel = [self controlButtonWithTitle:@"Cancel" selector:@selector(cancelRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *complete = [self controlButtonWithTitle:@"Complete" selector:@selector(completeRobotAction:) events:UIControlEventTouchUpInside];
    UIButton *failed = [self controlButtonWithTitle:@"Failed" selector:@selector(failRobotAction:) events:UIControlEventTouchUpInside];
    self.robotActionsEnabledButton = enabled;
    self.robotActionApproveButton = approve;
    self.robotActionRejectButton = reject;
    self.robotActionCancelButton = cancel;
    self.robotActionCompleteButton = complete;
    self.robotActionFailedButton = failed;
    [actions addArrangedSubview:[self equalRowWithViews:@[enabled, approve, reject, cancel, complete, failed]]];
    self.robotActionPanel = actionPanel;
    return panel;
}

- (UIView *)buildIPadManualControls
{
    UIView *panel = [UIView new];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self styleConsolePanel:panel];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.spacing = 4;
    stack.layoutMargins = UIEdgeInsetsMake(6, 6, 6, 6);
    stack.layoutMarginsRelativeArrangement = YES;
    [panel addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor]
    ]];

    UISlider *speedSlider = [UISlider new];
    speedSlider.minimumValue = 0;
    speedSlider.maximumValue = 100;
    speedSlider.value = self.speed;
    speedSlider.minimumTrackTintColor = [self consoleAmberColor];
    [speedSlider addTarget:self action:@selector(speed_slider_action:) forControlEvents:UIControlEventValueChanged];
    self.speedSlider = speedSlider;
    UILabel *speedCaption = [self consoleCaptionWithText:@"Tread power"];
    [speedCaption.widthAnchor constraintEqualToConstant:82].active = YES;
    UIButton *minus = [self controlButtonWithTitle:@"−" selector:@selector(speed_reduce:) events:UIControlEventTouchUpInside];
    UIButton *plus = [self controlButtonWithTitle:@"+" selector:@selector(speed_increase:) events:UIControlEventTouchUpInside];
    [minus.widthAnchor constraintEqualToConstant:44].active = YES;
    [plus.widthAnchor constraintEqualToConstant:44].active = YES;
    UIStackView *speedRow = [[UIStackView alloc] initWithArrangedSubviews:@[speedCaption, minus, speedSlider, plus]];
    speedRow.axis = UILayoutConstraintAxisHorizontal;
    speedRow.alignment = UIStackViewAlignmentCenter;
    speedRow.spacing = 5;
    [stack addArrangedSubview:speedRow];

    [stack addArrangedSubview:[self equalRowWithViews:@[
        [self controlButtonWithTitle:@"Forward" selector:@selector(speed_FORWARD_toggle:) events:UIControlEventTouchUpInside],
        [self controlButtonWithTitle:@"Reverse" selector:@selector(speed_REVERSE_toggle:) events:UIControlEventTouchUpInside],
        [self controlButtonWithTitle:@"Run / Stop" selector:@selector(speed_playpause_action:) events:UIControlEventTouchUpInside],
        [self controlButtonWithTitle:@"Tread Brake" selector:@selector(tred_brakelock:) events:UIControlEventTouchUpInside]
    ]]];
    [stack addArrangedSubview:[self equalRowWithViews:@[
        [self momentaryButtonWithTitle:@"Flipper +" down:@selector(flipper_FORWARD_touchdown:) up:@selector(flipper_FORWARD_touchup:)],
        [self momentaryButtonWithTitle:@"Flipper Relax" down:@selector(flipper_RELAX_touchdown:) up:@selector(flipper_RELAX_touchup:)],
        [self momentaryButtonWithTitle:@"Flipper −" down:@selector(flipper_BACKWARD_touchdown:) up:@selector(flipper_BACKWARD_touchup:)],
        [self controlButtonWithTitle:@"Flipper Brake" selector:@selector(flipper_brakelock:) events:UIControlEventTouchUpInside]
    ]]];
    [stack addArrangedSubview:[self equalRowWithViews:@[
        [self momentaryButtonWithTitle:@"Lift Front" down:@selector(lact_FRONT_touchdown:) up:@selector(lact_FRONT_touchup:)],
        [self controlButtonWithTitle:@"Lift Gravity" selector:@selector(lact_GRAVITY_toggle:) events:UIControlEventTouchUpInside],
        [self momentaryButtonWithTitle:@"Lift Back" down:@selector(lact_BACK_touchdown:) up:@selector(lact_BACK_touchup:)],
        [self controlButtonWithTitle:@"10% Power" selector:@selector(speed_10Percent:) events:UIControlEventTouchUpInside]
    ]]];
    self.commandSheetStackView = stack;
    return panel;
}

- (UIViewController *)buildIPadCommandTab
{
    UIViewController *controller = [self tabControllerWithTitle:@"Command" systemImage:@"square.grid.2x2.fill"];
    controller.view.backgroundColor = [self consoleBackgroundColor];

    ROBOpenStreetMapView *map = [ROBOpenStreetMapView new];
    map.translatesAutoresizingMaskIntoConstraints = NO;
    map.mapDelegate = self;
    [controller.view addSubview:map];
    self.openStreetMapView = map;

    UIImageView *mapImageSink = [UIImageView new];
    mapImageSink.hidden = YES;
    [controller.view addSubview:mapImageSink];
    self.rpLidarMapView = mapImageSink;
    self.rpLidarPolarView = [RPLidarPolarView new];

    UIView *deck = [UIView new];
    deck.translatesAutoresizingMaskIntoConstraints = NO;
    deck.backgroundColor = [self consoleBackgroundColor];
    [controller.view addSubview:deck];
    self.iPadCommandDeck = deck;

    UIView *narrative = [self buildIPadNarrativeChannel];
    UIView *manual = [self buildIPadManualControls];
    DaydreamView *joystick = [DaydreamView new];
    joystick.translatesAutoresizingMaskIntoConstraints = NO;
    joystick.backgroundColor = UIColor.clearColor;
    joystick.accessibilityLabel = @"Left and right tread joysticks";
    [deck addSubview:narrative];
    [deck addSubview:manual];
    [deck addSubview:joystick];
    self.iPadNarrativePanel = narrative;
    self.iPadManualPanel = manual;
    self.daydreamView = joystick;

    NSLayoutConstraint *mapHeight = [map.heightAnchor constraintEqualToConstant:300];
    self.iPadCommandMapHeightConstraint = mapHeight;
    [NSLayoutConstraint activateConstraints:@[
        [map.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [map.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [map.topAnchor constraintEqualToAnchor:controller.view.topAnchor],
        mapHeight,
        [deck.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [deck.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [deck.topAnchor constraintEqualToAnchor:map.bottomAnchor],
        [deck.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor],
        [narrative.leadingAnchor constraintEqualToAnchor:deck.leadingAnchor constant:10],
        [narrative.trailingAnchor constraintEqualToAnchor:deck.trailingAnchor constant:-10],
        [joystick.leadingAnchor constraintEqualToAnchor:deck.leadingAnchor],
        [joystick.trailingAnchor constraintEqualToAnchor:deck.trailingAnchor]
    ]];

    self.iPadLandscapeCommandConstraints = @[
        [narrative.topAnchor constraintEqualToAnchor:deck.topAnchor constant:8],
        [narrative.heightAnchor constraintEqualToConstant:150],
        [manual.topAnchor constraintEqualToAnchor:narrative.bottomAnchor constant:6],
        [manual.bottomAnchor constraintEqualToAnchor:deck.bottomAnchor constant:-8],
        [manual.centerXAnchor constraintEqualToAnchor:deck.centerXAnchor],
        [manual.widthAnchor constraintLessThanOrEqualToConstant:540],
        [manual.leadingAnchor constraintGreaterThanOrEqualToAnchor:deck.leadingAnchor constant:210],
        [manual.trailingAnchor constraintLessThanOrEqualToAnchor:deck.trailingAnchor constant:-210],
        [joystick.topAnchor constraintEqualToAnchor:narrative.bottomAnchor constant:2],
        [joystick.bottomAnchor constraintEqualToAnchor:deck.bottomAnchor]
    ];
    self.iPadPortraitCommandConstraints = @[
        [narrative.topAnchor constraintEqualToAnchor:deck.topAnchor constant:8],
        [narrative.heightAnchor constraintEqualToConstant:180],
        [manual.topAnchor constraintEqualToAnchor:narrative.bottomAnchor constant:6],
        [manual.leadingAnchor constraintEqualToAnchor:deck.leadingAnchor constant:16],
        [manual.trailingAnchor constraintEqualToAnchor:deck.trailingAnchor constant:-16],
        [manual.heightAnchor constraintEqualToConstant:200],
        [joystick.topAnchor constraintEqualToAnchor:manual.bottomAnchor constant:2],
        [joystick.bottomAnchor constraintEqualToAnchor:deck.bottomAnchor]
    ];
    [NSLayoutConstraint activateConstraints:self.iPadPortraitCommandConstraints];
    self.iPadCommandUsesLandscapeLayout = NO;
    return controller;
}

- (UIViewController *)buildSettingsTab
{
    UIViewController *controller = [self tabControllerWithTitle:@"Settings" systemImage:@"gearshape.fill"];

    UILabel *settingsTitle = [self sectionLabelWithText:@"Controller pairing"];
    settingsTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [controller.view addSubview:settingsTitle];
    UIButton *pair = [self controlButtonWithTitle:@"Pair Cerebro…" selector:@selector(pairCerebroController:) events:UIControlEventTouchUpInside];
    [controller.view addSubview:pair];
    self.pairControllerButton = pair;

    UILabel *languageTitle = [self sectionLabelWithText:@"Speech and output language"];
    languageTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [controller.view addSubview:languageTitle];
    UITableView *languageTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    languageTable.translatesAutoresizingMaskIntoConstraints = NO;
    languageTable.dataSource = self;
    languageTable.delegate = self;
    languageTable.rowHeight = 58;
    languageTable.backgroundColor = [self usesIPadCommandConsole] ? [self consoleBackgroundColor] : UIColor.systemBackgroundColor;
    languageTable.separatorColor = [self usesIPadCommandConsole]
        ? [[self consoleAmberColor] colorWithAlphaComponent:0.22]
        : UIColor.separatorColor;
    self.languageTableView = languageTable;
    [controller.view addSubview:languageTable];

    [NSLayoutConstraint activateConstraints:@[
        [settingsTitle.leadingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.leadingAnchor constant:18],
        [settingsTitle.trailingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.trailingAnchor constant:-18],
        [settingsTitle.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor constant:14],
        [pair.leadingAnchor constraintEqualToAnchor:settingsTitle.leadingAnchor],
        [pair.trailingAnchor constraintEqualToAnchor:settingsTitle.trailingAnchor],
        [pair.topAnchor constraintEqualToAnchor:settingsTitle.bottomAnchor constant:8],
        [languageTitle.leadingAnchor constraintEqualToAnchor:settingsTitle.leadingAnchor],
        [languageTitle.trailingAnchor constraintEqualToAnchor:settingsTitle.trailingAnchor],
        [languageTitle.topAnchor constraintEqualToAnchor:pair.bottomAnchor constant:18],
        [languageTable.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [languageTable.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [languageTable.topAnchor constraintEqualToAnchor:languageTitle.bottomAnchor constant:4],
        [languageTable.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor]
    ]];
    return controller;
}

- (UIView *)buildPersistentOverlay
{
    UIBlurEffectStyle blurStyle = [self usesIPadCommandConsole]
        ? UIBlurEffectStyleSystemChromeMaterialDark
        : UIBlurEffectStyleSystemChromeMaterial;
    UIVisualEffectView *overlay = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    if ([self usesIPadCommandConsole]) {
        overlay.contentView.backgroundColor = [[self consoleBackgroundColor] colorWithAlphaComponent:0.84];
        overlay.layer.borderColor = [[self consoleAmberColor] colorWithAlphaComponent:0.22].CGColor;
        overlay.layer.borderWidth = 1.0;
    }

    UIStackView *content = [UIStackView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 4;
    content.layoutMargins = UIEdgeInsetsMake(6, 10, 6, 10);
    content.layoutMarginsRelativeArrangement = YES;
    [overlay.contentView addSubview:content];

    UIButton *reconnect = [self controlButtonWithTitle:@"Reconnect" selector:@selector(reconnectAutoNet:) events:UIControlEventTouchUpInside];
    reconnect.accessibilityHint = @"Reconnect to the paired Cerebro controller";
    UIView *indicator = [UIView new];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    indicator.backgroundColor = UIColor.systemRedColor;
    indicator.layer.cornerRadius = 7;
    [indicator.widthAnchor constraintEqualToConstant:14].active = YES;
    [indicator.heightAnchor constraintEqualToConstant:14].active = YES;
    self.chatConnectionStatus = indicator;

    UILabel *linkLabel = [UILabel new];
    linkLabel.text = @"Disconnected";
    linkLabel.font = [self usesIPadCommandConsole]
        ? [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightSemibold]
        : [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    linkLabel.textColor = [self usesIPadCommandConsole]
        ? [UIColor.whiteColor colorWithAlphaComponent:0.68]
        : UIColor.secondaryLabelColor;
    self.connectionStatusLabel = linkLabel;
    UIButton *requestControl = [self controlButtonWithTitle:@"Request Control" selector:@selector(RequestToBeMasterControllerAction:) events:UIControlEventTouchUpInside];
    UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[reconnect, indicator, linkLabel, [UIView new], requestControl]];
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.alignment = UIStackViewAlignmentCenter;
    topRow.spacing = 8;
    [content addArrangedSubview:topRow];

    UILabel *position = [UILabel new];
    position.text = @"x:0.00  y:0.00  z:0.00";
    position.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    position.textColor = [self usesIPadCommandConsole] ? [self consoleAmberColor] : UIColor.labelColor;
    position.adjustsFontSizeToFitWidth = YES;
    position.minimumScaleFactor = 0.7;
    self.locationLabel = position;
    UILabel *rotation = [UILabel new];
    rotation.text = @"yaw:0.00  pitch:0.00  roll:0.00";
    rotation.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    rotation.textColor = [self usesIPadCommandConsole] ? [self consoleAmberColor] : UIColor.labelColor;
    rotation.textAlignment = NSTextAlignmentRight;
    rotation.adjustsFontSizeToFitWidth = YES;
    rotation.minimumScaleFactor = 0.7;
    self.rotationLabel = rotation;
    UIStackView *telemetry = [[UIStackView alloc] initWithArrangedSubviews:@[position, rotation]];
    telemetry.axis = UILayoutConstraintAxisHorizontal;
    telemetry.distribution = UIStackViewDistributionFillEqually;
    telemetry.spacing = 12;
    [content addArrangedSubview:telemetry];

    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:overlay.contentView.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:overlay.contentView.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:overlay.contentView.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:overlay.contentView.bottomAnchor]
    ]];
    self.persistentControlOverlay = overlay;
    return overlay;
}

- (void)installTabbedInterface
{
    NSArray<UIView *> *storyboardSubviews = self.view.subviews.copy;
    for (UIView *subview in storyboardSubviews) {
        [subview removeFromSuperview];
    }
    self.controlTrailingSpace = nil;
    self.languageLeadingSpace = nil;
    self.view.backgroundColor = [self usesIPadCommandConsole] ? [self consoleBackgroundColor] : UIColor.systemBackgroundColor;

    UIView *overlay = [self buildPersistentOverlay];
    [self.view addSubview:overlay];

    UITabBarController *tabs = [UITabBarController new];
    if ([self usesIPadCommandConsole]) {
        tabs.viewControllers = @[
            [self buildIPadCommandTab],
            [self buildSettingsTab]
        ];
    } else {
        tabs.viewControllers = @[
            [self buildMapTab],
            [self buildControlsTab],
            [self buildAutoTab],
            [self buildSettingsTab]
        ];
    }
    tabs.selectedIndex = 0;
    tabs.tabBar.translucent = YES;
    if ([self usesIPadCommandConsole]) {
        tabs.tabBar.barStyle = UIBarStyleBlack;
        tabs.tabBar.backgroundColor = [self consoleBackgroundColor];
        tabs.tabBar.tintColor = [self consoleAmberColor];
        tabs.tabBar.unselectedItemTintColor = [UIColor.whiteColor colorWithAlphaComponent:0.45];
        if (@available(iOS 18.0, *)) {
            tabs.mode = UITabBarControllerModeTabBar;
        }
    }
    [self addChildViewController:tabs];
    tabs.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:tabs.view belowSubview:overlay];
    [tabs didMoveToParentViewController:self];
    self.robotTabBarController = tabs;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [overlay.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [overlay.heightAnchor constraintEqualToConstant:82],
        [tabs.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tabs.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tabs.view.topAnchor constraintEqualToAnchor:overlay.bottomAnchor],
        [tabs.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self.view bringSubviewToFront:overlay];
}

- (void)updateIPadCommandLayoutForSize:(CGSize)size
{
    if (![self usesIPadCommandConsole] || self.iPadCommandMapHeightConstraint == nil) {
        return;
    }

    BOOL landscape = size.width > size.height;
    CGFloat requestedMapHeight = landscape ? size.height * 0.34 : size.height * 0.40;
    CGFloat minimumMapHeight = landscape ? 230.0 : 360.0;
    CGFloat maximumMapHeight = landscape ? 420.0 : 560.0;
    self.iPadCommandMapHeightConstraint.constant = MIN(maximumMapHeight, MAX(minimumMapHeight, requestedMapHeight));

    if (landscape == self.iPadCommandUsesLandscapeLayout) {
        return;
    }
    self.daydreamView.leftJoystick = CGPointMake(-999, -999);
    self.daydreamView.rightJoystick = CGPointMake(-999, -999);
    [self treadInputDidChangeLeft:self.daydreamView.leftJoystick
                            right:self.daydreamView.rightJoystick];
    if (landscape) {
        [NSLayoutConstraint deactivateConstraints:self.iPadPortraitCommandConstraints];
        [NSLayoutConstraint activateConstraints:self.iPadLandscapeCommandConstraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:self.iPadLandscapeCommandConstraints];
        [NSLayoutConstraint activateConstraints:self.iPadPortraitCommandConstraints];
    }
    self.iPadCommandUsesLandscapeLayout = landscape;
    [self.daydreamView setNeedsLayout];
    [self.daydreamView setNeedsDisplay];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updateIPadCommandLayoutForSize:self.view.bounds.size];
}

- (void)microphoneTouchDown:(UIButton *)sender
{
    [self setMicrophoneActiveAppearance:YES];
    [self recordButtonTouchDown:sender];
}

- (void)microphoneTouchReleased:(UIButton *)sender
{
    [self setMicrophoneActiveAppearance:NO];
    [self recordButtonTouchUp:sender];
}

- (void)setMicrophoneActiveAppearance:(BOOL)active
{
    [UIView animateWithDuration:0.16 animations:^{
        self.microphoneGlowView.alpha = active ? 1.0 : 0.16;
        self.microphoneBlurView.alpha = active ? 0.72 : 0.12;
        self.microphoneButton.backgroundColor = active ? UIColor.systemRedColor : UIColor.systemGray5Color;
        self.microphoneButton.tintColor = active ? UIColor.whiteColor : UIColor.labelColor;
        self.microphoneButton.transform = active ? CGAffineTransformMakeScale(1.06, 1.06) : CGAffineTransformIdentity;
    }];
    self.microphoneButton.accessibilityValue = active ? @"Listening" : @"Off";
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *newLocation = locations.lastObject;
    // test that the horizontal accuracy does not indicate an invalid measurement
    if (newLocation.horizontalAccuracy < 0) {
        return;
    }
    
    
    // test the age of the location measurement to determine if the measurement is cached
    // in most cases you will not want to rely on cached measurements
    //
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 5.0) {
        return;
    }
    [self.openStreetMapView updateRobotLatitude:newLocation.coordinate.latitude
                                      longitude:newLocation.coordinate.longitude];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    [self prepareMicrophoneCuePlayers];
    // Do any additional setup after loading the view, typically from a nib.
    self.speed = 50;
    self.speedSlider.value = self.speed;
    self.speed_ForwardReverse_toggle = true; //forward is true at first
    
    self.flipper_FORWARD_isDown = false;
    self.flipper_RELAX_isDown = false;
    self.flipper_BACKWARD_isDown = false;
    
    self.lact_BACK_isDown = false;
    self.lact_GRAVITY_toggle = false;
    self.lact_FRONT_isDown = false;

    // Physical-action requests require an explicit opt-in after every launch.
    // Resigning active resets the opt-in and cancels any open request.
    self.robotActionsEnabled = NO;
    self.currentRobotActionState = ROBRobotActionStateNone;
    self.robotActionLastStatusByLedgerKey = [NSMutableDictionary dictionary];
    self.robotActionStatusLedgerKeyOrder = [NSMutableArray array];
    self.didAnnounceRobotActionConsole = NO;
    self.autonomySequence = 0;
    self.autonomySessionState = ROBAutonomySessionStateInactive;
    self.autonomyStatusDetail = @"Inactive — one operator tap starts a bounded social-roam session.";
    self.autonomyStartRequested = NO;
    [self installTabbedInterface];
    __weak ConsciousViewController *weakSelfForTreads = self;
    self.daydreamView.joystickValuesDidChange = ^(CGPoint left, CGPoint right) {
        [weakSelfForTreads treadInputDidChangeLeft:left right:right];
    };
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [self refreshRobotActionConsole];
    [self refreshAutonomyConsole];

    self.rpLidarMapController = [[RPLidarMapController alloc] initWithRpLidarMapView:self.rpLidarMapView];
    __weak ConsciousViewController *weakSelfForMap = self;
    self.rpLidarMapController.onMapImageUpdated = ^(UIImage *image) {
        [weakSelfForMap.openStreetMapView updateOccupancyMapImage:image];
    };
    //---
    //Location Manager code - versy simple
    self.locationManager = [CLLocationManager new];
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.delegate = self;
    
    [self.locationManager requestAlwaysAuthorization];
    [self.locationManager startUpdatingLocation];
    //---
    //Motion Manager
    self.motionManager = [CMMotionManager new];
    self.motionManager.deviceMotionUpdateInterval = (1.0/5.0);
    
    
    
    
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue new] withHandler:^(CMDeviceMotion *data, NSError *mc_error) {
        
        //*******
        //DEBUG TIMER INFO
        
        //ROBOT ONLY LIKES IT WHEN YOU SEND DATA AT ABOUT 10 Hz ---> if you see too many
        //parsing - you are pushing data too fast for the arduino mega to process it
        /*
         ****TOOFAST  60Hz deviceMotionUpdateInterval :
         
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
        target_Motor1_brake_command 0
        TargetCommandString M1:0000,
        target_Motor2_brake_command 0
        TargetCommandString M2:0000,
        target_FlipperMotor_brake_command 0
        TargetCommandString FLipper:0000,
        --------- NEW TARGET Motor Values -----------
        target_Motor1_Command: 0:0
        target_Motor2_Command: 0:0
        target_FlipperMotor_Command: 0:0
        target_LACT_Command: 0
        ---------------------------------------
        M1 BACKWARD
        M2 BACKWARD
        FLIPPER FORWARD
        ---------------------------------------
        Parsing Serial and resetting keepAlive
        Parsing Serial and resetting keepAlive
         
         
         
         
         ****JustRight 10Hz deviceMotionUpdateInterval:
         Parsing Serial and resetting keepAlive
         target_Motor1_brake_command 0
         TargetCommandString M1:+0000
         target_Motor2_brake_command 0
         TargetCommandString M2:+0000
         target_FlipperMotor_brake_command 0
         TargetCommandString FLipper:-0000
         --------- NEW TARGET Motor Values -----------
         target_Motor1_Command: 0:0
         target_Motor2_Command: 0:0
         target_FlipperMotor_Command: 0:0
         target_LACT_Command: 0
         ---------------------------------------
         M1 BACKWARD
         M2 BACKWARD
         FLIPPER FORWARD
         ---------------------------------------
         Parsing Serial and resetting keepAlive
         target_Motor1_brake_command 0
         TargetCommandString M1:+0000
         target_Motor2_brake_command 0
         TargetCommandString M2:+0000
         target_FlipperMotor_brake_command 0
         TargetCommandString FLipper:-0000
         --------- NEW TARGET Motor Values -----------
         target_Motor1_Command: 0:0
         target_Motor2_Command: 0:0
         target_FlipperMotor_Command: 0:0
         target_LACT_Command: 0
         ---------------------------------------
         M1 BACKWARD
         M2 BACKWARD
         FLIPPER FORWARD
         ---------------------------------------
         IMU Pulse
         ax = -88.01 ay = -1.10 az = -999.21 mg
         gx = -0.05 gy = 0.05 gz = -0.08 deg/s
         mx = 569 my = -768 mz = -1162 mG
         q0 = -0.04 qx = 0.79 qy = -0.59 qz = -0.18
         Yaw, Pitch, Roll: -78.93, 19.27, 170.51
         Temperature is 29.5 degrees C
         rate = 0.22 Hz
         Parsing Serial and resetting keepAlive
         target_Motor1_brake_command 0
         TargetCommandString M1:+0000
         target_Motor2_brake_command 0
        */
        
        // perform some action
        
        
        // Find out the Z rotation of the device by doing some trig on the accelerometer values for X and Y
        float Lat = self.locationManager.location.coordinate.latitude;
        float Long = self.locationManager.location.coordinate.longitude;
        if (self.referenceAttitude)
            [data.attitude multiplyByInverseOfAttitude:self.referenceAttitude];
        
        self.yaw = data.attitude.yaw;
        self.pitch = data.attitude.pitch;
        self.roll = data.attitude.roll;
        
        NSString *dataString = [NSString stringWithFormat:
                                @"%0.2f,%0.2f,%0.2f,\n%0.2f,%0.2f,%0.2f,\n%0.2f,%0.2f,%0.2f,\nyaw=%f\npitch=%f\nroll=%f\ntouchPadL - %f,%f\ntouchPadR - %f,%f\n(Lat,Long):%f:%f\ntredBrakeLock=%i\nflipper=%i,%i,%i,%i\nlact=%i,%i,%i\nspeed=%f,play=%i,forward-reverse=%i\nTEXT=%@",
                                data.attitude.rotationMatrix.m11, data.attitude.rotationMatrix.m12, data.attitude.rotationMatrix.m13,
                                data.attitude.rotationMatrix.m21, data.attitude.rotationMatrix.m22, data.attitude.rotationMatrix.m23,
                                data.attitude.rotationMatrix.m31, data.attitude.rotationMatrix.m32, data.attitude.rotationMatrix.m33,
                                data.attitude.yaw, data.attitude.pitch, data.attitude.roll,
                                
                                self.daydreamView.leftJoystick.x, self.daydreamView.leftJoystick.y,
                                self.daydreamView.rightJoystick.x, self.daydreamView.rightJoystick.y,
                                Lat, Long,
                                self.tred_BRAKELOCK,
                                self.flipper_FORWARD_isDown, self.flipper_RELAX_isDown, self.flipper_BACKWARD_isDown, self.flipper_BRAKELOCK,
                                self.lact_BACK_isDown, self.lact_GRAVITY_toggle, self.lact_FRONT_isDown,
                                self.speed, self.speed_PlayPause_toggle, self.speed_ForwardReverse_toggle, self.currentUserVerbalQueryString];
        NSDictionary *messageDict = @{@"message":dataString, @"sender":[[[UIDevice currentDevice] identifierForVendor] UUIDString]};
        NSError *error = nil;
        [self.autoNetClient sendWithData:[NSKeyedArchiver archivedDataWithRootObject:messageDict requiringSecureCoding:false error:&error]];
        if (error != nil) {
            NSLog(@"Error %@", [error localizedDescription]);
        }
        
    }];
    //MCBus Setup
    if (self.autoNetClient == nil)
        self.autoNetClient = [[AutoNetClient alloc] initWithService:AutoNetClient.defaultService];
    self.autoNetClient.dataDelegate = self;
    [self.autoNetClient start];
    self.watchRelay = [[ROBWatchRelay alloc] initWithAutoNetClient:self.autoNetClient];
    __weak ConsciousViewController *weakSelfForHello = self;
    self.robotActionHelloTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        [weakSelfForHello announceRobotActionConsole];
        [weakSelfForHello retransmitPendingAutonomyCommand];
        [weakSelfForHello refreshAutonomyConsole];
    }];
    [self refreshAutonomyConsole];
    //Aurora Setup audio tap conflicts with speech audio tap...???
    // how to merge the 2 audio captures to be used together? DTS Ticket material

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(systemVolumeDidChange:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    
    self.safeToStartRecording = true;
    [self speechAudioInit];
    [self.languageTableView reloadData];
}

- (BOOL)treadPointIsActive:(CGPoint)point
{
    return isfinite(point.x) && isfinite(point.y) && point.x > -999.0 && point.y > -999.0;
}

- (BOOL)hasActiveTreadDemand
{
    return [self treadPointIsActive:self.daydreamView.leftJoystick]
        || [self treadPointIsActive:self.daydreamView.rightJoystick]
        || self.speed_PlayPause_toggle;
}

- (void)treadInputDidChangeLeft:(CGPoint)left right:(CGPoint)right
{
    BOOL active = [self treadPointIsActive:left] || [self treadPointIsActive:right]
        || self.speed_PlayPause_toggle;
    BOOL leftActive = [self treadPointIsActive:left];
    BOOL rightActive = [self treadPointIsActive:right];
    BOOL isBeginOrEndEdge = active != self.lastTreadInputWasActive
        || leftActive != self.lastLeftTreadInputWasActive
        || rightActive != self.lastRightTreadInputWasActive;
    NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime
        - self.lastTreadControlSendUptime;

    if (isBeginOrEndEdge || elapsed >= 0.09) {
        [self sendTreadControlSnapshot];
    }
    [self refreshTreadControlHeartbeat];
}

- (void)refreshTreadControlHeartbeat
{
    if (![self hasActiveTreadDemand]) {
        [self.treadControlHeartbeatTimer invalidate];
        self.treadControlHeartbeatTimer = nil;
        return;
    }
    if (self.treadControlHeartbeatTimer != nil) {
        return;
    }

    __weak ConsciousViewController *weakSelf = self;
    self.treadControlHeartbeatTimer = [NSTimer timerWithTimeInterval:0.05
                                                            repeats:YES
                                                              block:^(NSTimer *timer) {
        ConsciousViewController *strongSelf = weakSelf;
        if (strongSelf == nil || ![strongSelf hasActiveTreadDemand]) {
            [timer invalidate];
            strongSelf.treadControlHeartbeatTimer = nil;
            return;
        }
        NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime
            - strongSelf.lastTreadControlSendUptime;
        if (elapsed >= 0.09) {
            [strongSelf sendTreadControlSnapshot];
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.treadControlHeartbeatTimer
                              forMode:NSRunLoopCommonModes];
}

- (void)sendTreadControlSnapshotImmediately
{
    [self sendTreadControlSnapshot];
    [self refreshTreadControlHeartbeat];
}

- (void)sendTreadControlSnapshot
{
    CGPoint left = self.daydreamView.leftJoystick;
    CGPoint right = self.daydreamView.rightJoystick;
    BOOL leftActive = [self treadPointIsActive:left];
    BOOL rightActive = [self treadPointIsActive:right];
    BOOL active = leftActive || rightActive || self.speed_PlayPause_toggle;
    self.lastTreadInputWasActive = active;
    self.lastLeftTreadInputWasActive = leftActive;
    self.lastRightTreadInputWasActive = rightActive;
    self.lastTreadControlSendUptime = NSProcessInfo.processInfo.systemUptime;
    self.treadControlSequence += 1;

    NSString *senderID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (senderID.length == 0 || self.autoNetClient == nil) {
        return;
    }
    uint64_t sentAtMilliseconds = (uint64_t)MAX(
        0,
        floor(NSDate.date.timeIntervalSince1970 * 1000.0)
    );
    NSDictionary *message = @{
        @"message": @"ROBControllerTreadSnapshotV1",
        @"sender": senderID,
        @"controller.tread.version": @"1",
        @"controller.tread.sequence": [NSString stringWithFormat:@"%llu", self.treadControlSequence],
        @"controller.tread.sent_at_ms": [NSString stringWithFormat:@"%llu", sentAtMilliseconds],
        @"controller.tread.left.active": leftActive ? @"1" : @"0",
        @"controller.tread.left.x": [NSString stringWithFormat:@"%.5f", leftActive ? left.x : 0.0],
        @"controller.tread.left.y": [NSString stringWithFormat:@"%.5f", leftActive ? left.y : 0.0],
        @"controller.tread.right.active": rightActive ? @"1" : @"0",
        @"controller.tread.right.x": [NSString stringWithFormat:@"%.5f", rightActive ? right.x : 0.0],
        @"controller.tread.right.y": [NSString stringWithFormat:@"%.5f", rightActive ? right.y : 0.0],
        @"controller.tread.speed": [NSString stringWithFormat:@"%.2f", self.speed],
        @"controller.tread.brake_lock": self.tred_BRAKELOCK ? @"1" : @"0",
        @"controller.tread.play": self.speed_PlayPause_toggle ? @"1" : @"0",
        @"controller.tread.forward": self.speed_ForwardReverse_toggle ? @"1" : @"0"
    };
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:message
                                         requiringSecureCoding:NO
                                                         error:&error];
    if (data == nil || error != nil) {
        NSLog(@"Unable to encode prioritized tread snapshot: %@", error.localizedDescription);
        return;
    }
    [self.autoNetClient sendControlWithData:data];
}

- (void) systemVolumeDidChange:(NSNotification *)notification {
    NSLog(@"systemVolumeDidChange = %@", notification.userInfo);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.isSpeaking)
        [self.speechRequest appendAudioSampleBuffer:sampleBuffer];
}


- (void) speechAudioInit
{
    self.localeArray = @[
                         //English
                         @{@"locale_id":@"en-US",@"locale_string":@"English (United States)"},
                         @{@"locale_id":@"en-ZA",@"locale_string":@"English (SouthAfrica)"},
                         @{@"locale_id":@"en-PH",@"locale_string":@"English (Republic of the Philippines)"},
                         @{@"locale_id":@"en-CA",@"locale_string":@"English (Canadian)"},
                         @{@"locale_id":@"en-SG",@"locale_string":@"English (Singapore)"},
                         @{@"locale_id":@"en-IN",@"locale_string":@"English (India)"},
                         @{@"locale_id":@"en-NZ",@"locale_string":@"English (New Zealand)"},
                         @{@"locale_id":@"en-GB",@"locale_string":@"English (British)"},
                         @{@"locale_id":@"en-ID",@"locale_string":@"English (Indonesia)"},
                         @{@"locale_id":@"en-AE",@"locale_string":@"English (Australia)"},
                         @{@"locale_id":@"en-AU",@"locale_string":@"English (Australia)"},
                         @{@"locale_id":@"en-IE",@"locale_string":@"English (Ireland"},
                         @{@"locale_id":@"en-SA",@"locale_string":@"English (?)"},
                         //Spanish
                         @{@"locale_id":@"es-MX",@"locale_string":@"Mexican Spanish"},
                         @{@"locale_id":@"es-CL",@"locale_string":@"Chilean Spanish"},
                         @{@"locale_id":@"ca-ES",@"locale_string":@"Catalan Spain"},
                         @{@"locale_id":@"es-ES",@"locale_string":@"Castilian Spanish"},
                         @{@"locale_id":@"es-CO",@"locale_string":@"Colombian Spanish"},
                         @{@"locale_id":@"es-US",@"locale_string":@"United States - Spanish"},
                         //French
                         @{@"locale_id":@"fr-FR",@"locale_string":@"French"},
                         @{@"locale_id":@"fr-CH",@"locale_string":@"French (Switzerland)"},
                         @{@"locale_id":@"fr-CA",@"locale_string":@"French (Canada)"},
                         @{@"locale_id":@"fr-BE",@"locale_string":@"French (Belgium)"},
                         //Chinese
                         @{@"locale_id":@"zh-HK",@"locale_string":@"Chinese (Hong Kong)"},
                         @{@"locale_id":@"zh-CN",@"locale_string":@"Chinese (Mainland China)"},
                         @{@"locale_id":@"zh-TW",@"locale_string":@"Chinese (Taiwanese Mandarin)"},
                         @{@"locale_id":@"yue-CN",@"locale_string":@"Chinese (?)"},
                         //Portugese
                         @{@"locale_id":@"pt-BR",@"locale_string":@"Portuguese (Brazilian)"},
                         @{@"locale_id":@"pt-PT",@"locale_string":@"Portuguese (European)"},
                         //German
                         @{@"locale_id":@"de-DE",@"locale_string":@"German"},
                         @{@"locale_id":@"de-CH",@"locale_string":@"German (Switzerland)"},
                         //Dutch
                         @{@"locale_id":@"nl-NL",@"locale_string":@"Dutch"},
                         @{@"locale_id":@"nl-BE",@"locale_string":@"Dutch (Belgium"},
                         //Danish
                         @{@"locale_id":@"da-DK",@"locale_string":@"Danish (Denmark)"},
                         @{@"locale_id":@"de-AT",@"locale_string":@"Danish (?)"},
                         //Italian
                         @{@"locale_id":@"it-IT",@"locale_string":@"Italian"},
                         @{@"locale_id":@"it-CH",@"locale_string":@"Italian (Switzerland)"},
                         
                         //Single Locale ID Languages:
                         @{@"locale_id":@"vi-VN",@"locale_string":@"Vietnamese"},
                         
                         @{@"locale_id":@"ko-KR",@"locale_string":@"Korean"},
                         
                         @{@"locale_id":@"ro-RO",@"locale_string":@"Romanian"},
                         
                         @{@"locale_id":@"sv-SE",@"locale_string":@"Swedish (Sweden"},
                         
                         @{@"locale_id":@"ar-SA",@"locale_string":@"Arabic (Saudi Arabia)"},
                         
                         @{@"locale_id":@"hu-HU",@"locale_string":@"Hungarian"},
                         
                         @{@"locale_id":@"ja-JP",@"locale_string":@"Japanese"},
                         
                         @{@"locale_id":@"fi-FI",@"locale_string":@"Finnish (Finland)"},
                         
                         @{@"locale_id":@"tr-TR",@"locale_string":@"Turkish"},
                         
                         @{@"locale_id":@"nb-NO",@"locale_string":@"Norwegian (Bokmål) - Norway"},
                         
                         @{@"locale_id":@"pl-PL",@"locale_string":@"Polish"},
                         
                         @{@"locale_id":@"id-ID",@"locale_string":@"Indonesian"},
                         
                         @{@"locale_id":@"ms-MY",@"locale_string":@"Malaysia (Malay)"},
                         
                         @{@"locale_id":@"el-GR",@"locale_string":@"Greek"},
                         
                         @{@"locale_id":@"cs-CZ",@"locale_string":@"Czech (Czech Republic)"},
                         
                         @{@"locale_id":@"hr-HR",@"locale_string":@"Croatian"},
                         
                         @{@"locale_id":@"he-IL",@"locale_string":@"Hebrew (Israel)"},
                         
                         @{@"locale_id":@"ru-RU",@"locale_string":@"Russian"},
                         
                         @{@"locale_id":@"th-TH",@"locale_string":@"Thai"},
                         
                         @{@"locale_id":@"sk-SK",@"locale_string":@"Slovak (Slovakia"},
                         
                         @{@"locale_id":@"uk-UA",@"locale_string":@"Ukrainian (Ukraine)"}
                         ].mutableCopy;
    self.selectedLocaleIndex = 0;
    
}

- (IBAction)recordButtonTouchDown:(id)sender {
    if (!self.safeToStartRecording) {
        return;
    }
    self.safeToStartRecording = false;
    self.microphoneButtonHeld = YES;
    [self activateSpeechAudioSessionWithMode:AVAudioSessionModeDefault];
    [self.microphoneStartCuePlayer stop];
    self.microphoneStartCuePlayer.currentTime = 0;
    if (![self.microphoneStartCuePlayer play]) {
        [self setupSpeechRecognition];
    }
}

- (IBAction)recordButtonTouchUp:(id)sender {
    self.microphoneButtonHeld = NO;
    [self.microphoneStartCuePlayer stop];
    self.microphoneStartCuePlayer.currentTime = 0;
    self.speechRecognitionGeneration += 1;
    [self stopSpeechRecognition];
    self.safeToStartRecording = true;
    [self activateSpeechAudioSessionWithMode:AVAudioSessionModeDefault];
    [self.microphoneEndCuePlayer stop];
    self.microphoneEndCuePlayer.currentTime = 0;
    [self.microphoneEndCuePlayer play];
}

- (void)prepareMicrophoneCuePlayers
{
    NSError *startError = nil;
    NSURL *startURL = [[NSBundle mainBundle] URLForResource:@"nextel_ptt_start" withExtension:@"caf"];
    if (startURL != nil) {
        self.microphoneStartCuePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:startURL error:&startError];
        self.microphoneStartCuePlayer.delegate = self;
        self.microphoneStartCuePlayer.volume = 0.82;
        [self.microphoneStartCuePlayer prepareToPlay];
    }
    if (self.microphoneStartCuePlayer == nil) {
        NSLog(@"Unable to prepare the Motorola microphone start cue: %@", startError.localizedDescription);
    }

    NSError *endError = nil;
    NSURL *endURL = [[NSBundle mainBundle] URLForResource:@"motorola_ptt_end" withExtension:@"caf"];
    if (endURL != nil) {
        self.microphoneEndCuePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:endURL error:&endError];
        self.microphoneEndCuePlayer.delegate = self;
        self.microphoneEndCuePlayer.volume = 0.76;
        [self.microphoneEndCuePlayer prepareToPlay];
    }
    if (self.microphoneEndCuePlayer == nil) {
        NSLog(@"Unable to prepare the Motorola microphone end cue: %@", endError.localizedDescription);
    }
}

- (BOOL)activateSpeechAudioSessionWithMode:(AVAudioSessionMode)mode
{
    NSError *sessionError = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL configured = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                                           mode:mode
                                        options:AVAudioSessionCategoryOptionDefaultToSpeaker
                                          error:&sessionError];
    if (configured) {
        configured = [audioSession setActive:YES error:&sessionError];
    }
    if (!configured) {
        NSLog(@"Unable to activate the microphone audio session: %@", sessionError.localizedDescription);
    }
    return configured;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (player == self.microphoneStartCuePlayer && self.microphoneButtonHeld) {
        [self setupSpeechRecognition];
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"Unable to play a microphone cue: %@", error.localizedDescription);
    if (player == self.microphoneStartCuePlayer && self.microphoneButtonHeld) {
        [self setupSpeechRecognition];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) openCommandSheetMenu {
    self.controlTrailingSpace.constant = -self.commandSheetStackView.frame.size.width;
}

- (void) closeCommandSheetMenu {
    self.controlTrailingSpace.constant = 0;
}

- (void) openMenu
{
    self.languageLeadingSpace.constant = -self.languageTableView.frame.size.width;
}

- (void) closeMenu
{
    self.languageLeadingSpace.constant = 0;
}

- (IBAction) controllerAction:(id)sender {
    
    NSLog(@"Toggle Controller Menu Action");
    if (!self.isAnimatingControllerMenu)
    {
        self.isAnimatingControllerMenu = true;
        if (self.controlTrailingSpace.constant == 0)
        {
            [UIView animateWithDuration:0.0 animations:^(){
                [self openCommandSheetMenu];
            } completion:^(bool Finished){
                self.isAnimatingControllerMenu = false;
            }];
        }
        else
        {
            [UIView animateWithDuration:0.0 animations:^(){
                [self closeCommandSheetMenu];
            } completion:^(bool Finished){
                self.isAnimatingControllerMenu = false;
            }];
        }
    }

}


- (IBAction) languageAction:(id)sender
{
    NSLog(@"Select Language Action");
    if (!self.isAnimating)
    {
        self.isAnimating = true;
        if (self.languageLeadingSpace.constant == 0)
        {
            [UIView animateWithDuration:0.0 animations:^(){
                [self openMenu];
            } completion:^(bool Finished){
                self.isAnimating = false;
            }];
        }
        else
        {
            [UIView animateWithDuration:0.0 animations:^(){
                [self closeMenu];
            } completion:^(bool Finished){
                self.isAnimating = false;
            }];
        }
    }

}


- (void) setupSpeechRecognition
{
    self.isSpeaking = NO;
    self.speechRecognitionGeneration += 1;
    [self stopSpeechRecognition];

    if (![self activateSpeechAudioSessionWithMode:AVAudioSessionModeMeasurement]) {
        self.safeToStartRecording = true;
        return;
    }

    self.audioEngine = [[AVAudioEngine alloc] init];
    self.speechSynthesizer  = [[AVSpeechSynthesizer alloc] init];
    [self.speechSynthesizer setDelegate:self];
    [self startRecognizer];
}


- (void)startRecognizer
{
    NSString *locale = [self.localeArray[self.selectedLocaleIndex] valueForKey:@"locale_id"];
    NSUInteger generation = self.speechRecognitionGeneration;

    NSLog(@"starting speech recognizer with Locale - %@", locale);
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:locale]];
    self.speechRecognizer.delegate = self;
    if (self.speechRecognizer == nil) {
        NSLog(@"Unable to create a speech recognizer for Locale - %@", locale);
        self.safeToStartRecording = true;
        return;
    }

    __weak ConsciousViewController *weakSelf = self;
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ConsciousViewController *strongSelf = weakSelf;
            if (strongSelf == nil || generation != strongSelf.speechRecognitionGeneration) {
                return;
            }
            if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
                NSLog(@"Speech recognition authorization was not granted (status %ld)", (long)status);
                strongSelf.safeToStartRecording = true;
                return;
            }
            [strongSelf beginSpeechRecognitionForGeneration:generation];
        });
    }];
}

- (void)beginSpeechRecognitionForGeneration:(NSUInteger)generation
{
    if (generation != self.speechRecognitionGeneration) {
        return;
    }

    AVAudioEngine *audioEngine = self.audioEngine;
    if (audioEngine == nil) {
        NSLog(@"Unable to start speech recognition without an audio engine");
        self.safeToStartRecording = true;
        return;
    }

    SFSpeechAudioBufferRecognitionRequest *speechRequest = [SFSpeechAudioBufferRecognitionRequest new];
    if (speechRequest == nil) {
        NSLog(@"Unable to create a speech audio buffer recognition request");
        self.safeToStartRecording = true;
        return;
    }
    speechRequest.shouldReportPartialResults = YES;
    self.speechRequest = speechRequest;

    @try {
        AVAudioInputNode *inputNode = audioEngine.inputNode;
        if (inputNode == nil) {
            NSLog(@"Speech recognition is unavailable because no audio input node exists");
            [self stopSpeechRecognition];
            self.safeToStartRecording = true;
            return;
        }

        AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
        if (recordingFormat.sampleRate <= 0 || recordingFormat.channelCount == 0) {
            NSLog(@"Speech recognition is unavailable because the audio input format is invalid: %@", recordingFormat);
            [self stopSpeechRecognition];
            self.safeToStartRecording = true;
            return;
        }

        __weak ConsciousViewController *weakSelf = self;
        self.task = [self.speechRecognizer recognitionTaskWithRequest:speechRequest resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {
            BOOL isFinal = result.isFinal;
            if (result != nil) {
                NSString *transcription = result.bestTranscription.formattedString;
                dispatch_async(dispatch_get_main_queue(), ^{
                    ConsciousViewController *strongSelf = weakSelf;
                    if (strongSelf == nil || strongSelf.speechRequest != speechRequest) {
                        return;
                    }
                    strongSelf.currentUserVerbalQueryString = transcription;
                    strongSelf.textView.text = transcription;
                    [strongSelf positionTextView];
                });
            }

            if (error != nil || isFinal) {
                if (error != nil) {
                    NSLog(@"Speech recognition error: %@", error.localizedDescription);
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    ConsciousViewController *strongSelf = weakSelf;
                    if (strongSelf != nil && strongSelf.speechRequest == speechRequest) {
                        [strongSelf stopSpeechRecognition];
                        strongSelf.safeToStartRecording = true;
                    }
                });
            }
        }];
        if (self.task == nil) {
            NSLog(@"Unable to create a speech recognition task");
            [self stopSpeechRecognition];
            self.safeToStartRecording = true;
            return;
        }

        [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
            [speechRequest appendAudioPCMBuffer:buffer];
        }];
        self.speechInputNode = inputNode;
        self.speechInputTapInstalled = YES;

        [audioEngine prepare];
        NSError *startError = nil;
        if (![audioEngine startAndReturnError:&startError]) {
            NSLog(@"Unable to start the speech audio engine: %@", startError.localizedDescription);
            [self stopSpeechRecognition];
            self.safeToStartRecording = true;
            return;
        }

        NSLog(@"Recording has started...");
        [self positionTextView];
    } @catch (NSException *exception) {
        NSLog(@"Unable to start speech recognition audio: %@ (%@)", exception.reason, exception.name);
        [self stopSpeechRecognition];
        self.safeToStartRecording = true;
    }
}

- (void)stopSpeechRecognition
{
    SFSpeechRecognitionTask *task = self.task;
    SFSpeechAudioBufferRecognitionRequest *speechRequest = self.speechRequest;
    AVAudioEngine *audioEngine = self.audioEngine;
    AVAudioInputNode *inputNode = self.speechInputNode;
    BOOL tapInstalled = self.speechInputTapInstalled;

    self.task = nil;
    self.speechRequest = nil;
    self.speechInputNode = nil;
    self.speechInputTapInstalled = NO;

    [task cancel];
    [speechRequest endAudio];
    @try {
        [audioEngine stop];
    } @catch (NSException *exception) {
        NSLog(@"Unable to stop the speech audio engine: %@ (%@)", exception.reason, exception.name);
    }
    if (tapInstalled && inputNode != nil) {
        @try {
            [inputNode removeTapOnBus:0];
        } @catch (NSException *exception) {
            NSLog(@"Unable to remove the speech audio tap: %@ (%@)", exception.reason, exception.name);
        }
    }
}

- (void)endRecognizer
{
    // END capture and END voice Reco
    // or Apple will terminate this task after 30000ms.
    [self endCapture];
    [self.speechRequest endAudio];
}

- (void)startCapture
{
    NSError *error;
    self.capture = [[AVCaptureSession alloc] init];
    AVCaptureDevice *audioDev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (audioDev == nil){
        NSLog(@"Couldn't create audio capture device");
        return ;
    }
    
    // create mic device
    AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDev error:&error];
    if (error != nil){
        NSLog(@"Couldn't create audio input");
        return ;
    }
    
    // add mic device in capture object
    if ([self.capture canAddInput:audioIn] == NO){
        NSLog(@"Couldn't add audio input");
        return ;
    }
    [self.capture addInput:audioIn];
    // export audio data
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    if ([self.capture canAddOutput:audioOutput] == NO){
        NSLog(@"Couldn't add audio output");
        return ;
    }
    [self.capture addOutput:audioOutput];
    [audioOutput connectionWithMediaType:AVMediaTypeAudio];
    [self.capture startRunning];
}


- (void)endCapture
{
    if (self.capture != nil && [self.capture isRunning]){
        [self.capture stopRunning];
    }
}


// Called when the task first detects speech in the source audio
- (void)speechRecognitionDidDetectSpeech:(SFSpeechRecognitionTask *)task
{
    NSLog(@"didDetectSpeech - %@", task);
}



- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)result {
    
    NSLog(@"speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition");
    NSString * translatedString = [[[result bestTranscription] formattedString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSLog(@"%@",translatedString);
    
    self.currentUserVerbalQueryString = translatedString;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.textView.text = translatedString;
        [self positionTextView];
    });
    
    if ([result isFinal]) {
        [self stopSpeechRecognition];
        self.safeToStartRecording = true;
    }
}


- (void)positionTextView {
    if (self.textView.text.length == 0) {
        return;
    }
    // scroll to the bottom of the content
    NSRange lastLine = NSMakeRange(self.textView.text.length - 1, 1);
    [self.textView scrollRangeToVisible:lastLine];
}


// Called for all recognitions, including non-final hypothesis
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didHypothesizeTranscription:(SFTranscription *)transcription
{
    NSString * translatedString = [transcription formattedString];
    NSLog(@"didHypothesizeTranscription - %@", translatedString);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentUserVerbalQueryString = translatedString;
        self.textView.text = translatedString;
        [self positionTextView];
    });
    
    [self.speechSynthesizer speakUtterance:[AVSpeechUtterance speechUtteranceWithString:translatedString]];
    
}


#pragma mark - SFSpeechRecognizerDelegate


- (void) speechRecognizer:(SFSpeechRecognizer *)sf availabilityDidChange:(BOOL)available
{
    if (available)
    {
        NSLog(@"recognizer is available");
    }
    else{
        NSLog(@"recognizer is not available");
    }
}


#pragma mark - AVSpeechSynthesizer delegate


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"didStartSpeechUtterance");
}


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"didFinishSpeechUtterance");
    self.isSpeaking = false;
}


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didPauseSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"didPauseSpeechUtterance");
}


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didContinueSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"didContinueSpeechUtterance");
}


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"didCancelSpeechUtterance");
}


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer willSpeakRangeOfSpeechString:(NSRange)characterRange utterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"willSpeakRangeOfSpeechString");
    NSLog(@"Speaking!");
}


#pragma mark -

- (IBAction) shutUpDroid {
    NSDictionary *messageDict = @{@"message": [NSString stringWithFormat:@"ShutUp"],
                                  @"sender":[[[UIDevice currentDevice] identifierForVendor] UUIDString]};
    NSError *error = nil;
    [self.autoNetClient sendWithData:[NSKeyedArchiver archivedDataWithRootObject:messageDict requiringSecureCoding:false error:&error]];
    if (error != nil) {
        NSLog(@"Error %@", [error localizedDescription]);
    }

}

- (void) chooseOutputLanguageAction:(NSString *)outputLanguage {
    NSDictionary *messageDict = @{@"message": [NSString stringWithFormat:@"SetOutputLanguage:%@", outputLanguage],
                                  @"sender":[[[UIDevice currentDevice] identifierForVendor] UUIDString]};
    NSError *error = nil;
    [self.autoNetClient sendWithData:[NSKeyedArchiver archivedDataWithRootObject:messageDict requiringSecureCoding:false error:&error]];
    if (error != nil) {
        NSLog(@"Error %@", [error localizedDescription]);
    }
}

- (IBAction) RequestToBeMasterControllerAction:(id) sender {
    NSDictionary *messageDict = @{@"message": @"RequestToBeMasterController",
                                  @"sender":[[[UIDevice currentDevice] identifierForVendor] UUIDString]};
    NSError *error = nil;
    [self.autoNetClient sendWithData:[NSKeyedArchiver archivedDataWithRootObject:messageDict requiringSecureCoding:false error:&error]];
    if (error != nil) {
        NSLog(@"Error %@", [error localizedDescription]);
    }
}

#pragma mark - Pairing and controller-authorized autonomy

- (void)presentControllerNoticeWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)pairCerebroController:(id)sender
{
    if (self.autonomySessionID.length > 0 || self.autonomyStartRequested ||
        self.autonomySessionState == ROBAutonomySessionStateActive ||
        self.autonomySessionState == ROBAutonomySessionStateStopping) {
        [self presentControllerNoticeWithTitle:@"Stop autonomy first"
                                       message:@"Pairing cannot be replaced while an autonomy session may still be active."];
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Pair with Cerebro"
                         message:@"Paste the complete ROBCTL2 pairing code shown by Cerebro. The code is stored in this device's Keychain and is never logged."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"ROBCTL2:…";
        textField.secureTextEntry = YES;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    __weak ConsciousViewController *weakSelf = self;
    __weak UITextField *weakPairingCodeField = alert.textFields.firstObject;
    [alert addAction:[UIAlertAction actionWithTitle:@"Pair"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        ConsciousViewController *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        NSString *pairingCode = [weakPairingCodeField.text
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (pairingCode.length == 0) {
            [strongSelf presentControllerNoticeWithTitle:@"Pairing code required"
                                                  message:@"Copy the complete ROBCTL2 code from Cerebro and try again."];
            return;
        }

        NSError *pairingError = nil;
        BOOL installed = [strongSelf.autoNetClient installPairingCode:pairingCode
                                                                 error:&pairingError];
        [strongSelf refreshAutonomyConsole];
        if (!installed) {
            [strongSelf presentControllerNoticeWithTitle:@"Pairing failed"
                                                  message:(pairingError.localizedDescription ?: @"The pairing code was rejected.")];
            return;
        }

        strongSelf.didAnnounceRobotActionConsole = NO;
        [strongSelf presentControllerNoticeWithTitle:@"Pairing stored"
                                              message:@"ROBController will connect only to the paired Cerebro v2 service."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)sendAutonomyMessage:(ROBAutonomySessionMessage *)message
{
    if (message == nil || self.autoNetClient == nil || !self.autoNetClient.isConnected) {
        return NO;
    }
    NSData *archive = [ROBAutonomySessionWireCodec archiveMessage:message
                                                     legacySender:[self robotActionSenderID]];
    if (archive == nil) {
        NSLog(@"Unable to encode autonomy session message %@", message.messageID);
        return NO;
    }
    [self.autoNetClient sendWithData:archive];
    return YES;
}

- (void)startSocialRoamSession
{
    if (!self.autoNetClient.isPairingConfigured) {
        [self presentControllerNoticeWithTitle:@"Pair Cerebro first"
                                       message:@"Install the ROBCTL2 pairing code before authorizing autonomy."];
        return;
    }
    if (!self.autoNetClient.isConnected) {
        [self presentControllerNoticeWithTitle:@"Cerebro is not connected"
                                       message:@"Reconnect to the authenticated v2 service, then start autonomy."];
        return;
    }

    self.autonomyHasAuthorizedDestination = NO;
    self.autonomyDestinationName = nil;
    self.autonomySessionID = [NSUUID UUID].UUIDString;
    self.autonomySequence = 1;
    self.autonomyStartRequested = YES;
    self.autonomySessionState = ROBAutonomySessionStateInactive;
    self.autonomyStatusDetail = @"Start sent — waiting for Cerebro to acknowledge the bounded social-roam session.";
    self.pendingAutonomyCommand = [ROBAutonomySessionMessage
        startWithSessionID:self.autonomySessionID
                  sequence:self.autonomySequence
                  senderID:[self robotActionSenderID]
               recipientID:nil
                   profile:ROBAutonomyProfileSocialRoam
          zoneRadiusMeters:5.0
         maximumSpeedScale:0.20
                 behaviors:@[@"talk", @"look_at_person", @"idle_gesture", @"roam", @"stop_motion"]
                 expiresAt:[NSDate dateWithTimeIntervalSinceNow:8.0 * 60.0 * 60.0]];
    BOOL sent = [self sendAutonomyMessage:self.pendingAutonomyCommand];
    if (!sent) {
        self.autonomyStatusDetail = @"Start queued — waiting for the authenticated Cerebro link.";
    }
    [self refreshAutonomyConsole];
}

- (void)presentAutonomyModeChoice
{
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Start Autonomy"
                         message:@"Choose a bounded mode. Destination navigation is an early nearby-route pilot and will remain stopped until ROB has learned enough terrain from manual driving."
                  preferredStyle:UIAlertControllerStyleAlert];
    __weak ConsciousViewController *weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Navigate to Destination"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf presentDestinationSearch];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Social Roam"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        [weakSelf startSocialRoamSession];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentDestinationSearch
{
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"OpenStreetMap Destination"
                         message:@"Search once for a nearby path destination. Cerebro will reject routes longer than 50 m. Before starting, physically point ROB along the first path segment; fresh depth and RPLidar remain mandatory."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Place, path, or address";
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    __weak ConsciousViewController *weakSelf = self;
    __weak UITextField *weakSearchField = alert.textFields.firstObject;
    [alert addAction:[UIAlertAction actionWithTitle:@"Search"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        NSString *query = [weakSearchField.text
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (query.length == 0) {
            [weakSelf presentControllerNoticeWithTitle:@"Destination required"
                                               message:@"Enter a place or address to search OpenStreetMap."];
            return;
        }
        [weakSelf searchOpenStreetMapForDestination:query];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openStreetMapViewDidRequestSearch:(ROBOpenStreetMapView *)mapView
{
    [self presentDestinationSearch];
}

- (void)openStreetMapView:(ROBOpenStreetMapView *)mapView
didSelectDestinationLatitude:(double)latitude
                longitude:(double)longitude
{
    CLLocation *robotLocation = self.locationManager.location;
    CLLocation *destination = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    CLLocationDistance distance = robotLocation != nil
        ? [destination distanceFromLocation:robotLocation]
        : -1;
    NSString *coordinateName = [NSString stringWithFormat:@"%.6f, %.6f", latitude, longitude];
    NSString *distanceDetail = distance >= 0
        ? [NSString stringWithFormat:@"This point is approximately %.0f m from ROB's reported location. Cerebro enforces its own 50 m route limit.", distance]
        : @"Cerebro will validate this point against its 50 m route limit.";
    UIAlertController *confirmation = [UIAlertController
        alertControllerWithTitle:@"Navigate to this point?"
                         message:distanceDetail
                  preferredStyle:UIAlertControllerStyleAlert];
    [confirmation addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil]];
    __weak ConsciousViewController *weakSelf = self;
    [confirmation addAction:[UIAlertAction actionWithTitle:@"Authorize Navigation"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
        [weakSelf startDestinationSessionWithLatitude:latitude
                                            longitude:longitude
                                                 name:coordinateName];
    }]];
    [self presentViewController:confirmation animated:YES completion:nil];
}

- (void)searchOpenStreetMapForDestination:(NSString *)query
{
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (now - self.lastOpenStreetMapSearchUptime < 1.0) {
        [self presentControllerNoticeWithTitle:@"Please wait"
                                       message:@"OpenStreetMap search is limited to one submitted request per second."];
        return;
    }
    self.lastOpenStreetMapSearchUptime = now;
    NSString *endpoint = [[NSUserDefaults standardUserDefaults] stringForKey:@"ROBNominatimEndpoint"];
    if (endpoint.length == 0) {
        endpoint = @"https://nominatim.openstreetmap.org/search";
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:endpoint];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"q" value:query],
        [NSURLQueryItem queryItemWithName:@"format" value:@"jsonv2"],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"5"]
    ];
    if (components.URL == nil) {
        [self presentControllerNoticeWithTitle:@"Search unavailable"
                                       message:@"The configured OpenStreetMap search endpoint is invalid."];
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:12];
    [request setValue:@"ROBController/2 (destination selection; https://orbitusrobotics.com)"
   forHTTPHeaderField:@"User-Agent"];
    [request setValue:NSLocale.preferredLanguages.firstObject ?: @"en"
   forHTTPHeaderField:@"Accept-Language"];

    __weak ConsciousViewController *weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ConsciousViewController *strongSelf = weakSelf;
            NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class]
                ? (NSHTTPURLResponse *)response : nil;
            if (strongSelf == nil) { return; }
            if (error != nil || http.statusCode < 200 || http.statusCode > 299 || data.length > 500000) {
                [strongSelf presentControllerNoticeWithTitle:@"OpenStreetMap search failed"
                                                     message:error.localizedDescription ?: @"The search service did not return a usable response."];
                return;
            }
            id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![decoded isKindOfClass:NSArray.class] || [(NSArray *)decoded count] == 0) {
                [strongSelf presentControllerNoticeWithTitle:@"No destinations found"
                                                     message:@"Try a more specific OpenStreetMap search."];
                return;
            }
            UIAlertController *chooser = [UIAlertController
                alertControllerWithTitle:@"Choose Destination"
                                 message:@"OpenStreetMap search results. Route data © OpenStreetMap contributors."
                          preferredStyle:UIAlertControllerStyleAlert];
            NSUInteger count = MIN((NSUInteger)3, [(NSArray *)decoded count]);
            for (NSUInteger index = 0; index < count; index++) {
                NSDictionary *place = [(NSArray *)decoded objectAtIndex:index];
                NSString *name = [place[@"display_name"] isKindOfClass:NSString.class]
                    ? place[@"display_name"] : @"Unnamed destination";
                double latitude = [place[@"lat"] doubleValue];
                double longitude = [place[@"lon"] doubleValue];
                if (!isfinite(latitude) || !isfinite(longitude) || fabs(latitude) > 90 || fabs(longitude) > 180) {
                    continue;
                }
                NSString *shortName = name.length > 80
                    ? [[name substringToIndex:77] stringByAppendingString:@"…"] : name;
                [chooser addAction:[UIAlertAction actionWithTitle:shortName
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                    [strongSelf.openStreetMapView showDestinationWithLatitude:latitude
                                                                    longitude:longitude
                                                                        title:name];
                    [strongSelf startDestinationSessionWithLatitude:latitude
                                                          longitude:longitude
                                                               name:name];
                }]];
            }
            [chooser addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil]];
            [strongSelf presentViewController:chooser animated:YES completion:nil];
        });
    }] resume];
}

- (void)startDestinationSessionWithLatitude:(double)latitude
                                  longitude:(double)longitude
                                       name:(NSString *)name
{
    if (!self.autoNetClient.isPairingConfigured || !self.autoNetClient.isConnected) {
        [self presentControllerNoticeWithTitle:@"Cerebro is not ready"
                                       message:@"Pair and reconnect to Cerebro before authorizing navigation."];
        return;
    }
    self.autonomyHasAuthorizedDestination = YES;
    self.autonomyDestinationLatitude = latitude;
    self.autonomyDestinationLongitude = longitude;
    self.autonomyDestinationName = name;
    self.autonomySessionID = NSUUID.UUID.UUIDString;
    self.autonomySequence = 1;
    self.autonomyStartRequested = YES;
    self.autonomySessionState = ROBAutonomySessionStateInactive;
    self.autonomyStatusDetail = [NSString stringWithFormat:
        @"Navigation sent for %@ — point ROB down the first path segment; Cerebro will stop until routing, learned terrain, depth, and RPLidar are all ready.", name];
    self.pendingAutonomyCommand = [ROBAutonomySessionMessage
        startNavigationWithSessionID:self.autonomySessionID
                            sequence:self.autonomySequence
                            senderID:[self robotActionSenderID]
                         recipientID:nil
                    zoneRadiusMeters:50.0
                   maximumSpeedScale:0.14
                           behaviors:@[@"roam", @"navigate_destination", @"use_learned_traversability", @"stop_motion"]
                 destinationLatitude:latitude
                destinationLongitude:longitude
                     destinationName:name
                           expiresAt:[NSDate dateWithTimeIntervalSinceNow:2.0 * 60.0 * 60.0]];
    if (![self sendAutonomyMessage:self.pendingAutonomyCommand]) {
        self.autonomyStatusDetail = @"Navigation queued — waiting for the authenticated Cerebro link.";
    }
    [self refreshAutonomyConsole];
}

- (void)stopAutonomySession
{
    if (self.autonomySessionID.length == 0) {
        return;
    }

    self.autonomySequence += 1;
    self.autonomyStartRequested = NO;
    self.autonomySessionState = ROBAutonomySessionStateStopping;
    self.pendingAutonomyCommand = [ROBAutonomySessionMessage
        stopWithSessionID:self.autonomySessionID
                 sequence:self.autonomySequence
                 senderID:[self robotActionSenderID]
              recipientID:nil
                   reason:@"Operator pressed Stop Autonomy in ROBController"];
    BOOL sent = [self sendAutonomyMessage:self.pendingAutonomyCommand];
    self.autonomyStatusDetail = sent
        ? @"STOP sent — waiting for Cerebro to confirm that the session is inactive."
        : @"STOP queued — it will be sent as soon as the authenticated Cerebro link reconnects.";
    [self refreshAutonomyConsole];
}

- (IBAction)toggleAutonomySession:(id)sender
{
    if (self.autonomyStartRequested || self.autonomySessionState == ROBAutonomySessionStateActive) {
        [self stopAutonomySession];
        return;
    }
    if (self.autonomySessionState == ROBAutonomySessionStateStopping) {
        // A second tap is harmless and immediately retries the same immutable
        // stop command; it never creates a second autonomy session.
        [self sendAutonomyMessage:self.pendingAutonomyCommand];
        return;
    }
    [self presentAutonomyModeChoice];
}

- (void)retransmitPendingAutonomyCommand
{
    if (self.pendingAutonomyCommand == nil) {
        return;
    }
    [self sendAutonomyMessage:self.pendingAutonomyCommand];
}

- (BOOL)autonomyMessageIsAddressedToThisController:(ROBAutonomySessionMessage *)message
{
    return message.recipientID.length == 0 ||
        [message.recipientID isEqualToString:[self robotActionSenderID]];
}

- (void)handleAutonomyMessage:(ROBAutonomySessionMessage *)message
{
    NSAssert([NSThread isMainThread], @"Autonomy state must be updated on the main thread");
    if (message.kind != ROBAutonomySessionMessageKindStatus ||
        ![self autonomyMessageIsAddressedToThisController:message]) {
        return;
    }

    // An addressed active status after an app restart restores the session ID
    // and sequence so the operator can still issue a valid immediate Stop.
    if (self.autonomySessionID.length > 0 &&
        ![self.autonomySessionID isEqualToString:message.sessionID]) {
        return;
    }
    if (self.pendingAutonomyCommand != nil &&
        [self.pendingAutonomyCommand.sessionID isEqualToString:message.sessionID] &&
        message.sequence < self.pendingAutonomyCommand.sequence) {
        return;
    }
    if (self.autonomyHasAuthorizedDestination &&
        (!message.hasDestination ||
         fabs(message.destinationLatitude - self.autonomyDestinationLatitude) > 0.0000001 ||
         fabs(message.destinationLongitude - self.autonomyDestinationLongitude) > 0.0000001)) {
        NSLog(@"Ignoring autonomy status whose destination does not match operator authorization");
        return;
    }
    if (!self.autonomyHasAuthorizedDestination && self.autonomySessionID.length > 0 && message.hasDestination) {
        NSLog(@"Ignoring autonomy status that adds an unauthorized destination");
        return;
    }
    if (!self.autonomyHasAuthorizedDestination && self.autonomySessionID.length == 0 && message.hasDestination) {
        // A paired Cerebro status after an app restart is accepted only so the
        // operator regains an immediate Stop control for the active session.
        self.autonomyHasAuthorizedDestination = YES;
        self.autonomyDestinationLatitude = message.destinationLatitude;
        self.autonomyDestinationLongitude = message.destinationLongitude;
        self.autonomyDestinationName = message.destinationName;
    }

    self.autonomySessionID = message.sessionID;
    self.autonomySequence = MAX(self.autonomySequence, message.sequence);
    self.autonomySessionState = message.state;
    self.autonomyStatusDetail = message.detail.length > 0
        ? message.detail
        : @"Cerebro published an autonomy status update.";

    if (self.pendingAutonomyCommand != nil &&
        [self.pendingAutonomyCommand.sessionID isEqualToString:message.sessionID] &&
        message.sequence >= self.pendingAutonomyCommand.sequence) {
        self.pendingAutonomyCommand = nil;
    }

    switch (message.state) {
        case ROBAutonomySessionStateActive:
            self.autonomyStartRequested = YES;
            break;
        case ROBAutonomySessionStateStopping:
            self.autonomyStartRequested = NO;
            break;
        case ROBAutonomySessionStateInactive:
        case ROBAutonomySessionStateUnavailable:
            self.autonomyStartRequested = NO;
            self.pendingAutonomyCommand = nil;
            self.autonomySessionID = nil;
            self.autonomyHasAuthorizedDestination = NO;
            self.autonomyDestinationName = nil;
            break;
    }
    [self refreshAutonomyConsole];
}

- (void)refreshAutonomyConsole
{
    BOOL pairingConfigured = self.autoNetClient.isPairingConfigured;
    BOOL connected = self.autoNetClient.isConnected;
    self.chatConnectionStatus.backgroundColor = connected ? UIColor.systemGreenColor : UIColor.systemRedColor;
    self.connectionStatusLabel.text = connected
        ? @"Connected"
        : (pairingConfigured ? @"Disconnected" : @"Not paired");
    self.connectionStatusLabel.textColor = connected ? UIColor.systemGreenColor : UIColor.systemRedColor;
    BOOL sessionMayBeActive = self.autonomySessionID.length > 0 || self.autonomyStartRequested ||
        self.autonomySessionState == ROBAutonomySessionStateActive ||
        self.autonomySessionState == ROBAutonomySessionStateStopping;

    NSString *pairTitle = pairingConfigured
        ? (connected ? @"Pair: Connected" : @"Pair: Stored")
        : @"Pair Cerebro…";
    [self.pairControllerButton setTitle:pairTitle forState:UIControlStateNormal];
    self.pairControllerButton.enabled = !sessionMayBeActive;

    NSString *stateName = @"INACTIVE";
    NSString *buttonTitle = @"Start Autonomy…";
    if (self.autonomySessionState == ROBAutonomySessionStateStopping) {
        stateName = @"STOPPING";
        buttonTitle = @"Retry Stop";
    } else if (self.autonomySessionState == ROBAutonomySessionStateActive) {
        stateName = @"ACTIVE";
        buttonTitle = @"Stop Autonomy";
    } else if (self.autonomyStartRequested) {
        stateName = @"START REQUESTED";
        buttonTitle = @"Stop Autonomy";
    } else if (self.autonomySessionState == ROBAutonomySessionStateUnavailable) {
        stateName = @"UNAVAILABLE";
    }
    [self.autonomyModeButton setTitle:buttonTitle forState:UIControlStateNormal];
    self.autonomyModeButton.enabled = sessionMayBeActive || (pairingConfigured && connected);

    NSString *transportState = connected
        ? @"authenticated link connected"
        : (pairingConfigured ? @"pairing stored; link disconnected" : @"not paired");
    self.autonomyStatusLabel.text = [NSString stringWithFormat:@"Autonomy %@ — %@ (%@)",
                                     stateName,
                                     self.autonomyStatusDetail ?: @"No status received.",
                                     transportState];
}

#pragma mark - Gemini robot-action approval console

- (NSString *)robotActionSenderID
{
    NSString *identifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return identifier.length > 0 ? identifier : @"ROBController";
}

- (BOOL)sendRobotActionMessage:(ROBRobotActionMessage *)message
{
    if (message == nil || self.autoNetClient == nil || !self.autoNetClient.isConnected) {
        return NO;
    }
    NSData *archive = [ROBRobotActionWireCodec archiveMessage:message
                                                legacySender:[self robotActionSenderID]];
    if (archive == nil) {
        NSLog(@"Unable to encode robot-action message %@", message.messageID);
        return NO;
    }
    [self.autoNetClient sendWithData:archive];
    return YES;
}

- (void)announceRobotActionConsole
{
    ROBRobotActionMessage *hello = [ROBRobotActionMessage
                                    controllerHelloWithSenderID:[self robotActionSenderID]
                                    acceptsActions:self.robotActionsEnabled
                                    capabilities:@[
                                        @"look_at",
                                        @"play_gesture",
                                        @"request_pick",
                                        @"navigate_relative",
                                        @"stop_motion"
                                    ]];
    self.didAnnounceRobotActionConsole = [self sendRobotActionMessage:hello];
}

- (NSString *)robotActionLedgerKeyForPeerID:(NSString *)peerID callID:(NSString *)callID
{
    if (peerID.length == 0 || callID.length == 0) {
        return nil;
    }
    // A length prefix makes the compound key unambiguous without restricting
    // otherwise valid protocol identifiers.
    return [NSString stringWithFormat:@"%lu:%@%@",
            (unsigned long)peerID.length, peerID, callID];
}

- (NSString *)boundedRobotActionDetail:(NSString *)detail
{
    static NSUInteger const kMaximumDetailLength = 2048;
    if (detail.length <= kMaximumDetailLength) {
        return detail;
    }

    NSRange prefixRange = [detail rangeOfComposedCharacterSequencesForRange:
        NSMakeRange(0, kMaximumDetailLength)];
    if (NSMaxRange(prefixRange) > kMaximumDetailLength) {
        NSRange crossingSequence = [detail rangeOfComposedCharacterSequenceAtIndex:
            kMaximumDetailLength - 1];
        prefixRange.length = crossingSequence.location;
    }
    return [detail substringWithRange:prefixRange];
}

- (void)rememberRobotActionStatus:(ROBRobotActionMessage *)status
{
    NSString *ledgerKey = [self robotActionLedgerKeyForPeerID:status.recipientID
                                                      callID:status.callID];
    if (ledgerKey == nil) {
        return;
    }

    if (self.robotActionLastStatusByLedgerKey[ledgerKey] == nil) {
        // Keep a bounded FIFO replay/tombstone ledger. Preserve the currently
        // displayed call while evicting an older inactive entry when possible.
        while (self.robotActionStatusLedgerKeyOrder.count >= 128) {
            NSString *currentLedgerKey = [self
                robotActionLedgerKeyForPeerID:self.currentRobotActionRequest.senderID
                                       callID:self.currentRobotActionRequest.callID];
            NSUInteger evictionIndex = [self.robotActionStatusLedgerKeyOrder indexOfObjectPassingTest:
                ^BOOL(NSString *candidate, NSUInteger index, BOOL *stop) {
                    return ![candidate isEqualToString:currentLedgerKey];
                }];
            if (evictionIndex == NSNotFound) {
                break;
            }
            NSString *evictedLedgerKey = self.robotActionStatusLedgerKeyOrder[evictionIndex];
            [self.robotActionStatusLedgerKeyOrder removeObjectAtIndex:evictionIndex];
            [self.robotActionLastStatusByLedgerKey removeObjectForKey:evictedLedgerKey];
        }
        [self.robotActionStatusLedgerKeyOrder addObject:ledgerKey];
    }
    self.robotActionLastStatusByLedgerKey[ledgerKey] = status;
}

- (ROBRobotActionMessage *)sendRobotActionStatusForRequest:(ROBRobotActionMessage *)request
                                                     state:(ROBRobotActionState)state
                                                    detail:(NSString *)detail
                                                    result:(NSDictionary *)result
{
    if (request.callID.length == 0) {
        return nil;
    }
    NSString *boundedDetail = [self boundedRobotActionDetail:detail];
    ROBRobotActionMessage *status = [ROBRobotActionMessage
                                     actionStatusWithCallID:request.callID
                                     state:state
                                     detail:boundedDetail
                                     result:(result != nil ? result : @{})
                                     senderID:[self robotActionSenderID]
                                     recipientID:request.senderID];
    [self rememberRobotActionStatus:status];
    [self sendRobotActionMessage:status];
    return status;
}

- (NSString *)displayNameForRobotActionState:(ROBRobotActionState)state
{
    switch (state) {
        case ROBRobotActionStatePending: return @"PENDING";
        case ROBRobotActionStateAccepted: return @"APPROVED — MANUAL ACTION";
        case ROBRobotActionStateExecuting: return @"MANUAL ACTION IN PROGRESS";
        case ROBRobotActionStateCompleted: return @"COMPLETED";
        case ROBRobotActionStateRejected: return @"REJECTED";
        case ROBRobotActionStateCancelled: return @"CANCELLED";
        case ROBRobotActionStateFailed: return @"FAILED";
        case ROBRobotActionStateExpired: return @"EXPIRED";
        case ROBRobotActionStateNone: return @"IDLE";
    }
}

- (NSString *)summaryForRobotActionArguments:(NSDictionary *)arguments
{
    if (arguments.count == 0) {
        return @"{}";
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:arguments
                                                       options:NSJSONWritingSortedKeys
                                                         error:nil];
    NSString *summary = jsonData == nil ? arguments.description :
        [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (summary.length > 240) {
        summary = [[summary substringToIndex:240] stringByAppendingString:@"…"];
    }
    return summary;
}

- (void)refreshRobotActionConsole
{
    self.robotActionSafetyLabel.text = @"PER-ACTION BUTTONS DO NOT ACTUATE — AUTONOMY IS A SEPARATE BOUNDED SESSION";
    [self.robotActionsEnabledButton setTitle:(self.robotActionsEnabled ? @"AI Actions: On" : @"AI Actions: Off")
                                    forState:UIControlStateNormal];

    BOOL pending = self.robotActionsEnabled && self.currentRobotActionState == ROBRobotActionStatePending;
    BOOL accepted = self.robotActionsEnabled &&
        (self.currentRobotActionState == ROBRobotActionStateAccepted ||
         self.currentRobotActionState == ROBRobotActionStateExecuting);
    self.robotActionApproveButton.enabled = pending;
    self.robotActionRejectButton.enabled = pending;
    self.robotActionCompleteButton.enabled = accepted;
    self.robotActionFailedButton.enabled = accepted;
    self.robotActionCancelButton.enabled = pending || accepted;

    ROBRobotActionMessage *request = self.currentRobotActionRequest;
    if (request == nil) {
        self.robotActionTitleLabel.text = self.robotActionsEnabled ?
            @"AI Action: Waiting for request" : @"AI Action: Disabled (operator opt-in required)";
        self.robotActionDetailLabel.text = @"No pending action. Legacy manual controls and the tread heartbeat are unchanged.";
        return;
    }

    NSString *action = request.action.length > 0 ? request.action : @"unknown action";
    self.robotActionTitleLabel.text = [NSString stringWithFormat:@"AI Action: %@ — %@",
                                       action,
                                       [self displayNameForRobotActionState:self.currentRobotActionState]];
    NSString *ledgerKey = [self robotActionLedgerKeyForPeerID:request.senderID
                                                       callID:request.callID];
    ROBRobotActionMessage *latestStatus = self.robotActionLastStatusByLedgerKey[ledgerKey];
    NSString *detail = latestStatus.detail.length > 0 ? latestStatus.detail : @"Awaiting operator decision.";
    self.robotActionDetailLabel.text = [NSString stringWithFormat:@"%@  Arguments: %@",
                                        detail,
                                        [self summaryForRobotActionArguments:request.arguments]];
}

- (void)scheduleExpiryForRobotActionRequest:(ROBRobotActionMessage *)request
{
    [self.robotActionExpiryTimer invalidate];
    self.robotActionExpiryTimer = nil;

    NSTimeInterval nowMilliseconds = [[NSDate date] timeIntervalSince1970] * 1000.0;
    NSTimeInterval delay = ((NSTimeInterval)request.expiresAtMilliseconds - nowMilliseconds) / 1000.0;
    if (delay <= 0.0) {
        self.currentRobotActionState = ROBRobotActionStateExpired;
        [self sendRobotActionStatusForRequest:request
                                       state:ROBRobotActionStateExpired
                                      detail:@"Approval deadline expired before operator approval."
                                      result:@{}];
        [self refreshRobotActionConsole];
        return;
    }

    __weak ConsciousViewController *weakSelf = self;
    self.robotActionExpiryTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer) {
        ConsciousViewController *strongSelf = weakSelf;
        if (strongSelf == nil ||
            strongSelf.currentRobotActionState != ROBRobotActionStatePending ||
            ![strongSelf.currentRobotActionRequest.callID isEqualToString:request.callID] ||
            ![strongSelf.currentRobotActionRequest.senderID isEqualToString:request.senderID]) {
            return;
        }
        strongSelf.currentRobotActionState = ROBRobotActionStateExpired;
        [strongSelf sendRobotActionStatusForRequest:request
                                              state:ROBRobotActionStateExpired
                                             detail:@"Approval deadline expired before operator approval."
                                             result:@{}];
        [strongSelf refreshRobotActionConsole];
    }];
}

- (void)setRobotActionsEnabled:(BOOL)enabled reason:(NSString *)reason
{
    self.robotActionsEnabled = enabled;
    if (!enabled && self.currentRobotActionState == ROBRobotActionStatePending) {
        [self.robotActionExpiryTimer invalidate];
        self.robotActionExpiryTimer = nil;
        self.currentRobotActionState = ROBRobotActionStateCancelled;
        [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                       state:ROBRobotActionStateCancelled
                                      detail:(reason.length > 0 ? reason : @"Operator disabled AI actions.")
                                      result:@{}];
    } else if (!enabled &&
               (self.currentRobotActionState == ROBRobotActionStateAccepted ||
                self.currentRobotActionState == ROBRobotActionStateExecuting)) {
        // Losing the foreground console or disabling proposals is not proof
        // that a manually initiated physical action stopped. Keep the call
        // nonterminal until the operator confirms Complete, Failed, or Cancel.
        NSString *context = reason.length > 0 ? reason : @"Operator disabled AI actions.";
        NSString *detail = [NSString stringWithFormat:
            @"%@ Physical stop/hold is unconfirmed; re-enable the console and report a terminal outcome.",
            context];
        [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                        state:self.currentRobotActionState
                                       detail:detail
                                       result:@{}];
    }
    self.didAnnounceRobotActionConsole = NO;
    [self refreshRobotActionConsole];
    if (self.autoNetClient.isConnected) {
        [self announceRobotActionConsole];
    }
}

- (IBAction)toggleRobotActionsEnabled:(id)sender
{
    if (self.robotActionsEnabled) {
        [self setRobotActionsEnabled:NO
                              reason:@"Operator disabled AI actions"];
    } else {
        [self setRobotActionsEnabled:YES reason:nil];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    // The older per-action approval console is foreground-only. A separately
    // authorized autonomy session continues on Cerebro until Stop, expiry,
    // manual takeover, or a local robot fault; backgrounding this UI does not
    // silently revoke or orphan that server-side session.
    [self setRobotActionsEnabled:NO
                          reason:@"Controller resigned active; AI actions reset to Off"];
    [self setMicrophoneActiveAppearance:NO];
    self.microphoneButtonHeld = NO;
    [self.microphoneStartCuePlayer stop];
    [self.microphoneEndCuePlayer stop];
    self.speechRecognitionGeneration += 1;
    [self stopSpeechRecognition];
    self.safeToStartRecording = true;
    self.speed_PlayPause_toggle = false;
    self.daydreamView.leftJoystick = CGPointMake(-999, -999);
    self.daydreamView.rightJoystick = CGPointMake(-999, -999);
    [self sendTreadControlSnapshotImmediately];
    [self.treadControlHeartbeatTimer invalidate];
    self.treadControlHeartbeatTimer = nil;
}

- (BOOL)robotActionMessageIsAddressedToThisController:(ROBRobotActionMessage *)message
{
    return message.recipientID.length == 0 ||
        [message.recipientID isEqualToString:[self robotActionSenderID]];
}

- (void)expirePendingRobotActionRequest:(ROBRobotActionMessage *)request
{
    if ([self.currentRobotActionRequest.callID isEqualToString:request.callID] &&
        [self.currentRobotActionRequest.senderID isEqualToString:request.senderID] &&
        self.currentRobotActionState == ROBRobotActionStatePending) {
        self.currentRobotActionState = ROBRobotActionStateExpired;
        [self.robotActionExpiryTimer invalidate];
        self.robotActionExpiryTimer = nil;
    }
    [self sendRobotActionStatusForRequest:request
                                   state:ROBRobotActionStateExpired
                                  detail:@"Approval deadline expired before operator approval."
                                  result:@{}];
    [self refreshRobotActionConsole];
}

- (void)handleRobotActionRequest:(ROBRobotActionMessage *)request
{
    NSString *callID = request.callID;
    if (callID.length == 0) {
        return;
    }

    // Cerebro retransmits immutable requests on UDP loss. Re-send the latest
    // status rather than repeating any state transition or operator action.
    NSString *ledgerKey = [self robotActionLedgerKeyForPeerID:request.senderID callID:callID];
    ROBRobotActionMessage *lastStatus = self.robotActionLastStatusByLedgerKey[ledgerKey];
    if (lastStatus != nil) {
        if (lastStatus.state == ROBRobotActionStatePending && request.isExpired) {
            [self expirePendingRobotActionRequest:request];
        } else {
            [self sendRobotActionMessage:lastStatus];
        }
        return;
    }

    // Preserve exact replay even if the active call was the one protected from
    // FIFO eviction (a defensive path for future ledger changes).
    if ([self.currentRobotActionRequest.callID isEqualToString:callID] &&
        [self.currentRobotActionRequest.senderID isEqualToString:request.senderID]) {
        if (self.currentRobotActionState == ROBRobotActionStatePending && request.isExpired) {
            [self expirePendingRobotActionRequest:request];
        } else {
            [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                           state:self.currentRobotActionState
                                          detail:@"Replayed current operator-console state."
                                          result:@{}];
        }
        return;
    }

    BOOL hasOpenRequest = self.currentRobotActionState == ROBRobotActionStatePending ||
        self.currentRobotActionState == ROBRobotActionStateAccepted ||
        self.currentRobotActionState == ROBRobotActionStateExecuting;
    if (hasOpenRequest) {
        [self sendRobotActionStatusForRequest:request
                                       state:ROBRobotActionStateRejected
                                      detail:@"Another action is already awaiting operator disposition."
                                      result:@{}];
        return;
    }

    self.currentRobotActionRequest = request;
    if (request.isExpired) {
        self.currentRobotActionState = ROBRobotActionStateExpired;
        [self sendRobotActionStatusForRequest:request
                                       state:ROBRobotActionStateExpired
                                      detail:@"Approval deadline expired before the request reached the operator."
                                      result:@{}];
        [self refreshRobotActionConsole];
        return;
    }

    if (!self.robotActionsEnabled) {
        self.currentRobotActionState = ROBRobotActionStateRejected;
        [self sendRobotActionStatusForRequest:request
                                       state:ROBRobotActionStateRejected
                                      detail:@"AI actions are Off; explicit operator opt-in is required. No hardware was actuated."
                                      result:@{}];
        [self refreshRobotActionConsole];
        return;
    }

    self.currentRobotActionState = ROBRobotActionStatePending;
    [self sendRobotActionStatusForRequest:request
                                   state:ROBRobotActionStatePending
                                  detail:@"Awaiting operator approval. This console does not actuate hardware."
                                  result:@{}];
    [self scheduleExpiryForRobotActionRequest:request];
    [self refreshRobotActionConsole];
}

- (void)handleRobotActionCancellation:(ROBRobotActionMessage *)cancellation
{
    NSString *callID = cancellation.callID;
    if (callID.length == 0) {
        return;
    }

    NSString *ledgerKey = [self robotActionLedgerKeyForPeerID:cancellation.senderID callID:callID];
    ROBRobotActionMessage *lastStatus = self.robotActionLastStatusByLedgerKey[ledgerKey];
    if (lastStatus != nil && lastStatus.isTerminal) {
        [self sendRobotActionMessage:lastStatus];
        return;
    }

    BOOL isCurrent = [self.currentRobotActionRequest.callID isEqualToString:callID] &&
        [self.currentRobotActionRequest.senderID isEqualToString:cancellation.senderID];
    if (isCurrent) {
        [self.robotActionExpiryTimer invalidate];
        self.robotActionExpiryTimer = nil;
        NSString *context = cancellation.detail.length > 0 ? cancellation.detail : @"Cancelled by Cerebro.";
        if (self.currentRobotActionState == ROBRobotActionStateAccepted ||
            self.currentRobotActionState == ROBRobotActionStateExecuting) {
            // A network cancellation requests a stop; it does not observe one.
            // Keep Cerebro's blocking action slot occupied until the operator
            // confirms the physical outcome with a terminal button.
            NSString *detail = [NSString stringWithFormat:
                @"%@ Cancellation requested; physical stop/hold is unconfirmed. Operator confirmation is required.",
                context];
            [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                            state:self.currentRobotActionState
                                          detail:detail
                                          result:@{}];
            [self refreshRobotActionConsole];
            return;
        }

        self.currentRobotActionState = ROBRobotActionStateCancelled;
        [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                       state:ROBRobotActionStateCancelled
                                      detail:context
                                      result:@{}];
        [self refreshRobotActionConsole];
        return;
    }

    // UDP may reorder cancellation ahead of its request. Store a terminal
    // tombstone so a later request from this peer with this call ID is never
    // shown or acted on.
    NSString *detail = cancellation.detail.length > 0 ? cancellation.detail : @"Cancelled before request delivery.";
    [self sendRobotActionStatusForRequest:cancellation
                                   state:ROBRobotActionStateCancelled
                                  detail:detail
                                  result:@{}];
}

- (void)handleRobotActionMessage:(ROBRobotActionMessage *)message
{
    NSAssert([NSThread isMainThread], @"Robot-action state must be updated on the main thread");
    if (![self robotActionMessageIsAddressedToThisController:message]) {
        return;
    }

    switch (message.kind) {
        case ROBRobotActionMessageKindActionRequest:
            [self handleRobotActionRequest:message];
            break;
        case ROBRobotActionMessageKindActionCancel:
            [self handleRobotActionCancellation:message];
            break;
        case ROBRobotActionMessageKindControllerHello:
        case ROBRobotActionMessageKindActionStatus:
            break;
    }
}

- (IBAction)approveRobotAction:(id)sender
{
    ROBRobotActionMessage *request = self.currentRobotActionRequest;
    if (!self.robotActionsEnabled || request == nil ||
        self.currentRobotActionState != ROBRobotActionStatePending) {
        return;
    }
    if (request.isExpired) {
        [self expirePendingRobotActionRequest:request];
        return;
    }

    // Approval only records a human decision. It deliberately sends no
    // executing state and calls no robot/servo/tread API.
    [self.robotActionExpiryTimer invalidate];
    self.robotActionExpiryTimer = nil;
    self.currentRobotActionState = ROBRobotActionStateAccepted;
    [self sendRobotActionStatusForRequest:request
                                   state:ROBRobotActionStateAccepted
                                  detail:@"Operator approved. Perform the action manually; this console does not actuate hardware."
                                  result:@{}];
    [self refreshRobotActionConsole];
}

- (IBAction)rejectRobotAction:(id)sender
{
    if (self.currentRobotActionRequest == nil ||
        self.currentRobotActionState != ROBRobotActionStatePending) {
        return;
    }
    [self.robotActionExpiryTimer invalidate];
    self.robotActionExpiryTimer = nil;
    self.currentRobotActionState = ROBRobotActionStateRejected;
    [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                   state:ROBRobotActionStateRejected
                                  detail:@"Operator rejected the proposed action. No hardware was actuated."
                                  result:@{}];
    [self refreshRobotActionConsole];
}

- (IBAction)completeRobotAction:(id)sender
{
    if (self.currentRobotActionRequest == nil ||
        (self.currentRobotActionState != ROBRobotActionStateAccepted &&
         self.currentRobotActionState != ROBRobotActionStateExecuting)) {
        return;
    }
    self.currentRobotActionState = ROBRobotActionStateCompleted;
    [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                   state:ROBRobotActionStateCompleted
                                  detail:@"Operator confirmed the physical outcome after manual action."
                                  result:@{
                                      @"operator_confirmed": @YES,
                                      @"physical_outcome": @"completed",
                                      @"console_actuated_hardware": @NO
                                  }];
    [self refreshRobotActionConsole];
}

- (IBAction)failRobotAction:(id)sender
{
    if (self.currentRobotActionRequest == nil ||
        (self.currentRobotActionState != ROBRobotActionStateAccepted &&
         self.currentRobotActionState != ROBRobotActionStateExecuting)) {
        return;
    }
    self.currentRobotActionState = ROBRobotActionStateFailed;
    [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                   state:ROBRobotActionStateFailed
                                  detail:@"Operator confirmed that the manual physical action failed."
                                  result:@{
                                      @"operator_confirmed": @YES,
                                      @"physical_outcome": @"failed",
                                      @"console_actuated_hardware": @NO
                                  }];
    [self refreshRobotActionConsole];
}

- (IBAction)cancelRobotAction:(id)sender
{
    if (self.currentRobotActionRequest == nil ||
        (self.currentRobotActionState != ROBRobotActionStatePending &&
         self.currentRobotActionState != ROBRobotActionStateAccepted &&
         self.currentRobotActionState != ROBRobotActionStateExecuting)) {
        return;
    }
    BOOL operatorConfirmedPhysicalStop =
        self.currentRobotActionState == ROBRobotActionStateAccepted ||
        self.currentRobotActionState == ROBRobotActionStateExecuting;
    [self.robotActionExpiryTimer invalidate];
    self.robotActionExpiryTimer = nil;
    self.currentRobotActionState = ROBRobotActionStateCancelled;
    [self sendRobotActionStatusForRequest:self.currentRobotActionRequest
                                   state:ROBRobotActionStateCancelled
                                  detail:(operatorConfirmedPhysicalStop
                                      ? @"Operator confirmed that the manual action stopped or was safely cancelled."
                                      : @"Operator cancelled the pending request before approval. No hardware was actuated.")
                                  result:@{
                                      @"operator_confirmed_stop": @(operatorConfirmedPhysicalStop),
                                      @"console_actuated_hardware": @NO
                                  }];
    [self refreshRobotActionConsole];
}

-(IBAction) reconnectAutoNet:(id)sender {
    //Reconnection Proceedure...needs to be embedded into autoNetClient API and pushed to Github repo
    [self setRobotActionsEnabled:NO reason:@"AutoNet reconnect requested; AI actions reset to Off"];
    self.didAnnounceRobotActionConsole = NO;
    [self.autoNetClient stop];
    [self.autoNetClient startBrowsing];
}

- (void)autoNetClient:(AutoNetClient *)client didChangeConnectionState:(BOOL)isConnected
{
    if (client != self.autoNetClient) {
        return;
    }

    // AutoNetClient delivers this on the main queue after reciprocal pairing
    // proof succeeds and whenever that authenticated readiness is lost.
    [self refreshAutonomyConsole];
}

- (void) didReceiveData:(NSData *)data {
    ROBAutonomySessionMessage *autonomyMessage = [ROBAutonomySessionWireCodec decodeEnvelopeData:data];
    if (autonomyMessage != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleAutonomyMessage:autonomyMessage];
            if (!self.didAnnounceRobotActionConsole) {
                [self announceRobotActionConsole];
            }
        });
        return;
    }

    ROBRobotActionMessage *robotActionMessage = [ROBRobotActionWireCodec decodeEnvelopeData:data];
    if (robotActionMessage != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.didAnnounceRobotActionConsole) {
                [self announceRobotActionConsole];
            }
            [self handleRobotActionMessage:robotActionMessage];
        });
        return;
    }

    NSError *error = nil;
    NSSet *classSet = [NSSet setWithObjects:[NSDictionary class], [NSString class], [NSData class], nil];
    NSDictionary *messageDictionary = (NSDictionary*) [NSKeyedUnarchiver unarchivedObjectOfClasses:classSet fromData:data error:&error];
    NSString *msg = [messageDictionary valueForKey:@"message"];
    NSString *sender = [messageDictionary valueForKey:@"sender"];
    if (error != nil) {
        NSLog(@"Error data recieved: %@", [error localizedDescription]);
    }
    
    //TODO: Set AutoBrake userinterface status here!!! Bring in Gyro Data
    //TODO: make sure to send all the RPLidar M2M1 mapper data as well...
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        if (!self.didAnnounceRobotActionConsole) {
            [self announceRobotActionConsole];
        }
    });
    if ([msg isEqualToString:@"Clear input text message"]) {
        dispatch_async(dispatch_get_main_queue(), ^(){
            self.currentUserVerbalQueryString = @"";
            self.textView.text = @"";
        });
    }
    if ([sender isEqualToString:@"rpLidar"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __weak ConsciousViewController *weakSelf = self;
            
            NSMutableArray *lidarScan = [msg componentsSeparatedByString:@"\n"].mutableCopy;
            if (lidarScan.count < 2) {
                NSLog(@"Ignoring malformed RPLidar scan without position and pose headers");
                return;
            }
            //x:y:z
            NSArray *position = [lidarScan[0] componentsSeparatedByString:@":"];
            [lidarScan removeObjectAtIndex:0];
            if (position.count >= 3) {
                weakSelf.locationLabel.text = [NSString stringWithFormat:@"x:%@  y:%@  z:%@", position[0], position[1], position[2]];
            }
            
            //yaw:pitch:roll
            NSArray *pose = [lidarScan[0] componentsSeparatedByString:@":"];
            [lidarScan removeObjectAtIndex:0];
            double robotYaw = pose.count > 0 ? [pose[0] doubleValue] : self.yaw;
            double robotPitch = pose.count > 1 ? [pose[1] doubleValue] : self.pitch;
            double robotRoll = pose.count > 2 ? [pose[2] doubleValue] : self.roll;
            double robotHeadingRadians = fabs(robotYaw) > (M_PI * 2.0)
                ? robotYaw * M_PI / 180.0
                : robotYaw;
            weakSelf.rotationLabel.text = [NSString stringWithFormat:@"yaw:%.2f  pitch:%.2f  roll:%.2f", robotYaw, robotPitch, robotRoll];

            //laserPoint-distance:angle
            
            weakSelf.rpLidarPolarView.laserPoints = lidarScan;
            [weakSelf.rpLidarPolarView setNeedsDisplay];
            [weakSelf.openStreetMapView updateLaserPoints:lidarScan headingRadians:robotHeadingRadians];
        });
    }
    if ([sender isEqualToString:@"rpLidar.map"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData *map_data = [messageDictionary valueForKey:@"map.data"];
            NSString *map_width_string = [messageDictionary valueForKey:@"map.width"];
            NSString *map_height_string = [messageDictionary valueForKey:@"map.height"];
            
            int map_width = map_width_string.intValue;
            int map_height = map_height_string.intValue;
            [self.rpLidarMapController updateMapWithData:map_data
                                                   width:map_width
                                                  height:map_height];
        });
    }
}


#pragma mark - UITableViewDelegate/Datasource


- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.localeArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"languageCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"languageCell"];
    }
    cell.textLabel.text = [self.localeArray[indexPath.row] valueForKey:@"locale_id"];
    cell.detailTextLabel.text = [self.localeArray[indexPath.row] valueForKey:@"locale_string"];
    if ([self usesIPadCommandConsole]) {
        cell.contentView.backgroundColor = [self consoleSurfaceColor];
        cell.backgroundColor = [self consoleSurfaceColor];
        cell.textLabel.textColor = [self consoleAmberColor];
        cell.detailTextLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.58];
        cell.tintColor = [self consoleAmberColor];
    } else {
        cell.contentView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
        cell.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
    }
    
    if (indexPath.row == self.selectedLocaleIndex)
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    else
        cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}


- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectedLocaleIndex = (int)indexPath.row;
    [tableView reloadData];
    
    NSString *locale = [self.localeArray[self.selectedLocaleIndex] valueForKey:@"locale_id"];
    [self chooseOutputLanguageAction:locale];
}


- (IBAction)flipper_FORWARD_touchdown:(id)sender{ self.flipper_FORWARD_isDown = true;}
- (IBAction)flipper_FORWARD_touchup:(id)sender{ self.flipper_FORWARD_isDown = false;}

- (IBAction)flipper_RELAX_touchdown:(id)sender{ self.flipper_RELAX_isDown = true;}
- (IBAction)flipper_RELAX_touchup:(id)sender{ self.flipper_RELAX_isDown = false;}

- (IBAction)flipper_BACKWARD_touchdown:(id)sender{ self.flipper_BACKWARD_isDown = true;}
- (IBAction)flipper_BACKWARD_touchup:(id)sender{ self.flipper_BACKWARD_isDown = false;}



- (IBAction)lact_FRONT_touchdown:(id)sender{ self.lact_FRONT_isDown = true;}
- (IBAction)lact_FRONT_touchup:(id)sender{ self.lact_FRONT_isDown = false;}

- (IBAction)lact_GRAVITY_toggle:(id)sender{ self.lact_GRAVITY_toggle = !self.lact_GRAVITY_toggle;}

- (IBAction)lact_BACK_touchdown:(id)sender{ self.lact_BACK_isDown = true;}
- (IBAction)lact_BACK_touchup:(id)sender{ self.lact_BACK_isDown = false;}

- (IBAction)speed_REVERSE_toggle:(id)sender
{
    self.speed_ForwardReverse_toggle = false;
    [self sendTreadControlSnapshotImmediately];
}
- (IBAction)speed_FORWARD_toggle:(id)sender
{
    self.speed_ForwardReverse_toggle = true;
    [self sendTreadControlSnapshotImmediately];
}
- (IBAction)speed_slider_action:(UISlider *)sender
{
    self.speed = sender.value;
    [self treadInputDidChangeLeft:self.daydreamView.leftJoystick
                            right:self.daydreamView.rightJoystick];
}

- (void) clampSpeed
{
    if (self.speed < 0.0)
        self.speed = 0.0;
    if (self.speed > 100.0)
        self.speed = 100.0;
    
    self.speedSlider.value = self.speed;
}

- (IBAction)speed_reduce:(id)sender
{
    self.speed -= 10.0;
    [self clampSpeed];
    [self sendTreadControlSnapshotImmediately];
}
- (IBAction)speed_increase:(id)sender
{
    self.speed += 10.0;
    [self clampSpeed];
    [self sendTreadControlSnapshotImmediately];
}
- (IBAction)speed_10Percent:(id)sender
{
    self.speed = 10.0;
    [self clampSpeed];
    [self sendTreadControlSnapshotImmediately];
}
- (IBAction)speed_max:(id)sender
{
    self.speed = 100.0;
    [self clampSpeed];
    [self sendTreadControlSnapshotImmediately];
}
- (IBAction)speed_playpause_action:(id)sender
{
    self.speed_PlayPause_toggle = !self.speed_PlayPause_toggle;
    [self sendTreadControlSnapshotImmediately];
}

- (IBAction)flipper_brakelock:(id)sender{ self.flipper_BRAKELOCK = !self.flipper_BRAKELOCK;}
- (IBAction)tred_brakelock:(id)sender
{
    self.tred_BRAKELOCK = !self.tred_BRAKELOCK;
    [self sendTreadControlSnapshotImmediately];
}

- (IBAction) toggleControllerView:(id)sender
{
    self.daydreamView.hidden = !self.daydreamView.hidden;
}


#pragma mark - RPLidar

- (IBAction)rpLidarZoomAction:(UISlider *)sender {
    self.rpLidarPolarView.zoomScale = sender.value;
}

- (void)dealloc
{
    self.microphoneStartCuePlayer.delegate = nil;
    self.microphoneEndCuePlayer.delegate = nil;
    [self.microphoneStartCuePlayer stop];
    [self.microphoneEndCuePlayer stop];
    [self stopSpeechRecognition];
    [self.robotActionExpiryTimer invalidate];
    [self.robotActionHelloTimer invalidate];
    [self.treadControlHeartbeatTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
