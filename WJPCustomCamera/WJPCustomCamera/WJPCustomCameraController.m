//
//  WJPCustomCameraController.m
//  DengYueCang
//
//  Created by 魏鹏 on 2016/12/15.
//  Copyright © 2016年 ACang. All rights reserved.
//

#import "WJPCustomCameraController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@import CoreMotion;

#define kMainScreenWidth [UIScreen mainScreen].bounds.size.width
#define kMainScreenHeight  [UIScreen mainScreen].bounds.size.height

typedef NS_ENUM(NSInteger, ThunderLightType) {
    THUNDER_LIGHT_TYPE_AUTO = 120,
    THUNDER_LIGHT_TYPE_OPEN,
    THUNDER_LIGHT_TYPE_CLOSE
};

@interface WJPCustomCameraController ()
// 陀螺仪 确定拍照时的方向
@property (nonatomic, strong) CMMotionManager * motionManager;
@property (nonatomic, assign) AVCaptureVideoOrientation avCaptureOrientation;
@property(nonatomic) UIImageOrientation my_imageOrientation;

// AVCaptureSession对象来执行输入设备和输出设备之间的数据传递
@property (nonatomic, strong) AVCaptureSession *session;
// 捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
@property (nonatomic, strong) AVCaptureDevice *device;
// 输入设备
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
// 照片输出流
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
// 预览图层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

// 承载 预览图层
@property (weak, nonatomic) UIView *backView;
// 上方 工具 容器 View
@property (weak, nonatomic) UIView *topToolView;
// 下方 工具 容器 View
@property (weak, nonatomic) UIView *bottomToolView;
// 拍完 闪光效果 提示
@property (nonatomic, weak) UIView *blinkView;
// 拍完 展示 View 容器
@property (nonatomic, weak) UIView *finishedView;
// 拍完 展示 图片 View
@property (nonatomic, weak) UIImageView *finishedPhotoView;
// 转换完的Image
@property (nonatomic, strong) UIImage *finalImage;
// 闪光灯 按钮
@property (nonatomic, weak) UIButton *thunderLightButton;
// 闪光灯 选择 容器 View
@property (nonatomic, weak) UIView *lightTypeView;
@end

@implementation WJPCustomCameraController

#pragma mark -- Core Motion 陀螺仪 确定 照片拍摄方向

- (void)startMotionManager{
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    _motionManager.deviceMotionUpdateInterval = 1/15.0;
    if (_motionManager.deviceMotionAvailable) {
        NSLog(@"Device Motion Available");
        [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue]
                                            withHandler: ^(CMDeviceMotion *motion, NSError *error){
                                                [self performSelectorOnMainThread:@selector(handleDeviceMotion:) withObject:motion waitUntilDone:YES];
                                                
                                            }];
    } else {
        NSLog(@"No device motion on device.");
        [self setMotionManager:nil];
    }
}

- (void)handleDeviceMotion:(CMDeviceMotion *)deviceMotion{
    double x = deviceMotion.gravity.x;
    double y = deviceMotion.gravity.y;
    if (fabs(y) >= fabs(x))
    {
        if (y >= 0){
            // UIDeviceOrientationPortraitUpsideDown;
            self.avCaptureOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            self.my_imageOrientation = UIImageOrientationDown;
        }
        else{
            // UIDeviceOrientationPortrait;
            self.avCaptureOrientation = AVCaptureVideoOrientationPortrait;
            self.my_imageOrientation = UIImageOrientationUp;
        }
    }
    else
    {
        if (x >= 0){
            // UIDeviceOrientationLandscapeRight;
            self.avCaptureOrientation = AVCaptureVideoOrientationLandscapeLeft;
            self.my_imageOrientation = UIImageOrientationLeft;
        }
        else{
            // UIDeviceOrientationLandscapeLeft;
            self.avCaptureOrientation = AVCaptureVideoOrientationLandscapeRight;
            self.my_imageOrientation = UIImageOrientationRight;
        }
    }
}


