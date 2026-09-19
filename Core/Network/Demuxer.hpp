#ifndef VBAN_DEMUXER_HPP
#define VBAN_DEMUXER_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../VBAN/Parser.hpp"
#include "../Monitoring/StreamStats.hpp"
#include "JitterBuffer.hpp"
#include "PingManager.hpp"

namespace vban {

// 流数据处理回调函数签名
using PktCb = std::function<void(const PktInf& inf, const char* sip, uint16_t sprt)>;

// 音频样本提取回调函数签名
using AudCb = std::function<void(const char* strm, const float* smpls, size_t cnt, uint32_t ch)>;

// 单流上下文封装
struct StrmCtx {
    std::string             strm;
    std::string             req_ip;
    PktCb                   cb;
    StrmStts                stts;
    std::shared_ptr<JtrBuf> jtr;
    bool                    en{true};
};

// 单端口多流解复用分发器
class StrmDmx {
public:
    // 初始化解复用器
    StrmDmx() : auto_dsc_(true) {}

    // 注册指定名称与源IP的流通道
    bool regstrm(const std::string& strm, const std::string& ip, PktCb cb) {
        // 向解复用器添加受管流定义
        std::lock_guard<std::mutex> lock(mtx_);
        if (strm.empty()) {
            return false;
        }

        auto ctx = std::make_shared<StrmCtx>();
        ctx->strm   = strm;
        ctx->req_ip = ip;
        ctx->cb     = std::move(cb);
        ctx->en     = true;

        strms_[strm] = ctx;
        return true;
    }

    // 移除指定流
    void rmvstrm(const std::string& strm) {
        // 从分发列表中移除流
        std::lock_guard<std::mutex> lock(mtx_);
        strms_.erase(strm);
    }

    // 启用或禁用指定流
    void tglstrm(const std::string& strm, bool en) {
        // 设置指定流的使能状态
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = strms_.find(strm);
        if (it != strms_.end()) {
            it->second->en = en;
        }
    }

    // 设置是否开启自动发现新流
    void stautodsc(bool en) {
        // 设置自动发现开关
        auto_dsc_ = en;
    }

    // 设置音频样本提取回调
    void setaudcb(AudCb cb) {
        // 注册接收样本提取回调
        aud_cb_ = std::move(cb);
    }

    // 分分解码并分发单个网络数据包
    bool dmxpkt(const uint8_t* dat, size_t len, const char* sip, uint16_t sprt) {
        // 服务协议探测报文优先分发
        if (len >= kHdrSz && (dat[4] & 0xE0) == 0x60) {
            if (PingMgr::inst().prspkt(dat, len, sip, sprt)) {
                return true;
            }
        }

        // 将收到的数据包精准路由至对应流上下文
        PktInf inf{};
        if (!prspkt(dat, len, &inf)) {
            crptcnt_++;
            return false;
        }

        std::shared_ptr<StrmCtx> target;
        {
            std::lock_guard<std::mutex> lock(mtx_);
            std::string key(inf.strm);
            auto it = strms_.find(key);
            if (it != strms_.end()) {
                target = it->second;
            } else if (auto_dsc_) {
                // 自动登记发现的新流
                auto ctx = std::make_shared<StrmCtx>();
                ctx->strm = key;
                ctx->en   = true;
                strms_[key] = ctx;
                target = ctx;
            }
        }

        if (!target || !target->en) {
            return false;
        }

        // IP 过滤比对
        if (!target->req_ip.empty() && sip) {
            if (target->req_ip != sip) {
                return false;
            }
        }

        // 更新统计指标
        target->stts.updpkt(inf, sip, sprt);

        // 提取接收样本供流回放通路使用
        if (aud_cb_) {
            toflt(inf);
            if (flt_cnt_ > 0) {
                aud_cb_(inf.strm, flt_.data(), flt_cnt_, inf.ch);
            }
        }

        // 压入抗网络抖动平滑缓冲
        if (!target->jtr) {
            target->jtr = std::make_shared<JtrBuf>(inf.ch, inf.sr, def_qlt_);
        }
        if (!target->jtr->pshpkt(inf)) {
            target->stts.updcrpt();
        }

        // 派发回调
        if (target->cb) {
            target->cb(inf, sip, sprt);
        }

        return true;
    }

