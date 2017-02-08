//
//  ViewController.m
//  WJPCustomCamera
//
//  Created by 魏鹏 on 2017/2/8.
//  Copyright © 2017年 wjp. All rights reserved.
//

#import "ViewController.h"
#import "WJPCustomCameraController.h"

@interface ViewController ()

@end

@implementation ViewController

- (IBAction)customCameraClicked:(UIButton *)sender {
    WJPCustomCameraController *ccc = [[WJPCustomCameraController alloc] init];
    [self presentViewController:ccc animated:YES completion:^{
        
    }];
}




- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
