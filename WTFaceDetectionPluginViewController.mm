//
//  WTFaceDetectionPluginViewController.m
//  Native Examples
//
//  Created by Alami Yacine on 29/07/15.
//  Edited by Big Daddy on 09/19/16
//  Copyright (c) 2015 Wikitude. All rights reserved.
//

#import "WTFaceDetectionPluginViewController.h"

#import <AVFoundation/AVCaptureSession.h>
#import <WikitudeNativeSDK/WikitudeNativeSDK.h>

#import "FaceDetectionPluginConnector.h"
#import "WikitudeLicense.h"
#import "StrokedRectangle.h"
#import "ExternalRenderer.h"


#define DEGREES_TO_RADIANS(x) ((x) / 180.0 * M_PI)


@interface WTFaceDetectionPluginViewController () <WTWikitudeNativeSDKDelegate, WTClientTrackerDelegate>

@property (nonatomic, strong) WTWikitudeNativeSDK                           *wikitudeSDK;
@property (nonatomic, strong) WTClientTracker                               *clientTracker;

@property (nonatomic, strong) EAGLContext                                   *sharedWikitudeEAGLCameraContext;

@property (nonatomic, copy) WTWikitudeUpdateHandler                         wikitudeUpdateHandler;
@property (nonatomic, copy) WTWikitudeDrawHandler                           wikitudeDrawHandler;

@property (nonatomic, assign) BOOL                                          isTracking;

@property (nonatomic, strong) ExternalRenderer                              *renderer;
@property (nonatomic, strong) StrokedRectangle                              *renderableRectangle;
@property (nonatomic, strong) StrokedRectangle                              *recognizedFaceRectangle;

@property (nonatomic, assign) std::shared_ptr<FaceDetectionPluginConnector> faceDetectionPluginConnector;
@property (nonatomic, assign) std::shared_ptr<FaceDetectionPlugin>          faceDetectionPlugin;

@property (nonatomic, assign) BOOL                                          faceDetected;


//boolean flag to see if a face wasn't recognized
@property (nonatomic, assign) BOOL                                          faceUnDetectedBool;




@end

@implementation WTFaceDetectionPluginViewController

+ (int)flipFlagForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    int flipFlag = 1; // one refers to portrait orientation
    
    if ( UIDeviceOrientationIsLandscape(deviceOrientation) ) {
        if ( UIDeviceOrientationLandscapeLeft == deviceOrientation ) {
            flipFlag = 999;
        } else if ( UIDeviceOrientationLandscapeRight == deviceOrientation ) {
            flipFlag = -1;
        }
    } else if ( UIDeviceOrientationIsPortrait(deviceOrientation) ) {
        if ( UIDeviceOrientationPortrait == deviceOrientation ) {
            flipFlag = 1;
        } else if ( UIDeviceOrientationPortraitUpsideDown == deviceOrientation ) {
            flipFlag = 0;
        }
    } else { /* face up or face down */
        UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
        if ( UIInterfaceOrientationIsLandscape(interfaceOrientation) ) {
            if ( UIInterfaceOrientationLandscapeRight == interfaceOrientation ) {
                flipFlag = 999;
            } else if ( UIInterfaceOrientationLandscapeLeft == interfaceOrientation ) {
                flipFlag = -1;
            }
        } else if ( UIInterfaceOrientationIsPortrait(interfaceOrientation) ) {
            if ( UIInterfaceOrientationPortrait == interfaceOrientation ) {
                flipFlag = 1;
            } else if ( UIInterfaceOrientationPortraitUpsideDown == interfaceOrientation ) {
                flipFlag = 0;
            }
        }
    }
    
    return flipFlag;
}