    // 设置全局网络质量预设
    void setqlt(NetQlt q) {
        std::lock_guard<std::mutex> lock(mtx_);
        def_qlt_ = q;
        for (auto& pair : strms_) {
            if (pair.second->jtr) {
                pair.second->jtr->setqlt(q);
            }
        }
    }

    // 获取当前默认网络质量预设
    NetQlt gtqlt() const {
        std::lock_guard<std::mutex> lock(mtx_);
        return def_qlt_;
    }

    // 定时轮询检查超时离线流
    void chkall(int64_t to_ms = 3000) {
        // 遍历所有流并更新离线状态
        std::lock_guard<std::mutex> lock(mtx_);
        for (auto& pair : strms_) {
            pair.second->stts.chkoffln(to_ms);
        }
    }

    // 获取所有流的统计指标快照
    std::vector<StrmSnap> gtsnaps() {
        // 提取全部已知流的快照列表
        std::vector<StrmSnap> snaps;
        std::lock_guard<std::mutex> lock(mtx_);
        snaps.reserve(strms_.size());
        for (const auto& pair : strms_) {
            auto sn = pair.second->stts.gtsnap();
            if (pair.second->jtr) {
                sn.undrcnt = pair.second->jtr->gtundr();
                sn.ovrcnt  = pair.second->jtr->gtovr();
            }
            snaps.push_back(sn);
        }
        return snaps;
    }

    // 获取当前注册流总数
    size_t gtcnt() const {
        // 返回当前流数量
        std::lock_guard<std::mutex> lock(mtx_);
        return strms_.size();
    }

    // 获取全局损坏报文计数
    uint64_t gtcrpt() const {
        return crptcnt_.load(std::memory_order_relaxed);
    }

    // 获取全局套接字错误计数
    uint64_t gterrcnt() const {
        return errcnt_.load(std::memory_order_relaxed);
    }

    // 记录全局套接字错误
    void upderr() {
        errcnt_.fetch_add(1, std::memory_order_relaxed);
    }

private:
    // 将整型负载归一化转换为单精度浮点样本
    void toflt(const PktInf& inf) {
        // 按采样格式解包负载为浮点样本
        const uint32_t total = inf.smpls * inf.ch;
        flt_cnt_ = 0;
        if (total == 0 || total > kMaxPyld / 2 || !inf.pyld) {
            return;
        }
        if (flt_.size() < total) {
            flt_.resize(total, 0.0f);
        }

        switch (inf.fmt) {
            case SmplFmt::Int16: {
                const auto* s = reinterpret_cast<const int16_t*>(inf.pyld);
                for (uint32_t i = 0; i < total; ++i) flt_[i] = s[i] / 32768.0f;
                break;
            }
            case SmplFmt::Float32: {
                std::memcpy(flt_.data(), inf.pyld, total * sizeof(float));
                break;
            }
            case SmplFmt::Int24: {
                const auto* b = inf.pyld;
                for (uint32_t i = 0; i < total; ++i) {
                    const int32_t v = (static_cast<int32_t>(b[i * 3 + 0])) |
                                      (static_cast<int32_t>(b[i * 3 + 1]) << 8) |
                                      (static_cast<int32_t>(static_cast<int8_t>(b[i * 3 + 2])) << 16);
                    flt_[i] = v / 8388608.0f;
                }
                break;
            }
            case SmplFmt::Int32: {
                const auto* s = reinterpret_cast<const int32_t*>(inf.pyld);
                for (uint32_t i = 0; i < total; ++i) flt_[i] = s[i] / 2147483648.0f;
                break;
            }
            case SmplFmt::Int8: {
                const auto* s = reinterpret_cast<const int8_t*>(inf.pyld);
                for (uint32_t i = 0; i < total; ++i) flt_[i] = s[i] / 128.0f;
                break;
            }
            default:
                return;
        }
        flt_cnt_ = total;
    }

    mutable std::mutex mtx_;
    std::unordered_map<std::string, std::shared_ptr<StrmCtx>> strms_;
    std::atomic<bool> auto_dsc_;
    NetQlt            def_qlt_{NetQlt::Fast};
    std::atomic<uint64_t> crptcnt_{0};
    std::atomic<uint64_t> errcnt_{0};
    AudCb                 aud_cb_;
    std::vector<float>    flt_;
    size_t                flt_cnt_{0};
};

} // namespace vban

#endif // VBAN_DEMUXER_HPP
