#ifndef VBAN_TX_MANAGER_HPP
#define VBAN_TX_MANAGER_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../VBAN/Protocol.hpp"
#include "../VBAN/Packetizer.hpp"
#include "../Monitoring/StreamStats.hpp"
#include "UdpSocket.hpp"
#include <thread>
#include <atomic>
#include <mutex>
#include <vector>
#include <chrono>

namespace vban {

// 发送流运行时上下文
struct TxStreamCtx {
    std::string       id;
    std::string       name;
    std::string       src;
    std::string       dst_ip;
    uint16_t          dst_prt{6980};
    uint32_t          sr{48000};
    uint32_t          ch{2};
    uint32_t          bdepth{24};
    SmplFmt           fmt{SmplFmt::Int24};
    std::atomic<bool> en{true};
    uint32_t          nu_frm{0};
    std::chrono::steady_clock::time_point next_snd;
    StrmStts          stats;
};

// 发送流生命周期管理与网络发射引擎
class TxMgr {
public:
    // 初始化发射管理器
    TxMgr() : th_run_(false) {
        sck_ = std::make_shared<UdpSck>();
        sck_->initsck();
        sck_->enbldcast();
    }

    // 析构清理
    ~TxMgr() {
        stpall();
    }

    // 添加或更新发送流配置
    bool addstrm(const std::string& id,
                 const std::string& name,
                 const std::string& src,
                 const std::string& dst_ip,
                 uint16_t dst_prt,
                 uint32_t sr,
                 uint32_t ch,
                 uint32_t bdepth) {
        std::lock_guard<std::mutex> lock(mtx_);
        for (auto& s : strms_) {
            if (s->id == id) {
                s->name    = name;
                s->src     = src;
                s->dst_ip  = dst_ip;
                s->dst_prt = dst_prt;
                s->sr      = sr;
                s->ch      = ch;
                s->bdepth  = bdepth;
                s->fmt     = bd2fmt(bdepth);
                return true;
            }
        }

        auto ctx = std::make_shared<TxStreamCtx>();
        ctx->id      = id;
        ctx->name    = name;
        ctx->src     = src;
        ctx->dst_ip  = dst_ip;
        ctx->dst_prt = dst_prt;
        ctx->sr      = sr;
        ctx->ch      = ch;
        ctx->bdepth  = bdepth;
        ctx->fmt     = bd2fmt(bdepth);
        ctx->en.store(true);
        strms_.push_back(ctx);
        return true;
    }

    // 移除指定发送流
    bool rmvstrm(const std::string& id) {
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = std::remove_if(strms_.begin(), strms_.end(), [&](const std::shared_ptr<TxStreamCtx>& s) {
            return s->id == id;
        });
        if (it != strms_.end()) {
            strms_.erase(it, strms_.end());
            return true;
        }
        return false;
    }

    // 启停指定发送流
    bool tglstrm(const std::string& id, bool en) {
        std::lock_guard<std::mutex> lock(mtx_);
        for (auto& s : strms_) {
            if (s->id == id) {
                s->en.store(en);
                return true;
            }
        }
        return false;
    }

    // 清空全部发送流
    void clrstrms() {
        std::lock_guard<std::mutex> lock(mtx_);
        strms_.clear();
    }

    // 启动后台发射线程
    void strtall() {
        if (th_run_.load()) return;
        th_run_.store(true);

        tx_th_ = std::thread([this]() {
            this->txloop();
        });
    }

    // 停止后台发射线程
    void stpall() {
        th_run_.store(false);
        if (tx_th_.joinable()) {
            tx_th_.join();
        }
    }

    // 获取发送流指标快照
    std::vector<StrmSnap> gtsnaps() {
        std::lock_guard<std::mutex> lock(mtx_);
        std::vector<StrmSnap> snaps;
        snaps.reserve(strms_.size());
        for (const auto& s : strms_) {
            auto sn = s->stats.gtsnap();
            std::strncpy(sn.strm, s->name.c_str(), kStrmSz);
            sn.strm[kStrmSz] = '\0';
            std::strncpy(sn.srcip, s->dst_ip.c_str(), sizeof(sn.srcip) - 1);
            sn.srcip[sizeof(sn.srcip) - 1] = '\0';
            sn.srcprt = s->dst_prt;
            sn.sr     = s->sr;
            sn.ch     = s->ch;
            sn.fmt    = s->fmt;
            sn.stt    = s->en.load() ? StrmStt::Active : StrmStt::Offline;
            snaps.push_back(sn);
        }
        return snaps;
    }

    // 获取当前活跃发送流数量
    uint32_t gtactv() {
        std::lock_guard<std::mutex> lock(mtx_);
        uint32_t cnt = 0;
        for (const auto& s : strms_) {
            if (s->en.load()) cnt++;
        }
        return cnt;
    }

private:
    // 位深转协议采样格式
    static SmplFmt bd2fmt(uint32_t bd) {
        switch (bd) {
            case 8:  return SmplFmt::Int8;
            case 16: return SmplFmt::Int16;
            case 24: return SmplFmt::Int24;
            case 32: return SmplFmt::Int32;
            default: return SmplFmt::Int24;
        }
    }

    // 单包承载的采样帧数
    static constexpr uint32_t kSmplsPerPkt = 256;