#pragma mark UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _faceUnDetectedBool = NO;
    
    //hide augmentation labels
    [self.collin setHidden:YES];
    [self.josh setHidden:YES];
    [self.jordan setHidden:YES];
    [self.matt setHidden:YES];
	
    self.renderer = [[ExternalRenderer alloc] init];
    self.renderableRectangle = [[StrokedRectangle alloc] init];
	self.renderableRectangle.scale = 320.0f;
	
    self.recognizedFaceRectangle = [[StrokedRectangle alloc] init];
		
	
    self.wikitudeSDK = [[WTWikitudeNativeSDK alloc] initWithRenderingMode:WTRenderingMode_External delegate:self];
    [self.wikitudeSDK setLicenseKey:kWTLicenseKey];

    std::string databasePath( [[[NSBundle mainBundle] pathForResource:@"high_database" ofType:@"xml" inDirectory:@"Assets"] UTF8String] );

    _faceDetectionPluginConnector = std::make_shared<FaceDetectionPluginConnector>(self);
    _faceDetectionPlugin = std::make_shared<FaceDetectionPlugin>(640, 480, databasePath, *_faceDetectionPluginConnector.get());

    __weak typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        
        weakSelf.faceDetectionPlugin->setFlipFlag( [WTFaceDetectionPluginViewController flipFlagForDeviceOrientation:[[UIDevice currentDevice] orientation]] );
    }];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _faceUnDetectedBool = NO;
    
    //hide augmentation labels
    [self.collin setHidden:YES];
    [self.josh setHidden:YES];
    [self.jordan setHidden:YES];
    [self.matt setHidden:YES];
    
    [self.renderer setupRenderingWithLayer:[self.eaglView eaglLayer]];
    [self.renderer startRenderLoopWithRenderBlock:[self renderBlock]];

    [self.wikitudeSDK start:^(WTStartupConfiguration *startupConfiguration) {
        startupConfiguration.captureDevicePreset = AVCaptureSessionPreset640x480;
		startupConfiguration.captureDeviceFocusMode = AVCaptureFocusModeContinuousAutoFocus;
		startupConfiguration.targetFrameRate = WTMakeTargetFrameRate30FPS();
    } completion:^(BOOL isRunning, NSError * __nonnull error) {
        if ( !isRunning ) {
            NSLog(@"Wikitude SDK is not running. Reason: %@", [error localizedDescription]);
        }
        else
        {
            NSURL *clientTrackerURL = [[NSBundle mainBundle] URLForResource:@"faces_database" withExtension:@"wtc" subdirectory:@"Assets"];
            self.clientTracker = [self.wikitudeSDK.trackerManager create2DClientTrackerFromURL:clientTrackerURL extendedTargets:nil andDelegate:self];

            _faceDetectionPlugin->setFlipFlag( [WTFaceDetectionPluginViewController flipFlagForDeviceOrientation:[[UIDevice currentDevice] orientation]] );
            [self.wikitudeSDK registerPlugin:_faceDetectionPlugin];
        }
    }];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    [self.wikitudeSDK removePlugin:_faceDetectionPlugin];
    [self.wikitudeSDK stop];
    
    [self.renderer stopRenderLoop];
    [self.renderer teardownRendering];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [self.wikitudeSDK shouldTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Public Methods
- (void)setFaceIsRecognized:(BOOL)recognized atPosition:(const float*)modelViewMatrix
{
    self.faceDetected = recognized;
    if (recognized) {
        
        [self.recognizedFaceRectangle setModelViewMatrix:modelViewMatrix];
        
    }
    
}

- (void)setFaceAugmentationProjectionMatrix:(const float*)projectionMatrix
{
    [self.recognizedFaceRectangle setProjectionMatrix:projectionMatrix];
}

#pragma mark - ExternalRenderer render loop
- (ExternalRenderBlock)renderBlock
{
    return ^ (CADisplayLink *displayLink) {
        if ( self.wikitudeUpdateHandler
            &&
            self.wikitudeDrawHandler )
        {
            self.wikitudeUpdateHandler();
            self.wikitudeDrawHandler();
        }

        [self.renderer bindBuffer];
        
        if ( _isTracking )
        {
            [self.renderableRectangle drawInContext:[self.renderer internalContext]];
        }
		if ( _faceDetected )
		{
            [self.recognizedFaceRectangle drawInContext:[self.renderer internalContext]];
            
		}
        
        
    };
}

#pragma mark - Delegation
#pragma mark WTWikitudeNativeSDKDelegte
- (void)wikitudeNativeSDK:(WTWikitudeNativeSDK * __nonnull)wikitudeNativeSDK didCreatedExternalUpdateHandler:(WTWikitudeUpdateHandler __nonnull)updateHandler
{
    self.wikitudeUpdateHandler = updateHandler;
}

- (void)wikitudeNativeSDK:(WTWikitudeNativeSDK * __nonnull)wikitudeNativeSDK didCreatedExternalDrawHandler:(WTWikitudeDrawHandler __nonnull)drawHandler
{
    self.wikitudeDrawHandler = drawHandler;
}

- (EAGLContext *)eaglContextForVideoCameraInWikitudeNativeSDK:(WTWikitudeNativeSDK * __nonnull)wikitudeNativeSDK
{
    if (!_sharedWikitudeEAGLCameraContext )
    {
        EAGLContext *rendererContext = [self.renderer internalContext];
        self.sharedWikitudeEAGLCameraContext = [[EAGLContext alloc] initWithAPI:[rendererContext API] sharegroup:[rendererContext sharegroup]];
    }
    return self.sharedWikitudeEAGLCameraContext;
}

- (CGRect)eaglViewSizeForExternalRenderingInWikitudeNativeSDK:(WTWikitudeNativeSDK * __nonnull)wikitudeNativeSDK
{
    return self.eaglView.bounds;
}

- (void)wikitudeNativeSDK:(WTWikitudeNativeSDK * __nonnull)wikitudeNativeSDK didEncounterInternalError:(NSError * __nonnull)error
{
    NSLog(@"Internal Wikitude SDK error encounterd. %@", [error localizedDescription]);
}

#pragma mark WTClientTrackerDelegate

- (void)baseTracker:(nonnull WTBaseTracker *)baseTracker didRecognizedTarget:(nonnull WTImageTarget *)recognizedTarget
{
    
    NSLog(@"recognized target '%@'", [recognizedTarget name]);
    _isTracking = YES;
    
    
    if ([[recognizedTarget name]  isEqual: @"image3"]){ //matt
        NSLog(@"Matt");
        [self.matt setHidden:NO];
    }
    else if ([[recognizedTarget name]  isEqual: @"image2"]){ //josh
        NSLog(@"Josh");
        [self.josh setHidden:NO];
    }
    else if ([[recognizedTarget name]  isEqual: @"image1-2"]){ //jordan
        NSLog(@"Jordan");
        [self.jordan setHidden:NO];
    }
    else if ([[recognizedTarget name]  isEqual: @"image1"]){ //collin
        NSLog(@"Collin");
        [self.collin setHidden:NO];
    }
    else {
        NSLog(@"Undetected");
        _faceUnDetectedBool = YES;
    }
}

- (void)baseTracker:(nonnull WTBaseTracker *)baseTracker didTrackTarget:(nonnull WTImageTarget *)trackedTarget
{
    [self.renderableRectangle setProjectionMatrix:trackedTarget.projection];
    [self.renderableRectangle setModelViewMatrix:trackedTarget.modelView];
    
}

- (void)baseTracker:(nonnull WTBaseTracker *)baseTracker didLostTarget:(nonnull WTImageTarget *)lostTarget
{
    NSLog(@"lost target '%@'", [lostTarget name]);
    _isTracking = NO;
    
    //check to see if face wasn't detected
    if(_faceUnDetectedBool == YES){
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Face isn't Recognized!"
                                                    message:@"You must add the face to the faces database file first."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
        [alert show];
        
        
    }
    
    
    //hide augmentation labels
    [self.collin setHidden:YES];
    [self.josh setHidden:YES];
    [self.jordan setHidden:YES];
    [self.matt setHidden:YES];
    
    _faceUnDetectedBool = NO;
    
    
  
}


- (void)clientTracker:(nonnull WTClientTracker *)clientTracker didFinishedLoadingTargetCollectionFromURL:(nonnull NSURL *)URL
{
    NSLog(@"Client tracker loaded");
}

- (void)clientTracker:(nonnull WTClientTracker *)clientTracker didFailToLoadTargetCollectionFromURL:(nonnull NSURL *)URL withError:(nonnull NSError *)error
{
    NSLog(@"Unable to load client tracker. Reason: %@", [error localizedDescription]);
}

@end
