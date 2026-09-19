#ifndef VBAN_METRICS_ENGINE_HPP
#define VBAN_METRICS_ENGINE_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "StreamStats.hpp"
#include "../Network/Demuxer.hpp"
#include "../Network/TxManager.hpp"
#include "../Audio/CableManager.hpp"
#include "../Routing/MatrixRouter.hpp"

namespace vban {

// 顶层全局监控快照
struct AppMetrics {
    uint32_t actv_rx{0};
    uint32_t actv_tx{0};
    uint32_t cbl_cnt{0};
    uint64_t totl_lost{0};
    uint64_t totl_ordr{0};
    uint64_t totl_undr{0};
    uint64_t totl_ovr{0};
    uint64_t totl_crpt{0};
    uint64_t totl_err{0};
    bool     aud_run{false};
    bool     drv_ok{false};
    std::vector<StrmSnap> rx_snaps;
    std::vector<StrmSnap> tx_snaps;
};

// 全局指标汇聚引擎
class MtrcsEngn {
public:
    MtrcsEngn(std::shared_ptr<StrmDmx> dmx,
              std::shared_ptr<CblMgr> cbl,
              std::shared_ptr<MtrxRtr> rtr,
              std::shared_ptr<TxMgr> tx = nullptr)
        : dmx_(std::move(dmx)),
          cbl_(std::move(cbl)),
          rtr_(std::move(rtr)),
          tx_(std::move(tx)) {}

    // 设置发送管理器引用
    void settx(std::shared_ptr<TxMgr> tx) {
        tx_ = std::move(tx);
    }

    // 捕获系统全局指标快照
    AppMetrics gtsnap(bool aud_running) {
        // 汇聚全部网络与设备指标
        AppMetrics m{};
        m.aud_run = aud_running;

        if (cbl_) {
            m.drv_ok  = cbl_->chkdrvr();
            m.cbl_cnt = static_cast<uint32_t>(cbl_->gtcbls().size());
        }

        if (dmx_) {
            dmx_->chkall(3000); // 检查超时
            m.rx_snaps = dmx_->gtsnaps();
            m.totl_crpt = dmx_->gtcrpt();
            m.totl_err  = dmx_->gterrcnt();
            for (const auto& s : m.rx_snaps) {
                if (s.stt == StrmStt::Active) {
                    m.actv_rx++;
                }
                m.totl_lost += s.lostcnt;
                m.totl_ordr += s.ordrcnt;
                m.totl_undr += s.undrcnt;
                m.totl_ovr  += s.ovrcnt;
            }
        }
        if (tx_) {
            m.tx_snaps = tx_->gtsnaps();
            m.actv_tx  = tx_->gtactv();
        }

        return m;
    }

private:
    std::shared_ptr<StrmDmx>  dmx_;
    std::shared_ptr<CblMgr>   cbl_;
    std::shared_ptr<MtrxRtr>  rtr_;
    std::shared_ptr<TxMgr>    tx_;
};

} // namespace vban

#endif // VBAN_METRICS_ENGINE_HPP
