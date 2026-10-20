import ApplicationServices
import Foundation

struct AXAttributeRead {
    let result: AXError
    let value: CFTypeRef?
}

/// 每次仍读取窗口角色和全屏状态，只缓存目标是否支持批量读取。
struct AXWindowValidationReads: Sendable {
    private var supportsBatch = true

    mutating func read(
        multiple: ([String]) -> (AXError, CFArray?),
        single: (String) -> AXAttributeRead
    ) -> (role: AXAttributeRead, fullScreen: AXAttributeRead) {
        if supportsBatch {
            let (result, values) = multiple([kAXRoleAttribute as String, "AXFullScreen"])
            if result == .notImplemented || result == .attributeUnsupported {
                // 只缓存 API 能力；不缓存会在手势中变化的窗口状态。
                supportsBatch = false
            } else {
                guard result == .success else {
                    let failure = AXAttributeRead(result: result, value: nil)
                    return (failure, failure)
                }
                guard let values = values as? [CFTypeRef], values.count == 2 else {
                    let failure = AXAttributeRead(result: .failure, value: nil)
                    return (failure, failure)
                }
                return (Self.decode(values[0]), Self.decode(values[1]))
            }
        }
        return (single(kAXRoleAttribute as String), single("AXFullScreen"))
    }

    private static func decode(_ value: CFTypeRef) -> AXAttributeRead {
        if CFGetTypeID(value) == CFNullGetTypeID() {
            return AXAttributeRead(result: .noValue, value: nil)
        }
        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axValue = value as! AXValue
            if AXValueGetType(axValue) == .axError {
                var error = AXError.failure
                guard AXValueGetValue(axValue, .axError, &error), error != .success else {
                    return AXAttributeRead(result: .failure, value: nil)
                }
                return AXAttributeRead(result: error, value: nil)
            }
        }
        return AXAttributeRead(result: .success, value: value)
    }
}
