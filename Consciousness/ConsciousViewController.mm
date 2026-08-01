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

#import <Speech/Speech.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>
#import <CoreMotion/CoreMotion.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import "ROBController-Swift.h"

@interface ConsciousViewController () <AVCaptureAudioDataOutputSampleBufferDelegate, AVSpeechSynthesizerDelegate, SFSpeechRecognizerDelegate, SFSpeechRecognitionTaskDelegate, UITableViewDelegate, UITableViewDataSource, AutoNetClientDataDelegate, CLLocationManagerDelegate>
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
@property (nonatomic, strong) AVSpeechSynthesizer *speechSynthesizer;
@property (nonatomic, assign) BOOL isSpeaking;
@property (atomic, assign) BOOL safeToStartRecording;

@property (nonatomic, retain) IBOutlet UITableView * languageTableView;
@property (readwrite, retain) IBOutlet RPLidarPolarView *rpLidarPolarView;
@property (readwrite, retain) IBOutlet UIStackView *commandSheetStackView;
@property (nonatomic, retain) IBOutlet UITextView * textView;
@property (atomic, retain) NSString *currentUserVerbalQueryString;
@property (nonatomic, retain) IBOutlet UILabel * locationLabel;
@property (nonatomic, retain) IBOutlet UILabel * rotationLabel;

//@property (nonatomic, retain) IBOutlet UIButton * recordButton; //auto start in english instead? change upon language  selection?

@property (readwrite, retain) CLLocationManager *locationManager;
@property (readwrite, retain) CMMotionManager *motionManager;
@property (readwrite, retain) CMAttitude *referenceAttitude;
@property (readwrite, assign) float yaw;
@property (readwrite, assign) float pitch;
@property (readwrite, assign) float roll;

@property (readwrite, retain) NSMutableArray *localeArray;
@property (readwrite, assign) int selectedLocaleIndex;

@property(nonatomic, strong) AutoNetClient *autoNetClient;
@property(nonatomic, strong) ROBWatchRelay *watchRelay;
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
//@property(readwrite, strong) ResNetController *resnet;

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
- (void)refreshRobotActionConsole;
- (void)announceRobotActionConsole;
- (void)setRobotActionsEnabled:(BOOL)enabled reason:(NSString *)reason;
- (ROBRobotActionMessage *)sendRobotActionStatusForRequest:(ROBRobotActionMessage *)request
                                                     state:(ROBRobotActionState)state
                                                    detail:(NSString *)detail
                                                    result:(NSDictionary *)result;
- (void)presentControllerNoticeWithTitle:(NSString *)title message:(NSString *)message;

@property (readwrite, assign) IBOutlet UIImageView *rpLidarMapView;
@property (readwrite, retain) RPLidarMapController *rpLidarMapController;

@end

@implementation ConsciousViewController

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *newLocation = locations.firstObject;
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
    
    // store all of the measurements, just so we can see what kind of data we might receive
    //[self.locationMeasurements addObject:newLocation];
    
    // update the display with the new location data
    //[self.tableView reloadData];
}


