import ApplicationServices
import Foundation
import XCTest
@testable import Ordo

final class AXWindowValidationReadsTests: XCTestCase {
    func testEachValidationFetchesFreshRoleAndFullScreenInOneBatch() {
        var reader = AXWindowValidationReads()
        var batchCalls = 0
        var singleCalls = 0
        for fullScreen in [false, true] {
            let values = reader.read(multiple: { attributes in
                batchCalls += 1
                XCTAssertEqual(attributes, ["AXRole", "AXFullScreen"])
                return (.success, ["AXWindow", fullScreen] as CFArray)
            }, single: { _ in
                singleCalls += 1
                return AXAttributeRead(result: .failure, value: nil)
            })
            XCTAssertEqual(values.role.value as? String, "AXWindow")
            XCTAssertEqual((values.fullScreen.value as? NSNumber)?.boolValue, fullScreen)
        }
        XCTAssertEqual(batchCalls, 2)
        XCTAssertEqual(singleCalls, 0)
    }

    func testUnsupportedBatchFallsBackAndCachesOnlyCapability() {
        for error in [AXError.notImplemented, .attributeUnsupported] {
            var reader = AXWindowValidationReads()
            var batchCalls = 0
            var singleCalls: [String] = []
            for _ in 0..<2 {
                _ = reader.read(multiple: { _ in
                    batchCalls += 1
                    return (error, nil)
                }, single: { attribute in
                    singleCalls.append(attribute)
                    return AXAttributeRead(result: .success, value: kCFBooleanFalse)
                })
            }
            XCTAssertEqual(batchCalls, 1)
            XCTAssertEqual(singleCalls, ["AXRole", "AXFullScreen", "AXRole", "AXFullScreen"])
        }
    }

    func testBatchPreservesPerAttributeErrorsAndNullValues() throws {
        for error in [AXError.invalidUIElement, .cannotComplete, .apiDisabled, .attributeUnsupported, .noValue] {
            var error = error
            let value = try XCTUnwrap(AXValueCreate(.axError, &error))
            var reader = AXWindowValidationReads()
            let values = reader.read(multiple: { _ in (.success, [value, kCFNull!] as CFArray) }, single: { _ in
                XCTFail("批量属性中的错误不能触发重试")
                return AXAttributeRead(result: .success, value: nil)
            })
            XCTAssertEqual(values.role.result, error)
            XCTAssertEqual(values.fullScreen.result, .noValue)
        }
    }

    func testHardBatchFailuresDoNotRetryAndMalformedArraysFailClosed() {
        for error in [AXError.invalidUIElement, .cannotComplete, .apiDisabled, .failure] {
            var reader = AXWindowValidationReads()
            let values = reader.read(multiple: { _ in (error, nil) }, single: { _ in
                XCTFail("硬错误不应再查询目标窗口")
                return AXAttributeRead(result: .success, value: nil)
            })
            XCTAssertEqual(values.role.result, error)
        }
        for array: CFArray? in [nil, [] as CFArray, ["AXWindow"] as CFArray] {
            var reader = AXWindowValidationReads()
            let values = reader.read(multiple: { _ in (.success, array) }, single: { _ in
                XCTFail("无效批量结果不能退化为成功")
                return AXAttributeRead(result: .success, value: nil)
            })
            XCTAssertNotEqual(values.role.result, .success)
        }
    }
}
