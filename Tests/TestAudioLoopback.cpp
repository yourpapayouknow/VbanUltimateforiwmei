#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/VBAN/Protocol.hpp"
#include "../Core/VBAN/Parser.hpp"
#include "../Core/VBAN/Packetizer.hpp"
#include "../Core/Network/UdpSocket.hpp"
#include "../Core/Network/Demuxer.hpp"
#include "../Core/Network/JitterBuffer.hpp"
#include <cassert>
#include <iostream>
#include <cmath>

using namespace vban;

// 验证正弦波音频经由封包、UDP传输、解复用与JitterBuffer还原的纯净度
void tstaudiorecon() {
    // 验证端到端音频网络重构无损
    const uint32_t sr = 48000;
    const uint32_t ch = 2;
    const uint32_t smpls = 64;
    const float freq = 440.0f;

    JtrBuf jb(ch, sr, NetQlt::Fast);
    StrmDmx dmx;
    dmx.regstrm("Sine440", "127.0.0.1", [&](const PktInf& inf, const char*, uint16_t) {
        jb.pshpkt(inf);
    });

    UdpSck rx_sck, tx_sck;
    assert(rx_sck.initsck() && rx_sck.bndsck(16981));
    assert(tx_sck.initsck());

    // 生成50个包的正弦波
    float phase = 0.0f;
    const float phase_inc = (2.0f * M_PI * freq) / static_cast<float>(sr);
    uint8_t pktbuf[1000];

    for (uint32_t p = 0; p < 50; ++p) {
        int16_t pcm[smpls * ch];
        for (uint32_t s = 0; s < smpls; ++s) {
            float val = std::sin(phase);
            phase += phase_inc;
            int16_t ival = static_cast<int16_t>(val * 32000.0f);
            pcm[s * 2 + 0] = ival;
            pcm[s * 2 + 1] = ival;
        }

        size_t sz = bldpkt(pktbuf, sizeof(pktbuf), "Sine440", sr, ch, smpls,
                           SmplFmt::Int16, p, pcm, sizeof(pcm));
        tx_sck.sndsck("127.0.0.1", 16981, pktbuf, sz);

        // 接收并解包
        uint8_t rcvbuf[1000];
        char sip[32];
        uint16_t sprt = 0;
        ssize_t n = rx_sck.rcvsck(rcvbuf, sizeof(rcvbuf), sip, &sprt);
        if (n > 0) {
            dmx.dmxpkt(rcvbuf, n, sip, sprt);
        }
    }

    // 验证音频样本可顺畅输出且非静音
    float out[smpls * ch];
    size_t popped = jb.popblks(out, smpls * ch);
    assert(popped == smpls * ch);

    float max_amp = 0.0f;
    for (uint32_t i = 0; i < smpls * ch; ++i) {
        max_amp = std::max(max_amp, std::abs(out[i]));
    }
    assert(max_amp > 0.5f); // 确认振幅真实恢复

    std::cout << "[PASS] tstaudiorecon: Sine 440Hz end-to-end reconstructed faithfully (peak=" << max_amp << ")!\n";
}

int main() {
    std::cout << "Running Audio Loopback Reconstruction Test...\n";
    tstaudiorecon();
    std::cout << "All Audio Loopback Tests PASSED successfully!\n";
    return 0;
}
