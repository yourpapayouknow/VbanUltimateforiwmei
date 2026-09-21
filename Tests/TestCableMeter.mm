#import "../Bridge/HeadBridge.h"
#include <cassert>
#include <cmath>
#include <thread>
#include <chrono>

// 验证线缆电平采样读取真实设备
int main() {
    @autoreleasepool {
        VbanBridge *bridge = [VbanBridge shared];
        NSArray<VbanCableDesc *> *cables = [bridge getCables];
        assert(cables.count > 0);
        for (VbanCableDesc *cable in cables) {
            assert([bridge startCableMeter:cable.cableId]);
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            NSArray<NSNumber *> *peaks = [bridge readCablePeaks:cable.cableId];
            assert(peaks.count == cable.channels);
            for (NSNumber *peak in peaks) {
                assert(std::isfinite(peak.floatValue));
                assert(peak.floatValue >= 0);
            }
            [bridge stopCableMeter:cable.cableId];
        }
    }
    return 0;
}