#pragma mark -- 设置session
- (void)initAVCaptureSession
{
    self.session = [[AVCaptureSession alloc] init];
//    if ([_session canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {
//        [_session setSessionPreset:AVCaptureSessionPreset3840x2160];
//    }
    
    NSError *error;
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.device = device;
    [device lockForConfiguration:nil];
    [device setFlashMode:AVCaptureFlashModeAuto];
    [device unlockForConfiguration];
    
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    // 输出设置， AVVideoCodecJPEG   输出jpeg格式图片
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    if ([self.session canAddOutput:self.stillImageOutput]) {
        [self.session addOutput:self.stillImageOutput];
    }
    
    // 初始化 预览 图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResize];
    self.previewLayer.frame = CGRectMake(0, 0, kMainScreenWidth, kMainScreenHeight);
    self.backView.layer.masksToBounds = YES;
    [self.backView.layer addSublayer:self.previewLayer];
}

#pragma mark -- about UI
- (void)createBaseUI
{
    if (!self.backView) {
        UIView *view = [[UIView alloc] init];
        view.frame = CGRectMake(0, 0, kMainScreenWidth, kMainScreenHeight);
        [self.view addSubview:view];
        self.backView = view;
    }
    if (!_topToolView) {
        UIView *toolMaskView = [[UIView alloc] init];
        toolMaskView.frame = CGRectMake(0, 0, kMainScreenWidth, 52);
        toolMaskView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.69];
        [self.view addSubview:toolMaskView];
        self.topToolView = toolMaskView;
        
        // 关闭页面按钮
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        cancelButton.frame = CGRectMake(0, 0, 24, 24);
        cancelButton.center = CGPointMake(15+24/2, 52/2+8);
        [cancelButton setImage:[UIImage imageNamed:@"icon_close_white"] forState:UIControlStateNormal];
        [cancelButton addTarget:self action:@selector(jp_close:) forControlEvents:UIControlEventTouchUpInside];
        [toolMaskView addSubview:cancelButton];
        
        // 闪光灯按钮
        UIButton *thunderButton = [UIButton buttonWithType:UIButtonTypeCustom];
        thunderButton.frame = CGRectMake(0, 0, 24, 24);
        thunderButton.center = CGPointMake(kMainScreenWidth-15-24/2, 52/2+8);
        [thunderButton setImage:[UIImage imageNamed:@"flashlight_auto"] forState:UIControlStateNormal];
        [thunderButton addTarget:self action:@selector(thunderLightBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        [toolMaskView addSubview:thunderButton];
        self.thunderLightButton = thunderButton;
        
        UIView *btnBgView = [[UIView alloc] init];
        btnBgView.frame = CGRectMake(0, 0, kMainScreenWidth-90*2*kMainScreenWidth/375, 24);
        btnBgView.center = CGPointMake(kMainScreenWidth/2, 52/2+8);
        btnBgView.hidden = YES;
        [toolMaskView addSubview:btnBgView];
        self.lightTypeView = btnBgView;
        
        NSArray *titles = @[@"自动", @"打开", @"关闭"];
        for (NSInteger i = 0; i < 3; ++i) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(0, 0, 30, 24);
            button.center = CGPointMake(24/2+(50+30)*i, CGRectGetHeight(btnBgView.frame)/2);
            button.titleLabel.font = [UIFont systemFontOfSize:14];
            [button setTitle:titles[i] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor yellowColor] forState:UIControlStateSelected];
            button.tag = THUNDER_LIGHT_TYPE_AUTO + i;
            [btnBgView addSubview:button];
            [button addTarget:self action:@selector(selectThunderLightType:) forControlEvents:UIControlEventTouchUpInside];
            if (i == 0) {
                button.selected = YES;
            }
        }
    }
    
    
    if (!_bottomToolView) {
        UIView *toolMaskView = [[UIView alloc] init];
        toolMaskView.frame = CGRectMake(0, kMainScreenHeight-112, kMainScreenWidth, 112);
        toolMaskView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.69];
        [self.view addSubview:toolMaskView];
        self.bottomToolView = toolMaskView;
        
        // 拍照按钮
        UIButton *shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
        shutterButton.frame = CGRectMake(0, 0, 52, 52);
        shutterButton.center = CGPointMake(kMainScreenWidth*0.5, 112 / 2);
        [shutterButton setImage:[UIImage imageNamed:@"takePic"] forState:UIControlStateNormal];
        [shutterButton addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchUpInside];
        [toolMaskView addSubview:shutterButton];
        
        // 相册按钮
        UIButton *libraryButton = [UIButton buttonWithType:UIButtonTypeCustom];
        libraryButton.frame = CGRectMake(0, 0, 23, 23);
        libraryButton.center = CGPointMake(78, 112/2);
        [libraryButton setImage:[UIImage imageNamed:@"album"] forState:UIControlStateNormal];
        [libraryButton addTarget:self action:@selector(jumpToLibrary:) forControlEvents:UIControlEventTouchUpInside];
        [toolMaskView addSubview:libraryButton];
        
        // 切换摄像头按钮
        UIButton *switchDeviceButton = [UIButton buttonWithType:UIButtonTypeCustom];
        switchDeviceButton.frame = CGRectMake(0, 0, 30, 30);
        switchDeviceButton.center = CGPointMake(kMainScreenWidth-50-30/2, 112/2);
        [switchDeviceButton setImage:[UIImage imageNamed:@"reload"] forState:UIControlStateNormal];
        [switchDeviceButton addTarget:self action:@selector(switchDeviceBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
        [toolMaskView addSubview:switchDeviceButton];
    }
    
    if (!self.blinkView) {
        UIView *blinkView = [[UIView alloc] init];
        blinkView.frame = CGRectMake(0, 0, kMainScreenWidth, kMainScreenHeight-112);
        blinkView.backgroundColor = [UIColor blackColor];
        blinkView.userInteractionEnabled = NO;
        blinkView.alpha = 0;
        [self.view addSubview:blinkView];
        self.blinkView = blinkView;
    }
}