- (void)viewDidLoad {
    [super viewDidLoad];
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [self refreshRobotActionConsole];
    [self refreshAutonomyConsole];

    self.rpLidarMapController = [[RPLidarMapController alloc] initWithRpLidarMapView:self.rpLidarMapView];
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
        
        //CFTimeInterval elapsedTime = CACurrentMediaTime() - self->startTime;
        //self->startTime = CACurrentMediaTime();
        //printf("%f\n", elapsedTime * 100.0);
        //*******
        
        // perform some action
        
        
        // Find out the Z rotation of the device by doing some trig on the accelerometer values for X and Y
        float Lat = self.locationManager.location.coordinate.latitude;
        float Long = self.locationManager.location.coordinate.longitude;
        //NSLog(@"Lat : %f  Long : %f",Lat,Long);
        
        if (self.referenceAttitude)
            [data.attitude multiplyByInverseOfAttitude:self.referenceAttitude];
        //NSLog(@"data.attitude.yaw = %f, data.attitude.pitch = %f, data.attitude.roll = %f", data.attitude.yaw, data.attitude.pitch, data.attitude.roll);
        
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
        //NSLog(@"dataString = %@", dataString);
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
    /* // !!!! Before WE ENABLE AUTOREJOIN MAKE SURE THE INITIAL BASE NETWORK NEEDS IT !!!!
    [NSTimer scheduledTimerWithTimeInterval:10 repeats:true block:^(NSTimer *timer){
        printf(".");
        if (self.chatConnectionStatus.backgroundColor == [UIColor redColor])
        {
            //self.chatManager = nil;
            
            NSString *newName = [NSString stringWithFormat:@"Brain%i", rand()%2000];
            NSLog(@"Rejoining Command&Control Server as %@", newName);
            self.chatManager = [[NZChatManager alloc] joinWithDisplayName:newName];
            //self.chatManager.chatDelegate = self;
        }
        
    }];*/
    //---
    //Aurora Setup audio tap conflicts with speech audio tap...???
    // how to merge the 2 audio captures to be used together? DTS Ticket material
    //[glview setup];
    //[glview startAnimation];
    //---
    
    
//    notificationCenter.addObserver(self,
//                selector: #selector(systemVolumeDidChange),
//                name: "AVSystemController_SystemVolumeDidChangeNotification",
//                object: nil
//            )
//    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(systemVolumeDidChange:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    
    self.safeToStartRecording = true;
    [self speechAudioInit];
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
    //dispatch_async(dispatch_get_main_queue(), ^(){
    //    self.languageTableView.backgroundColor = [UIColor clearColor];
    //});
    
    //[self closeMenu];
    //self.isAnimating = false;
    
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
    
    //THis button controls auto speech recording
    //[self recordButtonTapped:self];
}

- (IBAction)recordButtonTouchDown:(id)sender {
//    if (self.safeToStartRecording) {
        self.safeToStartRecording = false;
        [self setupSpeechRecognition];
        NSLog(@"Recording has started...");
//    } else {
//        NSError *outError;
//        
//        [self.audioEngine prepare];
//        [self.audioEngine startAndReturnError:&outError];
//        if (outError)
//            NSLog(@"Error %@", outError);
//    }
}

- (IBAction)recordButtonTouchUp:(id)sender {
    [self.task cancel];
//    [self endRecognizer];
//    if (self.audioEngine.isRunning)
//    {
//        [self.audioEngine pause];
//        //self.currentUserVerbalQueryString = @"";
//        //self.textView.text = @"";
//    }
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
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeMeasurement error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    [self startRecognizer];
    //[self startCapture];
    
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.speechSynthesizer  = [[AVSpeechSynthesizer alloc] init];
    [self.speechSynthesizer setDelegate:self];
    
}


