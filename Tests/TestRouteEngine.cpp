#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/Common/RingBuffer.hpp"
#include "../Core/Routing/RouteEngine.hpp"
#include <cassert>
#include <cmath>
#include <iostream>

using namespace vban;

// 测试接收流样本写入与回放读取
void tstrxbuf() {
    // 验证接收流缓冲写入后可按序读出
    RtEngn eng;
    eng.rstbuf("MainMusic", 2, 48000);

    const float in[4] = {0.1f, 0.2f, 0.3f, 0.4f};
    assert(eng.wrrx("MainMusic", in, 4));

    float out[4]{};
    assert(eng.rdrx("MainMusic", out, 4) == 4);
    for (int i = 0; i < 4; ++i) {
        assert(std::abs(out[i] - in[i]) < 1e-6f);
    }

    // 未登记的流不得产生数据
    float none[4]{};
    assert(eng.rdrx("Unknown", none, 4) == 0);
    assert(none[0] == 0.0f);

    std::cout << "[PASS] tstrxbuf: RX playback buffer round-trip OK\n";
}

// 测试接收流到输出设备的独占指派
void tstrxdev() {
    // 验证每条接收流绑定唯一输出设备
    RtEngn eng;
    assert(eng.gtrxdev("MainMusic").empty());

    eng.setrxdev("MainMusic", "BlackHole16ch_UID", 2, 48000);
    eng.setrxdev("Mic-mac",   "BlackHole2ch_UID",  1, 48000);

    assert(eng.gtrxdev("MainMusic") == "BlackHole16ch_UID");
    assert(eng.gtrxdev("Mic-mac")   == "BlackHole2ch_UID");

    // 解除指派后查询必须为空
    eng.clrrxdev("MainMusic");
    assert(eng.gtrxdev("MainMusic").empty());
    assert(eng.gtrxdev("Mic-mac") == "BlackHole2ch_UID");

    std::cout << "[PASS] tstrxdev: per-stream output device assignment OK\n";
}

// 测试发送流到输入设备的独占指派与采集
void tsttxdev() {
    // 验证发送流绑定输入设备并承载采集样本
    RtEngn eng;
    eng.settxdev("StreamOut", "Mic_Mac", 1, 48000);
    assert(eng.gttxdev("StreamOut") == "Mic_Mac");

    const float cap[4] = {0.5f, 0.6f, 0.7f, 0.8f};
    assert(eng.wrtx("StreamOut", cap, 4));

    float out[4]{};
    assert(eng.rdtx("StreamOut", out, 4) == 4);
    for (int i = 0; i < 4; ++i) {
        assert(std::abs(out[i] - cap[i]) < 1e-6f);
    }

    // 接收侧指派不得影响发送侧
    assert(eng.gtrxdev("StreamOut").empty());

    std::cout << "[PASS] tsttxdev: per-stream input device capture OK\n";
}

// 测试多流并发时的缓冲隔离
void tstisolt() {
    // 验证多路流各自缓冲互不串扰
    RtEngn eng;
    eng.rstbuf("StreamA", 1, 48000);
    eng.rstbuf("StreamB", 1, 48000);

    const float a[2] = {0.11f, 0.12f};
    const float b[2] = {0.91f, 0.92f};
    assert(eng.wrrx("StreamA", a, 2));
    assert(eng.wrrx("StreamB", b, 2));

    float out[2]{};
    assert(eng.rdrx("StreamA", out, 2) == 2);
    assert(std::abs(out[0] - 0.11f) < 1e-6f);
    assert(std::abs(out[1] - 0.12f) < 1e-6f);

    assert(eng.rdrx("StreamB", out, 2) == 2);
    assert(std::abs(out[0] - 0.91f) < 1e-6f);

    // 清空后全部归零
    eng.clrall();
    assert(eng.gtrxdev("StreamA").empty());
    assert(eng.rdrx("StreamA", out, 2) == 0);

    std::cout << "[PASS] tstisolt: concurrent stream buffers isolated OK\n";
}

// 测试欠载时回放必须静音补齐
void tstundr() {
    // 验证缓冲不足时不产生残留噪声
    RtEngn eng;
    eng.rstbuf("MainMusic", 1, 48000);

    const float one[1] = {0.75f};
    assert(eng.wrrx("MainMusic", one, 1));

    float out[4] = {9.0f, 9.0f, 9.0f, 9.0f};
    const size_t got = eng.rdrx("MainMusic", out, 4);
    assert(got == 1);
    assert(std::abs(out[0] - 0.75f) < 1e-6f);
    for (int i = 1; i < 4; ++i) {
        assert(out[i] == 0.0f);
    }

    std::cout << "[PASS] tstundr: underrun zero-fills remainder OK\n";
}

int main() {
    std::cout << "Running Stream Device Assignment Tests...\n";
    tstrxbuf();
    tstrxdev();
    tsttxdev();
    tstisolt();
    tstundr();
    std::cout << "All Stream Device Assignment Tests PASSED successfully!\n";
    return 0;
}