- (void)jp_close:(UIButton *)sender
{
//    [self.navigationController popViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

#pragma mark -- 拍完照片之后的动画和处理
- (void)blinkAnimation
{
    [UIView animateKeyframesWithDuration:0.5f delay:0 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
        
        [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:0.2f animations:^{
            self.blinkView.alpha = 0.7;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.2f relativeDuration:0.2f animations:^{
            self.blinkView.alpha = 0;
        }];
        
    } completion:^(BOOL finished) {
        
    }];
}

- (void)finishedTakePic
{
    self.topToolView.hidden = YES;
    self.bottomToolView.hidden = YES;
    self.finishedView.hidden = NO;
}

#pragma mark -- Camera and Library
- (void)thunderLightBtnClicked:(UIButton *)button
{
    self.lightTypeView.hidden = !self.lightTypeView.isHidden;
}

- (void)selectThunderLightType:(UIButton *)button
{
    for (NSInteger i = 0; i < 3; ++i) {
        UIButton *btn = [self.lightTypeView viewWithTag:THUNDER_LIGHT_TYPE_AUTO+i];
        btn.selected = NO;
    }
    button.selected = YES;
    
    [self.device lockForConfiguration:nil];
    if (button.tag == THUNDER_LIGHT_TYPE_AUTO) {
        [self.thunderLightButton setImage:[UIImage imageNamed:@"flashlight_auto"] forState:UIControlStateNormal];
        [self.device setFlashMode:AVCaptureFlashModeAuto];
    } else if (button.tag == THUNDER_LIGHT_TYPE_CLOSE) {
        [self.thunderLightButton setImage:[UIImage imageNamed:@"flashlight_off"] forState:UIControlStateNormal];
        [self.device setFlashMode:AVCaptureFlashModeOff];
    } else if (button.tag == THUNDER_LIGHT_TYPE_OPEN) {
        [self.thunderLightButton setImage:[UIImage imageNamed:@"flashlight_on"] forState:UIControlStateNormal];
        [self.device setFlashMode:AVCaptureFlashModeOn];
    }
    [self.device unlockForConfiguration];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.lightTypeView.hidden = !self.lightTypeView.isHidden;
    });
}

- (void)switchDeviceBtnClicked:(UIButton *)button
{
    button.selected = !button.selected;
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    if (cameraCount > 1) {
        NSError *error;
        //给摄像头的切换添加翻转动画
        CATransition *animation = [CATransition animation];
        animation.duration = .5f;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        animation.type = @"oglFlip";
        
        AVCaptureDevice *newCamera = nil;
        AVCaptureDeviceInput *newInput = nil;
        //拿到另外一个摄像头位置
        AVCaptureDevicePosition position = [[self.videoInput device] position];
        if (position == AVCaptureDevicePositionFront){
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            animation.subtype = kCATransitionFromLeft;//动画翻转方向
        }
        else {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            animation.subtype = kCATransitionFromRight;//动画翻转方向
        }
        //生成新的输入
        newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
        [self.previewLayer addAnimation:animation forKey:nil];
        if (newInput != nil) {
            [self.session beginConfiguration];
            [self.session removeInput:self.videoInput];
            if ([self.session canAddInput:newInput]) {
                [self.session addInput:newInput];
                self.videoInput = newInput;
                
            } else {
                [self.session addInput:self.videoInput];
            }
            [self.session commitConfiguration];
            
        } else if (error) {
            NSLog(@"toggle carema failed, error = %@", error);
        }
    }
    
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ){
            return device;
        }
    return nil;
}

