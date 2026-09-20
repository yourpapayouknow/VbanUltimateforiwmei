#include "../Core/Common/Head.hpp"
#include "../Core/VBAN/Parser.hpp"
#include "../Core/Network/TxManager.hpp"
#include <cassert>

using namespace vban;

// 验证96kHz 24位采集样本经过发送路由进入网络包
int main() {
    UdpSck rx;
    assert(rx.initsck() && rx.bndsck(16982));

    TxMgr tx;
    tx.setcapcb([](const std::string& name, uint8_t* dst, size_t size) -> ssize_t {
        assert(name == "Tone");
        auto* samples = reinterpret_cast<float*>(dst);
        for (size_t i = 0; i < size / sizeof(float); ++i) {
            samples[i] = i % 2 ? -0.5f : 0.5f;
        }
        return static_cast<ssize_t>(size);
    });
    assert(tx.addstrm("tx", "Tone", "device", "127.0.0.1", 16982, 96000, 2, 24));
    tx.strtall();

    uint8_t buf[2048]{};
    char ip[32]{};
    uint16_t port = 0;
    ssize_t n = 0;
    for (int i = 0; i < 100 && n <= 0; ++i) {
        n = rx.rcvsck(buf, sizeof(buf), ip, &port);
        if (n <= 0) std::this_thread::sleep_for(std::chrono::milliseconds(5));
    }
    tx.stpall();

    assert(n > 0 && n <= kMaxPkt);
    PktInf inf{};
    assert(prspkt(buf, static_cast<size_t>(n), &inf));
    assert(inf.sr == 96000 && inf.ch == 2 && inf.fmt == SmplFmt::Int24);
    assert(inf.smpls > 0 && inf.pyldsz == inf.smpls * 2 * 3);
    assert(inf.pyld[0] != 0 || inf.pyld[1] != 0 || inf.pyld[2] != 0);
}
