//
//  ViewController.m
//  FaceDetect
//
//  Created by Realank on 16/5/23.
//  Copyright © 2016年 Relaank. All rights reserved.
//

#import "ViewController.h"
#import <CoreImage/CoreImage.h>
#import "VideoViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIImage* image = [UIImage imageNamed:@"face"];
    UIImageView *testImage = [[UIImageView alloc] initWithImage: image];
    
    [testImage setFrame:CGRectMake(0, 100, 300,300)];
    [self.view addSubview:testImage];
    
    CIImage* ciimage = [CIImage imageWithCGImage:image.CGImage];
    NSDictionary* opts = [NSDictionary dictionaryWithObject:
                          CIDetectorAccuracyHigh forKey:CIDetectorAccuracy];
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:opts];
    NSArray* features = [detector featuresInImage:ciimage];
    for (CIFaceFeature *faceFeature in features){
        
        CGFloat faceWidth = testImage.bounds.size.width/4;
        
        UIView* faceView = [[UIView alloc] initWithFrame:[self verticalFlipFromRect:faceFeature.bounds inSize:image.size toSize:testImage.bounds.size]];
        faceView.layer.borderWidth = 1;
        faceView.layer.borderColor = [[UIColor redColor] CGColor];
        [testImage addSubview:faceView];
        
        if(faceFeature.hasLeftEyePosition) {
            UIView* leftEyeView = [[UIView alloc] initWithFrame:
                                   CGRectMake(0,0, faceWidth*0.3, faceWidth*0.3)];
            [leftEyeView setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
            [leftEyeView setCenter:[self verticalFlipFromPoint:faceFeature.leftEyePosition inSize:image.size toSize:testImage.bounds.size]];
            leftEyeView.layer.cornerRadius = faceWidth*0.15;
            [testImage addSubview:leftEyeView];
        }
        
        // 标出右眼
        if(faceFeature.hasRightEyePosition) {
            UIView* rightEyeView = [[UIView alloc] initWithFrame:
                               CGRectMake(0,0, faceWidth*0.3, faceWidth*0.3)];
            [rightEyeView setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
            [rightEyeView setCenter:[self verticalFlipFromPoint:faceFeature.rightEyePosition inSize:image.size toSize:testImage.bounds.size]];
            rightEyeView.layer.cornerRadius = faceWidth*0.15;
            [testImage  addSubview:rightEyeView];
        }
        
        if(faceFeature.hasMouthPosition) {
            UIView* mouth = [[UIView alloc] initWithFrame:
                             CGRectMake(faceFeature.mouthPosition.x-faceWidth*0.2,
                                        faceFeature.mouthPosition.y-faceWidth*0.2, faceWidth*0.4, faceWidth*0.4)];
            [mouth setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:0.3]];
            [mouth setCenter:[self verticalFlipFromPoint:faceFeature.mouthPosition inSize:image.size toSize:testImage.bounds.size]];
            mouth.layer.cornerRadius = faceWidth*0.2;
            [testImage addSubview:mouth];
        }
    }
    
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    VideoViewController* vc = [[VideoViewController alloc]init];
    [self presentViewController:vc animated:YES completion:nil];
}
@end