- (void)startRecognizer
{
    NSString *locale = [self.localeArray[self.selectedLocaleIndex] valueForKey:@"locale_id"];
    
    NSLog(@"starting speech recognizer with Locale - %@", locale);
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:locale]];
    self.speechRecognizer.delegate = self;
    
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        if (status == SFSpeechRecognizerAuthorizationStatusAuthorized){
            
            self.speechRequest = [SFSpeechAudioBufferRecognitionRequest new];
            //self.speechRequest.shouldReportPartialResults = YES;
            
            AVAudioInputNode *inputNode = [self.audioEngine inputNode];
            
            if (self.speechRequest == nil) {
                NSLog(@"Unable to created a SFSpeechAudioBufferRecognitionRequest object");
            }
            
            if (inputNode == nil) {
                
                NSLog(@"Unable to create an inputNode object");
            }
            
            //self.task = [self.speechRecognizer recognitionTaskWithRequest:self.speechRequest delegate:self];
            
            self.task = [self.speechRecognizer recognitionTaskWithRequest:self.speechRequest resultHandler:^(SFSpeechRecognitionResult* result, NSError *error){
                BOOL isFinal = false;
                
                if (result != nil)
                {
                    self.currentUserVerbalQueryString = result.bestTranscription.formattedString;
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        self.textView.text = result.bestTranscription.formattedString;
                    });
                    
                    isFinal = result.isFinal;
                    
                    //[self.speechSynthesizer speakUtterance:[AVSpeechUtterance speechUtteranceWithString:result.bestTranscription.formattedString]];

                    [self positionTextView];
                }
                
                if (error != nil || isFinal)
                {
                    if (!isFinal)
                        NSLog(@"error = %@", error.localizedDescription);
                    else
                        NSLog(@"restarting speech recognition ");
                    
                    [self.audioEngine stop];
                    [inputNode removeTapOnBus:0];
                    
                    self.speechRequest = nil;
                    self.task = nil;
                    
                    //self.recordButton.enabled = true;
                    //[self.recordButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
                    
                    //This method will control auto listening at all times voer and over for continuous speech recognition
                    //[self startRecognizer];
                }
                
            }];
            
            [inputNode installTapOnBus:0 bufferSize:1024 format:[inputNode outputFormatForBus:0] block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when){
                [self.speechRequest appendAudioPCMBuffer:buffer];
            }];
            
            
            NSError *outError;
            
            [self.audioEngine prepare];
            [self.audioEngine startAndReturnError:&outError];
            
            if (outError)
                NSLog(@"Error %@", outError);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self positionTextView];
            });
            
            
            
            //---------
            // Shows a different audio tap method that shows sample buffers
            // should call startCapture method in main queue or it may crash
            //dispatch_async(dispatch_get_main_queue(), ^{
            //    [self startCapture];
            //});
            //---------
            
        }
    }];
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
        //[self.speechSynthesizer speakUtterance:[AVSpeechUtterance speechUtteranceWithString:translatedString]];
    });
    
    if ([result isFinal]) {
        [self.audioEngine stop];
        [self.audioEngine.inputNode removeTapOnBus:0];
        self.task = nil;
        self.speechRequest = nil;
    }
}


- (void)positionTextView {
    
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
        //self.recordButton.enabled = YES;
        //[self.recordButton setTitle:@"Start Recording" forState:UIControlStateNormal];
        
    }
    else{
        NSLog(@"recognizer is not available");
        //self.recordButton.enabled = NO;
        //[self.recordButton setTitle:@"Recognition not available" forState:UIControlStateDisabled];
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //NSLog(@"Listening....");
        //[self startRecognizer];
        //[self startCapture];
    });
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
    //self.isSpeaking = YES;
    //[self endRecognizer];
    //[self endCapture];
    
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
    [self startSocialRoamSession];
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
            break;
    }
    [self refreshAutonomyConsole];
}

- (void)refreshAutonomyConsole
{
    BOOL pairingConfigured = self.autoNetClient.isPairingConfigured;
    BOOL connected = self.autoNetClient.isConnected;
    BOOL sessionMayBeActive = self.autonomySessionID.length > 0 || self.autonomyStartRequested ||
        self.autonomySessionState == ROBAutonomySessionStateActive ||
        self.autonomySessionState == ROBAutonomySessionStateStopping;

    NSString *pairTitle = pairingConfigured
        ? (connected ? @"Pair: Connected" : @"Pair: Stored")
        : @"Pair Cerebro…";
    [self.pairControllerButton setTitle:pairTitle forState:UIControlStateNormal];
    self.pairControllerButton.enabled = !sessionMayBeActive;

    NSString *stateName = @"INACTIVE";
    NSString *buttonTitle = @"Start Social Roam";
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
    dispatch_async(dispatch_get_main_queue(), ^(){
        self.chatConnectionStatus.backgroundColor = [UIColor redColor];
    });

    [self.autoNetClient startBrowsing];
}

