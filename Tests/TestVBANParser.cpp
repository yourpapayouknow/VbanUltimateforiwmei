#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/VBAN/Protocol.hpp"
#include "../Core/VBAN/Parser.hpp"
#include "../Core/VBAN/Packetizer.hpp"
#include "../Core/Network/Demuxer.hpp"
#include <cassert>
#include <iostream>

using namespace vban;

// 测试标准48kHz立体声16位包封包与解析
void tststdpkt() {
    // 验证48kHz立体声封包与解析完整性
    uint8_t buf[1500];
    const uint32_t smpls = 64;
    const uint32_t ch    = 2;
    const uint32_t sr    = 48000;
    const auto     fmt   = SmplFmt::Int16;

    int16_t pcm[smpls * ch];
    for (uint32_t i = 0; i < smpls * ch; ++i) {
        pcm[i] = static_cast<int16_t>(i * 100);
    }

    size_t sz = bldpkt(buf, sizeof(buf), "StreamA", sr, ch, smpls, fmt, 42, pcm, sizeof(pcm));
    assert(sz == kHdrSz + sizeof(pcm));

    PktInf inf{};
    bool ok = prspkt(buf, sz, &inf);
    assert(ok);
    assert(inf.proto == ProtoSub::Audio);
    assert(inf.sr == 48000);
    assert(inf.ch == 2);
    assert(inf.smpls == 64);
    assert(inf.fmt == SmplFmt::Int16);
    assert(inf.bpsz == 2);
    assert(inf.frmcnt == 42);
    assert(std::string(inf.strm) == "StreamA");
    assert(std::memcmp(inf.pyld, pcm, sizeof(pcm)) == 0);
    std::cout << "[PASS] tststdpkt: 48kHz Stereo 16-bit OK\n";
}

// 测试44.1kHz单声道24位包解析
void tst24bpkt() {
    // 验证44.1kHz单声道24位封包与解析
    uint8_t buf[1500];
    const uint32_t smpls = 128;
    const uint32_t ch    = 1;
    const uint32_t sr    = 44100;
    const auto     fmt   = SmplFmt::Int24;

    uint8_t pcm[smpls * ch * 3];
    std::memset(pcm, 0x7F, sizeof(pcm));

    size_t sz = bldpkt(buf, sizeof(buf), "TalkieMic", sr, ch, smpls, fmt, 1001, pcm, sizeof(pcm));
    assert(sz == kHdrSz + sizeof(pcm));

    PktInf inf{};
    bool ok = prspkt(buf, sz, &inf);
    assert(ok);
    assert(inf.sr == 44100);
    assert(inf.ch == 1);
    assert(inf.smpls == 128);
    assert(inf.fmt == SmplFmt::Int24);
    assert(inf.bpsz == 3);
    assert(inf.frmcnt == 1001);
    assert(std::string(inf.strm) == "TalkieMic");
    std::cout << "[PASS] tst24bpkt: 44.1kHz Mono 24-bit OK\n";
}

// 测试32位浮点立体声包解析
void tstfltpkt() {
    // 验证96kHz立体声浮点包封包与解析
    uint8_t buf[1500];
    const uint32_t smpls = 32;
    const uint32_t ch    = 2;
    const uint32_t sr    = 96000;
    const auto     fmt   = SmplFmt::Float32;

    float pcm[smpls * ch];
    for (uint32_t i = 0; i < smpls * ch; ++i) {
        pcm[i] = 0.5f;
    }

    size_t sz = bldpkt(buf, sizeof(buf), "HiResAudio", sr, ch, smpls, fmt, 0, pcm, sizeof(pcm));
    assert(sz == kHdrSz + sizeof(pcm));

    PktInf inf{};
    bool ok = prspkt(buf, sz, &inf);
    assert(ok);
    assert(inf.sr == 96000);
    assert(inf.ch == 2);
    assert(inf.fmt == SmplFmt::Float32);
    assert(inf.bpsz == 4);
    std::cout << "[PASS] tstfltpkt: 96kHz Stereo Float32 OK\n";
}

