#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/Common/RingBuffer.hpp"
#include "../Core/Network/JitterBuffer.hpp"
#include <cassert>
#include <iostream>
#include <thread>
#include <vector>

using namespace vban;

// 测试基础环形缓冲读写
void tstbasering() {
    // 验证单线程读写边界与环绕
    RingBuf<float> rb(1024);
    assert(rb.gtcap() == 1024);
    assert(rb.gtavlr() == 0);
    assert(rb.gtavlw() == 1024);

    float src[100];
    for (int i = 0; i < 100; ++i) src[i] = static_cast<float>(i);

    size_t wr = rb.wrblks(src, 100);
    assert(wr == 100);
    assert(rb.gtavlr() == 100);
    assert(rb.gtavlw() == 1024 - 100);

    float dst[150];
    size_t rd = rb.rdblks(dst, 150);
    assert(rd == 100); // 仅有 100 个
    for (int i = 0; i < 100; ++i) {
        assert(dst[i] == static_cast<float>(i));
    }
    // 不足的 50 个被静音填充为 0
    for (int i = 100; i < 150; ++i) {
        assert(dst[i] == 0.0f);
    }
    assert(rb.gtavlr() == 0);

    std::cout << "[PASS] tstbasering: RingBuf single-thread read/write OK\n";
}

// 测试高并发多线程生产消费安全
void tstconcurr() {
    // 验证单读单写多线程无锁连续传输一致性
    RingBuf<int32_t> rb(8192);
    const int total = 100000;
    std::atomic<bool> start{false};

    std::thread prod([&]() {
        while (!start.load()) {}
        int32_t val = 0;
        while (val < total) {
            int32_t chunk[64];
            int count = std::min(64, total - val);
            for (int i = 0; i < count; ++i) chunk[i] = val + i;

            size_t written = 0;
            while (written < static_cast<size_t>(count)) {
                size_t w = rb.wrblks(chunk + written, count - written);
                written += w;
                if (written < static_cast<size_t>(count)) {
                    std::this_thread::yield();
                }
            }
            val += count;
        }
    });

    std::thread cons([&]() {
        while (!start.load()) {}
        int32_t val = 0;
        while (val < total) {
            int32_t chunk[64];
            size_t r = rb.rdblks(chunk, 64);
            for (size_t i = 0; i < r; ++i) {
                assert(chunk[i] == val);
                val++;
            }
            if (r == 0) {
                std::this_thread::yield();
            }
        }
    });

    start.store(true);
    prod.join();
    cons.join();

    std::cout << "[PASS] tstconcurr: 100,000 samples transferred concurrently with 0 data loss\n";
}

// 测试抖动缓冲归一化与预缓冲
void tstjtrbuf() {
    // 验证格式转换与水位充盈平滑
    JtrBuf jb(2, 48000, NetQlt::Fast);

    // 构造一个模拟包 (48kHz, 2ch, 64 samples, 16-bit int)
    int16_t pcm[64 * 2];
    for (int i = 0; i < 64 * 2; ++i) {
        pcm[i] = 16384; // 对应 float 0.5f
    }

    PktInf inf{};
    inf.sr = 48000;
    inf.ch = 2;
    inf.smpls = 64;
    inf.fmt = SmplFmt::Int16;
    inf.pyldsz = sizeof(pcm);
    inf.pyld = reinterpret_cast<const uint8_t*>(pcm);

    // 压入几个包填充预缓冲
    for (int i = 0; i < 15; ++i) {
        assert(jb.pshpkt(inf));
    }

    assert(jb.gtfill() > 0.0f);

    float out[128];
    size_t popped = jb.popblks(out, 128);
    assert(popped == 128);
    for (int i = 0; i < 128; ++i) {
        assert(std::abs(out[i] - 0.5f) < 0.001f);
    }

    std::cout << "[PASS] tstjtrbuf: JitterBuffer normalization and playback OK\n";
}

int main() {
    std::cout << "Running RingBuffer and JitterBuffer Tests...\n";
    tstbasering();
    tstconcurr();
    tstjtrbuf();
    std::cout << "All RingBuffer Tests PASSED successfully!\n";
    return 0;
}