- (void)jumpToLibrary:(UIButton *)button
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)takePhoto:(UIButton *)button
{
    [self blinkAnimation];
    [self finishedTakePic];
    
    AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    [stillImageConnection setVideoOrientation:self.avCaptureOrientation];
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        
        UIImage *image = [UIImage imageWithData:jpegData];
        self.finishedPhotoView.image = image;
    }];
}

- (void)saveToAlbum:(UIImage *)image
{
    image = [self fixOrientation:image];
    ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
    if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied){
        //无权限
        return ;
    }
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error) {
        
    }];
}

- (UIImage *)fixOrientation:(UIImage *)aImage {
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    _finalImage = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return _finalImage;
}

#pragma mark -- 拍完照片，展示
- (void)configFinishedView
{
    if (!_finishedPhotoView) {
        UIView *finishedView = [[UIView alloc] init];
        finishedView.frame = self.view.bounds;
        finishedView.hidden = YES;
        finishedView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.9];
        [self.view addSubview:finishedView];
        self.finishedView = finishedView;
        
        UIImageView *finishedPhotoView = [[UIImageView alloc] init];
        finishedPhotoView.frame = finishedView.bounds;
        finishedPhotoView.contentMode = UIViewContentModeScaleAspectFit;
        [finishedView addSubview:finishedPhotoView];
        self.finishedPhotoView = finishedPhotoView;
        
        UIView *toolMaskView = [[UIView alloc] init];
        toolMaskView.frame = CGRectMake(0, kMainScreenHeight-112, kMainScreenWidth, 112);
        toolMaskView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.69];
        [finishedView addSubview:toolMaskView];
        
        // 重拍按钮
        UIButton *shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
        shutterButton.frame = CGRectMake(0, 0, 31, 24);
        shutterButton.center = CGPointMake(78, 112 / 2);
        [shutterButton setTitle:@"重拍" forState:UIControlStateNormal];
        shutterButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [shutterButton addTarget:self action:@selector(jp_retake:) forControlEvents:UIControlEventTouchUpInside];
        [toolMaskView addSubview:shutterButton];
        
        // 确定按钮
        UIButton *libraryButton = [UIButton buttonWithType:UIButtonTypeCustom];
        libraryButton.frame = CGRectMake(0, 0, 61, 24);
        libraryButton.center = CGPointMake(kMainScreenWidth-20-61, 112/2);
        [libraryButton setTitle:@"使用照片" forState:UIControlStateNormal];
        libraryButton.titleLabel.font = [UIFont systemFontOfSize:14];
        [libraryButton addTarget:self action:@selector(jp_ensure:) forControlEvents:UIControlEventTouchUpInside];
        [toolMaskView addSubview:libraryButton];
    }
}

- (void)jp_retake:(UIButton *)button
{
    // 显示拍照界面的工具栏
    self.topToolView.hidden = NO;
    self.bottomToolView.hidden = NO;
    // 隐藏上次放弃的照片展示
    self.finishedView.hidden = YES;
    // 设置上次放弃的照片，否则下次设置新的照片会有一个切换
    self.finishedPhotoView.image = nil;
}

- (void)jp_ensure:(UIButton *)button
{
    //确定
    [self saveToAlbum:self.finishedPhotoView.image];
    
}

#pragma mark -- Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self createBaseUI];
    
    [self configFinishedView];
    
    [self initAVCaptureSession];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    if (self.session) {
        [self.session startRunning];
    }
    [self startMotionManager];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.session) {
        [self.session stopRunning];
    }
    if (self.motionManager) {
        [self.motionManager stopDeviceMotionUpdates];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate
{
    return NO;
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
