#ifndef VBAN_JITTER_BUFFER_HPP
#define VBAN_JITTER_BUFFER_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../Common/RingBuffer.hpp"
#include "../VBAN/Protocol.hpp"

namespace vban {

// 网络抖动缓冲质量预设
enum class NetQlt : uint8_t {
    Optimal  = 0, // ~5ms 极低延迟，适用于局域网高保真
    Fast     = 1, // ~10ms 快速
    Normal   = 2, // ~20ms 平衡
    Slow     = 3, // ~40ms 抗抖动
    VerySlow = 4  // ~80ms 极端抗抖动与跨网段
};

// 抗网络抖动与平滑缓冲池
class JtrBuf {
public:
    // 初始化指定声道与采样率的抖动缓冲
    JtrBuf(uint32_t ch = 2, uint32_t sr = 48000, NetQlt qlt = NetQlt::Normal)
        : ch_(ch),
          sr_(sr),
          qlt_(qlt),
          ring_(32768),
          prebuf_(true),
          undrcnt_(0),
          ovrcnt_(0) {
        setqlt(qlt);
    }

    // 设置质量档位调整预缓冲深度
    void setqlt(NetQlt q) {
        // 设置目标缓冲深度毫秒数
        qlt_ = q;
        uint32_t ms = 20;
        switch (q) {
            case NetQlt::Optimal:  ms = 5;  break;
            case NetQlt::Fast:     ms = 10; break;
            case NetQlt::Normal:   ms = 20; break;
            case NetQlt::Slow:     ms = 40; break;
            case NetQlt::VerySlow: ms = 80; break;
        }
        trgt_smpls_ = (sr_ * ms / 1000) * ch_;
        if (trgt_smpls_ < 128) {
            trgt_smpls_ = 128;
        }
        rstjtr();
    }

    // 重置抖动缓冲
    void rstjtr() {
        // 清空环形缓冲区并进入预缓冲准备状态
        ring_.rstbuf();
        prebuf_.store(true, std::memory_order_release);
    }

    // 将收到的VBAN数据包解出Float样本压入缓冲
    bool pshpkt(const PktInf& inf) {
        // 将不同整型/浮点格式的原始样本转为单精度浮点存入
        if (inf.ch != ch_ || inf.sr != sr_) {
            ch_ = inf.ch;
            sr_ = inf.sr;
            setqlt(qlt_);
        }

        const uint32_t total_smpls = inf.smpls * inf.ch;
        float tmp[kMaxPyld / 2];
        if (total_smpls > (sizeof(tmp) / sizeof(float))) {
            return false;
        }

        // 统一归一化转换为 float
        if (inf.fmt == SmplFmt::Int16) {
            const auto* s16 = reinterpret_cast<const int16_t*>(inf.pyld);
            for (uint32_t i = 0; i < total_smpls; ++i) {
                tmp[i] = static_cast<float>(s16[i]) / 32768.0f;
            }
        } else if (inf.fmt == SmplFmt::Float32) {
            const auto* f32 = reinterpret_cast<const float*>(inf.pyld);
            std::memcpy(tmp, f32, total_smpls * sizeof(float));
        } else if (inf.fmt == SmplFmt::Int24) {
            const auto* b = inf.pyld;
            for (uint32_t i = 0; i < total_smpls; ++i) {
                int32_t v = (static_cast<int32_t>(b[i * 3 + 0])) |
                            (static_cast<int32_t>(b[i * 3 + 1]) << 8) |
                            (static_cast<int32_t>(static_cast<int8_t>(b[i * 3 + 2])) << 16);
                tmp[i] = static_cast<float>(v) / 8388608.0f;
            }
        } else if (inf.fmt == SmplFmt::Int32) {
            const auto* s32 = reinterpret_cast<const int32_t*>(inf.pyld);
            for (uint32_t i = 0; i < total_smpls; ++i) {
                tmp[i] = static_cast<float>(s32[i]) / 2147483648.0f;
            }
        } else if (inf.fmt == SmplFmt::Int8) {
            const auto* s8 = reinterpret_cast<const int8_t*>(inf.pyld);
            for (uint32_t i = 0; i < total_smpls; ++i) {
                tmp[i] = static_cast<float>(s8[i]) / 128.0f;
            }
        } else {
            return false;
        }

        const size_t wr = ring_.wrblks(tmp, total_smpls);
        if (wr < total_smpls) {
            ovrcnt_++;
        }

        if (prebuf_.load(std::memory_order_relaxed)) {
            if (ring_.gtavlr() >= trgt_smpls_) {
                prebuf_.store(false, std::memory_order_release);
            }
        }

        return true;
    }

    // 音频回调中提取样本 (不足则静音平滑)
    size_t popblks(float* dst, size_t cnt) {
        // 从缓冲池提取就绪音频样本
        if (!dst || cnt == 0) {
            return 0;
        }

        if (prebuf_.load(std::memory_order_acquire)) {
            std::memset(dst, 0, cnt * sizeof(float));
            return 0;
        }

        const size_t avl = ring_.gtavlr();
        if (avl < cnt) {
            undrcnt_++;
            // 若严重欠载则重新进入预缓冲，防止连续爆音
            if (avl == 0) {
                prebuf_.store(true, std::memory_order_release);
            }
        }

        return ring_.rdblks(dst, cnt);
    }

    // 获取当前缓冲水位百分比 (0.0 ~ 100.0)
    float gtfill() const {
        // 计算当前样本数相对于目标水位的比例
        if (trgt_smpls_ == 0) return 0.0f;
        const size_t avl = ring_.gtavlr();
        return std::min(100.0f, (static_cast<float>(avl) / static_cast<float>(trgt_smpls_)) * 100.0f);
    }

    // 获取欠载次数
    uint64_t gtundr() const {
        // 返回累计缓冲区空转次数
        return undrcnt_;
    }

    // 获取溢出次数
    uint64_t gtovr() const {
        // 返回累计丢弃样本次数
        return ovrcnt_;
    }

private:
    uint32_t            ch_;
    uint32_t            sr_;
    NetQlt              qlt_;
    size_t              trgt_smpls_{0};
    RingBuf<float>      ring_;
    std::atomic<bool>   prebuf_{true};
    std::atomic<uint64_t> undrcnt_{0};
    std::atomic<uint64_t> ovrcnt_{0};
};

} // namespace vban

#endif // VBAN_JITTER_BUFFER_HPP
