//
//  YGMonitor.m
//
//  Created by wyg on 2020/8/4.
//  Copyright © 2020 wyg. All rights reserved.
//

#import "YGMonitor.h"
#import "YGCallStack.h"
#import <UIKit/UIKit.h>


@interface YGMonitor()
{
    CFRunLoopObserverRef RLObserver;

    CFRunLoopActivity currentRunloopActivity;
    dispatch_semaphore_t semaphore;
    
    CADisplayLink *_link;
    NSTimeInterval _lastTime;
    float _fps;
    int count ;
    
    dispatch_source_t _CPUtimer;
    dispatch_source_t _memorytimer;

}



@end
@implementation YGMonitor
+ (instancetype)shareInstance{
    static dispatch_once_t onceToken;
    static YGMonitor *monitor;
    dispatch_once(&onceToken, ^{
        monitor = [YGMonitor new];
    });
    return monitor;
}


- (void)startFPSMonitoring {
    if (_link)
    {
        return;
    }
    
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(fpsDisplayLinkAction:)];
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopFPSMonitoring
{
    if (_link)
    {
        count = 0;
        _lastTime = 0;
        [_link removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_link invalidate];
        _link = nil;
    }
}

- (void)fpsDisplayLinkAction:(CADisplayLink *)link {
    if (_lastTime == 0) {
        _lastTime = link.timestamp;
        return;
    }
    
    count++;
    NSTimeInterval delta = link.timestamp - _lastTime;
    if (delta < 1) return;
    
    
    _lastTime = link.timestamp;
    _fps = count / delta;
    count = 0;
    
    NSLog(@"FPS = %.0f",_fps);

}

- (void)startCPUMonitor
{
 
    if (_CPUtimer)
    {
        return;
    }
    
    NSTimeInterval period = 1.0;
     
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _CPUtimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_CPUtimer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_CPUtimer, ^{
     
       
            [self getCPUUsage];
      
        
    });
        
      dispatch_resume(_CPUtimer);
  
}

-(void)stopCPUMonitor
{
    if(_CPUtimer){
        dispatch_source_cancel(_CPUtimer);
        _CPUtimer = nil;
    }
}



-(void)startMemoryMonitor
{
    if (_memorytimer)
    {
        return;
    }
     NSTimeInterval period = 1.0;
       
      dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
      _memorytimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
      dispatch_source_set_timer(_memorytimer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
      dispatch_source_set_event_handler(_memorytimer, ^{
       
         
              [self getMemoryUsage];
        
          
      });
          
        dispatch_resume(_memorytimer);
}

- (void)stopMemoryMonitor
{
    if(_memorytimer){
        dispatch_source_cancel(_memorytimer);
        _memorytimer = nil;
    }
}


-(void)getCPUUsage
{
    thread_act_array_t threads; //int 组成的数组比如 thread[1] = 5635
    mach_msg_type_number_t threadCount = 0; //mach_msg_type_number_t 是 int 类型
    const task_t thisTask = mach_task_self();
    //根据当前 task 获取所有线程
    kern_return_t kr = task_threads(thisTask, &threads, &threadCount);
    
    if (kr == KERN_SUCCESS) {
        
        integer_t cpuUsage = 0;
        // 遍历所有线程
        for (int i = 0; i < threadCount; i++) {
            
            thread_info_data_t threadInfo;
            thread_basic_info_t threadBaseInfo;
            mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
            
            if (thread_info((thread_act_t)threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount) == KERN_SUCCESS) {
                // 获取 CPU 使用率
                threadBaseInfo = (thread_basic_info_t)threadInfo;
                if (!(threadBaseInfo->flags & TH_FLAGS_IDLE)) {
                    cpuUsage += threadBaseInfo->cpu_usage;
                }
            }
        }
        assert(vm_deallocate(mach_task_self(), (vm_address_t)threads, threadCount * sizeof(thread_t)) == KERN_SUCCESS);
        NSLog(@"CPU使用率为：%d%%",cpuUsage/10);
        
    }
}

-(void)getMemoryUsage
{
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if (result == KERN_SUCCESS)
    {
        NSLog(@"内存使用为%llu Mb",vmInfo.phys_footprint / (1024 * 1024));
    }
  
  
}



- (void)startMainTheardMonitor{
    
    if (RLObserver) {
        return;
    }
    

    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL,NULL};
    
   
    RLObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, &mObservercallBack, &context);
    
    //向主线程添加 观察者
    CFRunLoopRef mainLoop = CFRunLoopGetMain();
    CFRunLoopAddObserver(mainLoop, RLObserver, kCFRunLoopCommonModes);
    
    //创建子线程开始监控
//    dispatch_queue_t monitorQueue = dispatch_queue_create("com.ym.monitorQueue", DISPATCH_QUEUE_CONCURRENT);
    
    //创建同步信号量
    semaphore = dispatch_semaphore_create(0);
    
    //创建子线程监控
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //子线程开启一个持续的 loop 用来进行监控
        while (YES)
        {
            
             //超时时间设置0.06秒
                dispatch_time_t outTimer = dispatch_time(DISPATCH_TIME_NOW, 0.06 * NSEC_PER_SEC);
            
            //信号量>1或者超时会继续向下进行，否则等待（dispatch_semaphore_wait执行后信号量会-1）
            long semaphoreWait = dispatch_semaphore_wait(self->semaphore, outTimer);
            
            //返回值不为0时表示发生了超时
            if (semaphoreWait != 0)
            {
                if (!self->RLObserver) {
                    self->semaphore = 0;
                    self->currentRunloopActivity = 0;
                    return;
                }
                
                //如果发生超时是在BeffaoreSources 和 AfterWaiting 这两个状态，表示主线程有卡顿
                if (self->currentRunloopActivity == kCFRunLoopBeforeSources || self->currentRunloopActivity == kCFRunLoopAfterWaiting)
                {
                   
//                  NSString *str =  [YGCallStack callStackWithType:YGCallStackTypeMain];

//             NSData *lagData = [[[PLCrashReporter alloc]
//                                                       initWithConfiguration:[[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll]] generateLiveReport];
//             // 转换成 PLCrashReport 对象
//             PLCrashReport *lagReport = [[PLCrashReport alloc] initWithData:lagData error:NULL];
//             // 进行字符串格式化处理
//             NSString *lagReportString = [PLCrashReportTextFormatter stringValueForCrashReport:lagReport withTextFormat:PLCrashReportTextFormatiOS];
//             //将字符串上传服务器
//             NSLog(@"主线程卡顿: \n %@",lagReportString);
                    
                    //将堆栈信息上报服务器的代码放到这里
                  
                }
            }
           
        }
    });
    
}

- (void)stopMainTheardMonitor{
    
    if (!RLObserver) {
        return;
    }
    
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), RLObserver, kCFRunLoopCommonModes);
    CFRelease(RLObserver);
    RLObserver = NULL;
    
}

#pragma mark -Private Method

/**
 * 观察者回调函数
 */
static void  mObservercallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    //每一次监测到Runloop发送通知的时候，都会调用此函数
    //在此过程修改当前的 RunloopActivity 状态，发送同步信号。
    YGMonitor *monitor = (__bridge YGMonitor *)info;
    
    monitor->currentRunloopActivity = activity;
    dispatch_semaphore_t tempSemaphore = monitor->semaphore;
    //runloop状态改变，信号量+1，信号量>1时候会触发dispatch_semaphore_wait
    dispatch_semaphore_signal(tempSemaphore);
}
@end