// 测试异常数据报文防破坏安全机制
void tsterrpkt() {
    // 验证截断或畸形包被正确拦截
    uint8_t buf[1500];
    PktInf inf{};

    // 长度不足 28 字节
    assert(!prspkt(buf, 20, &inf));

    // 魔数损坏
    bldpkt(buf, sizeof(buf), "Corrupt", 48000, 2, 64, SmplFmt::Int16, 0, buf, 256);
    buf[0] = 'X';
    assert(!prspkt(buf, kHdrSz + 256, &inf));

    // 采样率索引超界
    buf[0] = 'V';
    buf[4] = 0x1F; // 索引 31 > 20
    assert(!prspkt(buf, kHdrSz + 256, &inf));

    // 负载截断
    bldpkt(buf, sizeof(buf), "Truncated", 48000, 2, 64, SmplFmt::Int16, 0, buf, 256);
    assert(!prspkt(buf, kHdrSz + 100, &inf)); // 期望 256 字节，只给 100

    std::cout << "[PASS] tsterrpkt: Malformed & truncated packet protection OK\n";
}

// 测试单端口多流解复用与分发
void tstdmxstrm() {
    // 验证单端口多流按名称与IP精确路由
    StrmDmx dmx;

    std::vector<std::string> strmA_pkts;
    std::vector<std::string> strmB_pkts;

    dmx.regstrm("StreamA", "192.168.1.10", [&](const PktInf& inf, const char*, uint16_t) {
        strmA_pkts.emplace_back(inf.strm);
    });

    dmx.regstrm("StreamB", "", [&](const PktInf& inf, const char*, uint16_t) {
        strmB_pkts.emplace_back(inf.strm);
    });

    uint8_t bufA[500];
    int16_t pcmA[64 * 2]{0};
    size_t szA = bldpkt(bufA, sizeof(bufA), "StreamA", 48000, 2, 64, SmplFmt::Int16, 1, pcmA, sizeof(pcmA));

    uint8_t bufB[500];
    int16_t pcmB[64 * 2]{0};
    size_t szB = bldpkt(bufB, sizeof(bufB), "StreamB", 48000, 2, 64, SmplFmt::Int16, 1, pcmB, sizeof(pcmB));

    // 投递 StreamA (正确IP)
    assert(dmx.dmxpkt(bufA, szA, "192.168.1.10", 6980));
    assert(strmA_pkts.size() == 1);

    // 投递 StreamA (错误IP，被过滤)
    assert(!dmx.dmxpkt(bufA, szA, "192.168.1.99", 6980));
    assert(strmA_pkts.size() == 1);

    // 投递 StreamB (任意IP均接收)
    assert(dmx.dmxpkt(bufB, szB, "10.0.0.5", 6980));
    assert(strmB_pkts.size() == 1);

    // 自动发现未知流 StreamC
    uint8_t bufC[500];
    size_t szC = bldpkt(bufC, sizeof(bufC), "StreamC", 48000, 2, 64, SmplFmt::Int16, 1, pcmB, sizeof(pcmB));
    assert(dmx.dmxpkt(bufC, szC, "172.16.0.1", 6980));
    assert(dmx.gtcnt() == 3);

    auto snaps = dmx.gtsnaps();
    assert(snaps.size() == 3);

    std::cout << "[PASS] tstdmxstrm: Single port multi-stream demux OK\n";
}

// 测试丢包与乱序统计
void tststtloss() {
    // 验证统计分析器正确识别跳帧、重复和乱序
    StrmStts stts;
    PktInf inf{};
    inf.sr = 48000;
    inf.ch = 2;
    inf.smpls = 64;
    inf.fmt = SmplFmt::Int16;
    inf.pyldsz = 256;
    std::strcpy(inf.strm, "StatsTest");

    // 包 0
    inf.frmcnt = 0;
    stts.updpkt(inf, "127.0.0.1", 6980);

    // 包 1
    inf.frmcnt = 1;
    stts.updpkt(inf, "127.0.0.1", 6980);

    // 重复包 1
    stts.updpkt(inf, "127.0.0.1", 6980);

    // 跳过包2，直接收包3 (丢了1包)
    inf.frmcnt = 3;
    stts.updpkt(inf, "127.0.0.1", 6980);

    // 收到乱序的包 2
    inf.frmcnt = 2;
    stts.updpkt(inf, "127.0.0.1", 6980);

    auto sn = stts.gtsnap();
    assert(sn.pktcnt == 5);
    assert(sn.dupcnt == 1);
    assert(sn.lostcnt == 1);
    assert(sn.ordrcnt == 1);
    assert(sn.stt == StrmStt::Active);

    std::cout << "[PASS] tststtloss: Loss, duplicate, and out-of-order tracking OK\n";
}

int main() {
    std::cout << "Running VBAN Core Unit Tests...\n";
    tststdpkt();
    tst24bpkt();
    tstfltpkt();
    tsterrpkt();
    tstdmxstrm();
    tststtloss();
    std::cout << "All VBAN Core Unit Tests PASSED successfully!\n";
    return 0;
}
