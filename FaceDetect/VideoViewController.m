//
//  VideoViewController.m
//  openCV-Practice
//
//  Created by Realank on 16/5/3.
//  Copyright © 2016年 realank. All rights reserved.
//

#import "VideoViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface VideoViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>{
//    CIFilter *_colorCube;
    CIFilter *_vignatte;
//    CIFilter *_blend;
//    CIFilter *_sourceOver;
    CIContext* _ciContext;
    
    CALayer* _faceLayer;
    CALayer* _leftEyeLayer;
    CALayer* _rightEyeLayer;
    CALayer* _mouthLayer;
}

@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设备之间的数据传递
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;//照片输出流
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层
@property (weak, nonatomic) IBOutlet UIView *viewContainer;

@property (weak, nonatomic) IBOutlet UIImageView *resultImage;
@property (nonatomic, strong) CAShapeLayer *shapeLayer;
@end

@implementation VideoViewController

#pragma mark - 控制器视图方法
- (void)viewDidLoad {
    [super viewDidLoad];
    
    _shapeLayer = [CAShapeLayer layer];
    _shapeLayer.frame = _resultImage.bounds;
    [_resultImage.layer addSublayer:_shapeLayer];
    _shapeLayer.lineWidth = 3;
    _shapeLayer.strokeColor = [UIColor redColor].CGColor;
    _shapeLayer.fillColor = [UIColor clearColor].CGColor;

    
    _resultImage.contentMode = UIViewContentModeScaleToFill;
    [self setupFilters];
}
-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPresetMedium;
    }
    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];//取得前置摄像头
    if (!captureDevice) {
        NSLog(@"取得前置摄像头时出现问题.");
        return;
    }
    
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    //初始化设备输出对象，用于获得输出数据
    _captureStillImageOutput=[[AVCaptureStillImageOutput alloc]init];
    NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [_captureStillImageOutput setOutputSettings:outputSettings];//输出设置
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
    }
    
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureStillImageOutput]) {
//        [_captureSession addOutput:_captureStillImageOutput];
    }
    
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc]
                                               init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary
                                   dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    [_captureSession addOutput:captureOutput];
    
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer=self.viewContainer.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=layer.bounds;
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    //将视频预览层添加到界面中
    //[layer addSublayer:_captureVideoPreviewLayer];
    [layer insertSublayer:_captureVideoPreviewLayer below:_shapeLayer];
    
    [self addNotificationToCaptureDevice:captureDevice];
}

- (void)viewDidLayoutSubviews{
    _captureVideoPreviewLayer.frame=self.viewContainer.layer.bounds;
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.captureSession startRunning];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
}

-(void)dealloc{
    [self removeNotification];
}
#pragma mark - UI方法

-(void)setupFilters{
    _vignatte = [CIFilter filterWithName:@"CIVignette"];
    [_vignatte setValue:@3.0 forKey:@"inputIntensity"];
    [_vignatte setValue:@2.0 forKey:@"inputRadius"];
    _ciContext = [CIContext contextWithOptions:nil];
}

#pragma mark - 通知
/**
 *  给输入设备添加通知
 */
-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}

-(void)addNotificationToCaptureSession:(AVCaptureSession *)captureSession{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //会话出错
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:captureSession];
}

/**
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
-(void)deviceConnected:(NSNotification *)notification{
    NSLog(@"设备已连接...");
}
/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
-(void)deviceDisconnected:(NSNotification *)notification{
    NSLog(@"设备已断开.");
}
/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */
-(void)areaChange:(NSNotification *)notification{
    NSLog(@"捕获区域改变...");
}

/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSLog(@"会话发生错误.");
}

#pragma mark - 私有方法

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  设置闪光灯模式
 *
 *  @param flashMode 闪光灯模式
 */
-(void)setFlashMode:(AVCaptureFlashMode )flashMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFlashModeSupported:flashMode]) {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}
/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}
/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}
/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}



#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    static int proccessing = 0;
    if (proccessing) {
        return;
    }
    proccessing = 1;
    
    NSLog(@"current thread:%@",[NSThread currentThread]);

    
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage* image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    image = [image imageByApplyingTransform:CGAffineTransformMakeRotation(-M_PI/2.0)];
    CGPoint origin = [image extent].origin;
    image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(-origin.x, -origin.y)];
    
    [_vignatte setValue:image forKey:@"inputImage"];
    image = _vignatte.outputImage;
    
    
    
#pragma mark Attempt1
//    UIImage* uiImage = [UIImage imageWithCIImage:image];
    //
