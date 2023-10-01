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
#import "Consciousness-Swift.h"

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

@property (readwrite, retain) NSMutableArray *localeArray;
@property (readwrite, assign) int selectedLocaleIndex;

@property(nonatomic, strong) AutoNetClient *autoNetClient;
@property (readwrite, retain) IBOutlet UIView *chatConnectionStatus;
//@property(readwrite, strong) ResNetController *resnet;
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
    self.motionManager.deviceMotionUpdateInterval = (1.0/10.0);
    
    
    
    
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
        self.autoNetClient = [[AutoNetClient alloc] initWithService:@"_roboNet._tcp"];
    self.autoNetClient.dataDelegate = self;
    [self.autoNetClient start];
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


- (IBAction) RequestToBeMasterControllerAction:(id) sender {
    NSDictionary *messageDict = @{@"message": @"RequestToBeMasterController",
                                  @"sender":[[[UIDevice currentDevice] identifierForVendor] UUIDString]};
    NSError *error = nil;
    [self.autoNetClient sendWithData:[NSKeyedArchiver archivedDataWithRootObject:messageDict requiringSecureCoding:false error:&error]];
    if (error != nil) {
        NSLog(@"Error %@", [error localizedDescription]);
    }
}

-(IBAction) reconnectAutoNet:(id)sender {
    //Reconnection Proceedure...needs to be embedded into autoNetClient API and pushed to Github repo
    [self.autoNetClient stop];
    dispatch_async(dispatch_get_main_queue(), ^(){
        self.chatConnectionStatus.backgroundColor = [UIColor redColor];
    });

    [self.autoNetClient startBrowsing];
}

- (void) didReceiveData:(NSData *)data {
    NSError *error = nil;
    NSSet *classSet = [NSSet setWithObjects:[NSDictionary class], [NSString class], nil];
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
            weakSelf.rotationLabel.text = [NSString stringWithFormat:@"yaw:%@ pitch:%@ roll:%@", pose[0], pose[1], pose[2]];
            //laserPoint-distance:angle
            
            weakSelf.rpLidarPolarView.laserPoints = lidarScan;
            [weakSelf.rpLidarPolarView setNeedsDisplay];
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


@end
