//
//  WTFaceDetectionPluginViewController.h
//  Native Examples
//
//  Created by Yacine Alami on 29/07/15.
//  Edited by Big Daddy on 09/19/16
//  Copyright (c) 2015 Wikitude. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <vector>

#include <opencv.hpp>

#import "ExternalEAGLView.h"


@interface WTFaceDetectionPluginViewController : UIViewController

@property (nonatomic,weak) IBOutlet ExternalEAGLView *eaglView;

@property (nonatomic, strong) IBOutlet UILabel *collin;
@property (nonatomic, strong) IBOutlet UILabel *josh;
@property (nonatomic, strong) IBOutlet UILabel *jordan;
@property (nonatomic, strong) IBOutlet UILabel *matt;

- (void)setFaceIsRecognized:(BOOL)recognized atPosition:(const float*)modelViewMatrix;
- (void)setFaceAugmentationProjectionMatrix:(const float*)projectionMatrix;

@end


