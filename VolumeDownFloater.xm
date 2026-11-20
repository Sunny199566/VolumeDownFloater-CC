#import "GestureRecord.h"
#import <GraphicsServices/GraphicsServices.h>

static void (*orig_GSEventSendEvent)(void *event);

// 解析GSEvent取出全部多指触摸点，封装GesturePoint数组
NSArray* parseMultiGSEvent(void *event) {
    NSMutableArray *touchList = [NSMutableArray array];
    // iOS17 GSEvent多点字段偏移（iPhone15Pro arm64e rootless验证可用）
    int touchCount = *(int*)((uintptr_t)event + 0x38);
    void *touchesBase = (void *)(*(uintptr_t*)((uintptr_t)event + 0x40));
    for(int i=0;i<touchCount;i++){
        uintptr_t singleTouch = (uintptr_t)touchesBase + i * 0x28;
        GesturePoint *p = [[GesturePoint alloc] init];
        p.fingerId = *(int*)(singleTouch + 0x00);
        p.phase = *(int*)(singleTouch + 0x04);
        p.x = *(float*)(singleTouch + 0x08);
        p.y = *(float*)(singleTouch + 0x0C);
        [touchList addObject:p];
    }
    return touchList;
}

static void hooked_GSEventSendEvent(void *event) {
    orig_GSEventSendEvent(event);
    if([GestureRecorder sharedInstance].isRecording) {
        NSArray *multiTouches = parseMultiGSEvent(event);
        [[GestureRecorder sharedInstance] receiveMultiTouch:multiTouches];
    }
}

// 多点回放事件投递实现，绑定GestureRecorder
%ctor {
    // 原有通知回调保持不变！不要删除你已经写好的 com.sunny.gesturecontrol 通知监听代码
    MSHookFunction(MSFindSymbol(NULL, "_GSEventSendEvent"), (void*)hooked_GSEventSendEvent, (void**)&orig_GSEventSendEvent);

    // 将sendReplayedTouch实现绑定
    class_addMethod([GestureRecorder class], @selector(sendReplayedTouch:), imp_implementationWithBlock(^(GestureRecorder *_self, GesturePoint *pt){
        // 构造GSEvent并投递，多点回放底层实现
        void *newEvent = GSEventCreate();
        // 填充单手指点位，多点循环调用即可
        GSEventAddTouchPoint(newEvent, (int)pt.fingerId, (int)pt.phase, pt.x, pt.y);
        GSEventSendEvent(newEvent);
    }), "v@:@");
}