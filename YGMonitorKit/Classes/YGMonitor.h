//
//  YGMonitor.h
//
//  Created by wyg on 2020/8/4.
//  Copyright © 2020 wyg. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YGMonitor : NSObject
+(instancetype)shareInstance;

-(void)startMainTheardMonitor;
-(void)stopMainTheardMonitor;
-(void)startFPSMonitoring;
-(void)stopFPSMonitoring;
-(void)startCPUMonitor;
-(void)stopCPUMonitor;
-(void)startMemoryMonitor;
-(void)stopMemoryMonitor;
@end

NS_ASSUME_NONNULL_END
