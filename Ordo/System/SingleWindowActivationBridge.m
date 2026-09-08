#import "SingleWindowActivationBridge.h"

const OptionBits OrdoSingleWindowActivationOptions =
    kSetFrontProcessFrontWindowOnly | kSetFrontProcessCausedByUser;

// 公开旧 API 在 Swift 中不可用；用最小桥接保留仅带起前窗的语义，不改用整 App 激活。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
OSStatus OrdoActivateFrontWindowForPID(pid_t pid) {
    ProcessSerialNumber process = {0, 0};
    OSStatus result = GetProcessForPID(pid, &process);
    if (result != noErr) {
        return result;
    }
    return SetFrontProcessWithOptions(&process, OrdoSingleWindowActivationOptions);
}
#pragma clang diagnostic pop