- (void) didReceiveData:(NSData *)data {
    ROBAutonomySessionMessage *autonomyMessage = [ROBAutonomySessionWireCodec decodeEnvelopeData:data];
    if (autonomyMessage != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.chatConnectionStatus.backgroundColor = [UIColor greenColor];
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
            self.chatConnectionStatus.backgroundColor = [UIColor greenColor];
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
        self.chatConnectionStatus.backgroundColor = [UIColor greenColor];
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
    if ([msg isEqualToString:@"Hey I got your message"]) {
        dispatch_async(dispatch_get_main_queue(), ^(){
            self.chatConnectionStatus.backgroundColor = [UIColor greenColor];
        });
    }
    if ([sender isEqualToString:@"rpLidar"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __weak ConsciousViewController *weakSelf = self;
            
            NSMutableArray *lidarScan = [msg componentsSeparatedByString:@"\n"].mutableCopy;
            //x:y:z
            NSArray *position = [lidarScan[0] componentsSeparatedByString:@":"];
            [lidarScan removeObjectAtIndex:0];
            weakSelf.locationLabel.text = [NSString stringWithFormat:@"x:%@ y:%@ z:%@", position[0], position[1], position[2]];
            
            //yaw:pitch:roll
            NSArray *pose = [lidarScan[0] componentsSeparatedByString:@":"];
            [lidarScan removeObjectAtIndex:0];
            //weakSelf.rotationLabel.text = [NSString stringWithFormat:@"yaw:%@ pitch:%@ roll:%@", pose[0], pose[1], pose[2]];
            weakSelf.rotationLabel.text = [NSString stringWithFormat:@"yaw:%f pitch:%f roll:%f", self.yaw, self.pitch, self.roll];

            //laserPoint-distance:angle
            
            weakSelf.rpLidarPolarView.laserPoints = lidarScan;
            //TODO: we need to inject the map data into this polarView correctly and test the current location calculations...
            //weakSelf.rpLidarPolarView.map = RPMap()
            //weakSelf.rpLidarPolarView.currentLocation = RPLocation()
            
            [weakSelf.rpLidarPolarView setNeedsDisplay];
        });
    }
    //NSLog(@"sender = %@", sender);
    if ([sender isEqualToString:@"rpLidar.map"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData *map_data = [messageDictionary valueForKey:@"map.data"];
            NSString *map_width_string = [messageDictionary valueForKey:@"map.width"];
            NSString *map_height_string = [messageDictionary valueForKey:@"map.height"];
            
            int map_width = map_width_string.intValue;
            int map_height = map_height_string.intValue;
            //NSLog(@"updating map with %lu length bytes", static_cast<unsigned long>(map_data.length));
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
    cell.textLabel.text = [self.localeArray[indexPath.row] valueForKey:@"locale_id"];
    cell.detailTextLabel.text = [self.localeArray[indexPath.row] valueForKey:@"locale_string"];
    
    cell.contentView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
    cell.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
    
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

- (IBAction)speed_REVERSE_toggle:(id)sender{ self.speed_ForwardReverse_toggle = false;}
- (IBAction)speed_FORWARD_toggle:(id)sender{ self.speed_ForwardReverse_toggle = true;}
- (IBAction)speed_slider_action:(UISlider *)sender{ self.speed = sender.value; }

- (void) clampSpeed
{
    if (self.speed < 0.0)
        self.speed = 0.0;
    if (self.speed > 100.0)
        self.speed = 100.0;
    
    self.speedSlider.value = self.speed;
}

- (IBAction)speed_reduce:(id)sender{ self.speed -= 10.0; [self clampSpeed];}
- (IBAction)speed_increase:(id)sender{ self.speed += 10.0; [self clampSpeed];}
- (IBAction)speed_10Percent:(id)sender{ self.speed = 10.0; [self clampSpeed];}
- (IBAction)speed_max:(id)sender{ self.speed = 100.0; [self clampSpeed];}
- (IBAction)speed_playpause_action:(id)sender{ self.speed_PlayPause_toggle = !self.speed_PlayPause_toggle;}

- (IBAction)flipper_brakelock:(id)sender{ self.flipper_BRAKELOCK = !self.flipper_BRAKELOCK;}
- (IBAction)tred_brakelock:(id)sender{ self.tred_BRAKELOCK = !self.tred_BRAKELOCK;}

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
    [self.robotActionExpiryTimer invalidate];
    [self.robotActionHelloTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