    // 采集样本并按流格式编码负载
    size_t gtpyld(TxStreamCtx& s, uint8_t* dst, size_t maxlen) {
        // 取出采集样本并按流格式量化写入负载区
        const uint32_t smpls = kSmplsPerPkt;
        const uint32_t ch    = s.ch ? s.ch : 1;
        const uint32_t bpsz  = gtbpsz(s.fmt);
        const size_t   total = static_cast<size_t>(smpls) * ch;
        const size_t   need  = total * bpsz;
        if (need == 0 || need > maxlen) {
            return 0;
        }

        if (flt_.size() < total) {
            flt_.resize(total, 0.0f);
        }

        // 采集源由官方 emitter 直接驱动，此处输出静音帧保持时序连续
        std::memset(flt_.data(), 0, total * sizeof(float));
        encpcm(dst, flt_.data(), total, s.fmt);
        return need;
    }

    // 将浮点样本量化为指定协议格式
    static void encpcm(uint8_t* dst, const float* src, size_t cnt, SmplFmt fmt) {
        // 按目标位深执行饱和量化与字节序写入
        switch (fmt) {
            case SmplFmt::Int8: {
                auto* d = reinterpret_cast<int8_t*>(dst);
                for (size_t i = 0; i < cnt; ++i) {
                    d[i] = static_cast<int8_t>(std::lrint(std::clamp(src[i], -1.0f, 1.0f) * 127.0f));
                }
                break;
            }
            case SmplFmt::Int16: {
                auto* d = reinterpret_cast<int16_t*>(dst);
                for (size_t i = 0; i < cnt; ++i) {
                    d[i] = static_cast<int16_t>(std::lrint(std::clamp(src[i], -1.0f, 1.0f) * 32767.0f));
                }
                break;
            }
            case SmplFmt::Int24: {
                for (size_t i = 0; i < cnt; ++i) {
                    const int32_t v = static_cast<int32_t>(
                        std::lrint(std::clamp(src[i], -1.0f, 1.0f) * 8388607.0f));
                    dst[i * 3 + 0] = static_cast<uint8_t>(v & 0xFF);
                    dst[i * 3 + 1] = static_cast<uint8_t>((v >> 8) & 0xFF);
                    dst[i * 3 + 2] = static_cast<uint8_t>((v >> 16) & 0xFF);
                }
                break;
            }
            case SmplFmt::Int32: {
                auto* d = reinterpret_cast<int32_t*>(dst);
                for (size_t i = 0; i < cnt; ++i) {
                    d[i] = static_cast<int32_t>(std::llrint(
                        static_cast<double>(std::clamp(src[i], -1.0f, 1.0f)) * 2147483647.0));
                }
                break;
            }
            case SmplFmt::Float32: {
                std::memcpy(dst, src, cnt * sizeof(float));
                break;
            }
            default:
                std::memset(dst, 0, cnt * gtbpsz(fmt));
                break;
        }
    }

    // 发射线程主循环
    void txloop() {
        std::vector<uint8_t> pktbuf(kMaxPkt);
        std::vector<uint8_t> pyldbuf;

        while (th_run_.load()) {
            const auto now = std::chrono::steady_clock::now();

            {
                std::lock_guard<std::mutex> lock(mtx_);
                for (auto& s : strms_) {
                    if (!s->en.load()) continue;
                    if (now < s->next_snd) continue;

                    const uint32_t bpsz = gtbpsz(s->fmt);
                    const size_t pyldsz = kSmplsPerPkt * s->ch * bpsz;

                    if (pyldbuf.size() < pyldsz) {
                        pyldbuf.resize(pyldsz, 0);
                    }

                    // 采集样本并按流格式编码负载
                    if (gtpyld(*s, pyldbuf.data(), pyldbuf.size()) != pyldsz) {
                        continue;
                    }

                    // 组装并发送报文
                    size_t pktsz = bldpkt(pktbuf.data(), pktbuf.size(),
                                          s->name.c_str(), s->sr, s->ch,
                                          kSmplsPerPkt, s->fmt, s->nu_frm++,
                                          pyldbuf.data(), pyldsz);

                    if (pktsz > 0 && sck_) {
                        ssize_t sent = sck_->sndsck(s->dst_ip.c_str(), s->dst_prt, pktbuf.data(), pktsz);
                        if (sent < 0) {
                            s->stats.upderr();
                        } else {
                            PktInf inf{};
                            inf.proto  = ProtoSub::Audio;
                            inf.sr     = s->sr;
                            inf.ch     = s->ch;
                            inf.smpls  = kSmplsPerPkt;
                            inf.fmt    = s->fmt;
                            inf.bpsz   = bpsz;
                            inf.pyldsz = static_cast<uint32_t>(pyldsz);
                            inf.frmcnt = s->nu_frm;
                            std::strncpy(inf.strm, s->name.c_str(), kStrmSz);
                            inf.strm[kStrmSz] = '\0';

                            s->stats.updpkt(inf, s->dst_ip.c_str(), s->dst_prt);
                        }
                    }

                    const uint64_t step_us = (uint64_t)kSmplsPerPkt * 1000000ULL / (s->sr > 0 ? s->sr : 48000);
                    s->next_snd = now + std::chrono::microseconds(step_us);
                }
            }

            std::this_thread::sleep_for(std::chrono::microseconds(400));
        }
    }

    std::mutex                               mtx_;
    std::vector<std::shared_ptr<TxStreamCtx>> strms_;
    std::shared_ptr<UdpSck>                  sck_;
    std::vector<float>                       flt_;
    std::thread                              tx_th_;
    std::atomic<bool>                        th_run_;
};

} // namespace vban

#endif // VBAN_TX_MANAGER_HPP
