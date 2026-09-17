#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/VBAN/Protocol.hpp"
#include "../Core/VBAN/Parser.hpp"
#include "../Core/VBAN/Packetizer.hpp"
#include "../Core/Network/UdpSocket.hpp"
#include "../Core/Network/Demuxer.hpp"
#include <cassert>
#include <iostream>
#include <thread>
#include <atomic>

using namespace vban;

// 测试本机UDP回环收发与多流解复用
void tstloopback() {
    // 验证真实套接字多线程数据通信与统计准确性
    const uint16_t port = 16980;
    UdpSck rx_sck;
    assert(rx_sck.initsck());
    assert(rx_sck.bndsck(port));

    StrmDmx dmx;
    std::atomic<uint32_t> rx_cnt{0};
    dmx.regstrm("LoopStrm", "127.0.0.1", [&](const PktInf& inf, const char*, uint16_t) {
        if (inf.sr == 48000 && inf.ch == 2) {
            rx_cnt++;
        }
    });

    std::atomic<bool> running{true};
    std::thread rx_th([&]() {
        uint8_t buf[2048];
        char sip[32];
        uint16_t sprt = 0;
        while (running.load()) {
            ssize_t n = rx_sck.rcvsck(buf, sizeof(buf), sip, &sprt);
            if (n > 0) {
                dmx.dmxpkt(buf, n, sip, sprt);
            } else {
                std::this_thread::sleep_for(std::chrono::microseconds(100));
            }
        }
    });

    // 发送端
    UdpSck tx_sck;
    assert(tx_sck.initsck());
    const int total_pkts = 50;
    uint8_t pktbuf[500];
    int16_t pcm[64 * 2]{0};

    for (int i = 0; i < total_pkts; ++i) {
        size_t sz = bldpkt(pktbuf, sizeof(pktbuf), "LoopStrm", 48000, 2, 64,
                           SmplFmt::Int16, static_cast<uint32_t>(i), pcm, sizeof(pcm));
        assert(sz > 0);
        ssize_t sent = tx_sck.sndsck("127.0.0.1", port, pktbuf, sz);
        assert(sent == static_cast<ssize_t>(sz));
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }

    // 等待接收完毕
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    running.store(false);
    rx_th.join();

    assert(rx_cnt.load() == total_pkts);
    auto snaps = dmx.gtsnaps();
    assert(!snaps.empty());
    assert(snaps[0].pktcnt == total_pkts);
    assert(snaps[0].lostcnt == 0);
    assert(snaps[0].dupcnt == 0);
    assert(snaps[0].stt == StrmStt::Active);

    std::cout << "[PASS] tstloopback: Received " << rx_cnt.load() << " / " << total_pkts << " packets cleanly over UDP!\n";
}

int main() {
    std::cout << "Running UDP Loopback Integration Test...\n";
    tstloopback();
    std::cout << "All UDP Loopback Tests PASSED successfully!\n";
    return 0;
}
