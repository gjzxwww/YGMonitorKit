//
//  YGViewController.m
//  YGMonitorKit
//
//  Created by gjzxwyg@163.com on 08/06/2020.
//  Copyright (c) 2020 gjzxwyg@163.com. All rights reserved.
//

#import "YGViewController.h"
#import <YGMonitor.h>

@interface YGViewController ()

@end

@implementation YGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    
    YGMonitor *monitor = [YGMonitor shareInstance];
    [monitor startMainTheardMonitor];
    [monitor startMemoryMonitor];
    [monitor startCPUMonitor];
    [monitor startFPSMonitoring];
    

}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