#pragma mark Attempt2
    CGImageRef cgImage = [_ciContext createCGImage:image fromRect:[image extent]];
    UIImage* uiImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    NSDictionary* opts = [NSDictionary dictionaryWithObject:
                          CIDetectorAccuracyLow forKey:CIDetectorAccuracy];
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:opts];
    NSArray* features = [detector featuresInImage:image];
    if (features.count == 0) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _faceLayer.hidden = YES;
            _leftEyeLayer.hidden = YES;
            _rightEyeLayer.hidden = YES;
            _mouthLayer.hidden = YES;
        });
        
    }
    for (CIFaceFeature *faceFeature in features){
        
        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat faceWidth = self.resultImage.bounds.size.width/4;
            if (!_faceLayer) {
                _faceLayer = [[CALayer alloc]init];
                _faceLayer.bounds = CGRectMake(0, 0, 1, 1);
                _faceLayer.borderWidth = 1;
                _faceLayer.borderColor = [UIColor redColor].CGColor;
                [self.resultImage.layer addSublayer:_faceLayer];
            }
            _faceLayer.hidden = NO;
            _faceLayer.frame = [self verticalFlipFromRect:faceFeature.bounds inSize:image.extent.size toSize:self.resultImage.bounds.size];
            
            if(faceFeature.hasLeftEyePosition) {
                if (!_leftEyeLayer) {
                    _leftEyeLayer = [[CALayer alloc]init];
                    _leftEyeLayer.bounds = CGRectMake(0,0, faceWidth*0.3, faceWidth*0.3);
                    _leftEyeLayer.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.3].CGColor;
                    _leftEyeLayer.cornerRadius = faceWidth*0.15;
                    [self.resultImage.layer addSublayer:_leftEyeLayer];
                }
                _leftEyeLayer.hidden = NO;
                _leftEyeLayer.position =[self verticalFlipFromPoint:faceFeature.leftEyePosition inSize:image.extent.size toSize:self.resultImage.bounds.size];
            }else{
                _leftEyeLayer.hidden = YES;
            }
            
            if(faceFeature.hasRightEyePosition) {
                if (!_rightEyeLayer) {
                    _rightEyeLayer = [[CALayer alloc]init];
                    _rightEyeLayer.bounds = CGRectMake(0,0, faceWidth*0.3, faceWidth*0.3);
                    _rightEyeLayer.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.3].CGColor;
                    _rightEyeLayer.cornerRadius = faceWidth*0.15;
                    [self.resultImage.layer addSublayer:_rightEyeLayer];
                }
                _rightEyeLayer.hidden = NO;
                _rightEyeLayer.position =[self verticalFlipFromPoint:faceFeature.rightEyePosition inSize:image.extent.size toSize:self.resultImage.bounds.size];
            }else{
                _rightEyeLayer.hidden = YES;
            }
            
            if(faceFeature.hasMouthPosition) {
                if (!_mouthLayer) {
                    _mouthLayer = [[CALayer alloc]init];
                    _mouthLayer.bounds = CGRectMake(0,0, faceWidth*0.3, faceWidth*0.3);
                    _mouthLayer.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.3].CGColor;
                    _mouthLayer.cornerRadius = faceWidth*0.15;
                    [self.resultImage.layer addSublayer:_mouthLayer];
                }
                _mouthLayer.hidden = NO;
                _mouthLayer.position =[self verticalFlipFromPoint:faceFeature.mouthPosition inSize:image.extent.size toSize:self.resultImage.bounds.size];
            }else{
                _mouthLayer.hidden = YES;
            }


        });
        
    }

    
    [_vignatte setValue:nil forKey:@"inputImage"];
    uiImage = [self fixOrientation:uiImage];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.resultImage.image = uiImage;
        proccessing = 0;
    });

    
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
    UIImage *img = [UIImage imageWithCGImage:cgimg];  
    CGContextRelease(ctx);  
    CGImageRelease(cgimg);  
    return img;  
}

- (CGRect)convertRectFromRect:(CGRect)fromRect toSize:(CGSize)size{

    return CGRectMake(size.width*fromRect.origin.x, size.height*fromRect.origin.y,size.width*fromRect.size.width, size.height*fromRect.size.height);
}

-(CGRect)verticalFlipFromRect:(CGRect)originalRect inSize:(CGSize)originalSize toSize:(CGSize)finalSize{
    CGRect finalRect = originalRect;
    finalRect.origin.y = originalSize.height - finalRect.origin.y - finalRect.size.height;
    CGFloat hRate = finalSize.width / originalSize.width;
    CGFloat vRate = finalSize.height / originalSize.height;
    finalRect.origin.x *= hRate;
    finalRect.origin.y *= vRate;
    finalRect.size.width *= hRate;
    finalRect.size.height *= vRate;
    return finalRect;
    
}

- (CGPoint)verticalFlipFromPoint:(CGPoint)originalPoint inSize:(CGSize)originalSize toSize:(CGSize)finalSize{
    CGPoint finalPoint = originalPoint;
    finalPoint.y = originalSize.height - finalPoint.y;
    CGFloat hRate = finalSize.width / originalSize.width;
    CGFloat vRate = finalSize.height / originalSize.height;
    finalPoint.x *= hRate;
    finalPoint.y *= vRate;
    return finalPoint;
    
}


@end
