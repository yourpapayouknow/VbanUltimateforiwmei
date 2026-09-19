#ifndef VBAN_STREAM_STATS_HPP
#define VBAN_STREAM_STATS_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../VBAN/Protocol.hpp"

namespace vban {

// 流统计快照信息
struct StrmSnap {
    char        strm[kStrmSz + 1];
    char        srcip[32];
    uint16_t    srcprt;
    uint32_t    sr;
    uint32_t    ch;
    SmplFmt     fmt;
    StrmStt     stt;
    uint64_t    pktcnt;
    uint64_t    frmcnt;
    uint64_t    lostcnt;
    uint64_t    dupcnt;
    uint64_t    ordrcnt;
    uint64_t    undrcnt;
    uint64_t    ovrcnt;
    uint64_t    crptcnt;
    uint64_t    errcnt;
    uint32_t    pkts;
    uint32_t    kbps;
    double      jtr_ms;
    int64_t     last_ms;
};

// 单流统计分析器
class StrmStts {
public:
    // 初始化统计器
    StrmStts() {
        rststt();
    }

    // 重置统计器状态
    void rststt() {
        // 重置所有内部计数与时间戳
        strm_[0]   = '\0';
        srcip_[0]  = '\0';
        srcprt_    = 0;
        sr_        = 0;
        ch_        = 0;
        fmt_       = SmplFmt::Int16;
        stt_       = StrmStt::Offline;
        pktcnt_    = 0;
        frmcnt_    = 0;
        lostcnt_   = 0;
        dupcnt_    = 0;
        ordrcnt_   = 0;
        crptcnt_   = 0;
        errcnt_    = 0;
        last_frm_  = 0;
        has_frm_   = false;
        pkts_      = 0;
        kbps_      = 0;
        jtr_       = 0.0;
        win_pkts_  = 0;
        win_bytes_ = 0;
        last_rcv_  = std::chrono::steady_clock::now();
        win_start_ = last_rcv_;
    }

    // 更新收包统计数据
    void updpkt(const PktInf& inf, const char* sip, uint16_t sprt) {
        // 记录新收到的数据包并计算指标
        const auto now = std::chrono::steady_clock::now();
        last_rcv_ = now;
        stt_ = StrmStt::Active;

        if (strm_[0] == '\0') {
            std::strncpy(strm_, inf.strm, kStrmSz);
            strm_[kStrmSz] = '\0';
        }
        if (sip && srcip_[0] == '\0') {
            std::strncpy(srcip_, sip, sizeof(srcip_) - 1);
            srcip_[sizeof(srcip_) - 1] = '\0';
            srcprt_ = sprt;
        }

        sr_  = inf.sr;
        ch_  = inf.ch;
        fmt_ = inf.fmt;

        pktcnt_++;
        frmcnt_ += inf.smpls;
        win_pkts_++;
        win_bytes_ += (kHdrSz + inf.pyldsz);

        // 丢包与乱序分析
        if (has_frm_) {
            const int64_t diff = static_cast<int64_t>(inf.frmcnt) - static_cast<int64_t>(last_frm_);
            if (diff == 0) {
                dupcnt_++;
            } else if (diff < 0) {
                ordrcnt_++;
            } else if (diff > 1) {
                lostcnt_ += (diff - 1);
            }
        } else {
            has_frm_ = true;
        }
        last_frm_ = inf.frmcnt;

        // 计算滑动窗口吞吐率
        const auto elps = std::chrono::duration_cast<std::chrono::milliseconds>(now - win_start_).count();
        if (elps >= 1000) {
            pkts_ = static_cast<uint32_t>((win_pkts_ * 1000) / elps);
            kbps_ = static_cast<uint32_t>(((win_bytes_ * 8) / 1000) * 1000 / elps);
            win_pkts_  = 0;
            win_bytes_ = 0;
            win_start_ = now;
        }
    }

    // 检查并更新离线超时
    void chkoffln(int64_t timeout_ms = 3000) {
        // 超过指定毫秒未收到包则置为离线
        if (stt_ == StrmStt::Active) {
            const auto now = std::chrono::steady_clock::now();
            const auto elps = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_rcv_).count();
            if (elps > timeout_ms) {
                stt_ = StrmStt::Offline;
                pkts_ = 0;
                kbps_ = 0;
            }
        }
    }

    // 获取当前统计快照
    StrmSnap gtsnap() const {
        // 返回不可变的统计数据快照
        StrmSnap sn{};
        std::strncpy(sn.strm, strm_, kStrmSz);
        sn.strm[kStrmSz] = '\0';
        std::strncpy(sn.srcip, srcip_, sizeof(sn.srcip) - 1);
        sn.srcip[sizeof(sn.srcip) - 1] = '\0';
        sn.srcprt  = srcprt_;
        sn.sr      = sr_;
        sn.ch      = ch_;
        sn.fmt     = fmt_;
        sn.stt     = stt_;
        sn.pktcnt  = pktcnt_;
        sn.frmcnt  = frmcnt_;
        sn.lostcnt = lostcnt_;
        sn.dupcnt  = dupcnt_;
        sn.ordrcnt = ordrcnt_;
        sn.undrcnt = 0;
        sn.ovrcnt  = 0;
        sn.crptcnt = crptcnt_;
        sn.errcnt  = errcnt_;
        sn.pkts    = pkts_;
        sn.kbps    = kbps_;
        sn.jtr_ms  = jtr_;

        const auto now = std::chrono::steady_clock::now();
        sn.last_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_rcv_).count();
        return sn;
    }

    // 记录损坏包与错误计数
    void updcrpt() { crptcnt_++; }
    void upderr() { errcnt_++; }
    uint64_t gtcrpt() const { return crptcnt_; }
    uint64_t gterrcnt() const { return errcnt_; }

private:
    char        strm_[kStrmSz + 1];
    char        srcip_[32];
    uint16_t    srcprt_{0};
    uint32_t    sr_{0};
    uint32_t    ch_{0};
    SmplFmt     fmt_{SmplFmt::Int16};
    StrmStt     stt_{StrmStt::Offline};
    uint64_t    pktcnt_{0};
    uint64_t    frmcnt_{0};
    uint64_t    lostcnt_{0};
    uint64_t    dupcnt_{0};
    uint64_t    ordrcnt_{0};
    uint64_t    crptcnt_{0};
    uint64_t    errcnt_{0};
    uint32_t    last_frm_{0};
    bool        has_frm_{false};
    uint32_t    pkts_{0};
    uint32_t    kbps_{0};
    double      jtr_{0.0};

    uint64_t    win_pkts_{0};
    uint64_t    win_bytes_{0};
    std::chrono::steady_clock::time_point last_rcv_;
    std::chrono::steady_clock::time_point win_start_;
};

} // namespace vban

#endif // VBAN_STREAM_STATS_HPP
