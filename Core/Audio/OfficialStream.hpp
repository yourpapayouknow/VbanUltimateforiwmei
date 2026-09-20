#ifndef VBAN_OFFICIAL_STREAM_HPP
#define VBAN_OFFICIAL_STREAM_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../VBAN/Protocol.hpp"
#include "../VBAN/Parser.hpp"
#include "OfficialAudio.hpp"

namespace vban {

#if defined(__APPLE__)

// 对照官方 receptor：收包即写入设备
class OffRcvr {
public:
    explicit OffRcvr(std::shared_ptr<OffAud> aud, std::string strm)
        : aud_(std::move(aud)), strm_(std::move(strm)) {}

    // 处理单个报文，等价于官方 receptor 循环体
    bool onpkt(const uint8_t* buf, size_t size) {
        // 校验通过后按包头规格写入设备
        if (!aud_ || !buf) return false;

        PktInf inf{};
        if (!prspkt(buf, size, &inf)) return false;

        // 官方按 streamname 过滤
        if (strm_ != inf.strm) return false;

        StrmCfg cfg{};
        cfg.ch  = inf.ch;
        cfg.sr  = inf.sr;
        cfg.bit = inf.fmt == SmplFmt::Int16 ? 1
                : inf.fmt == SmplFmt::Int24 ? 2
                : inf.fmt == SmplFmt::Int32 ? 3
                : inf.fmt == SmplFmt::Float32 ? 4
                : inf.fmt == SmplFmt::Float64 ? 5
                : inf.fmt == SmplFmt::Int8 ? 0
                : inf.fmt == SmplFmt::Int12 ? 6 : 7;

        if (!aud_->setcfg(cfg)) return false;

        // 负载转换为 32 位浮点后写入
        const uint32_t total = inf.smpls * inf.ch;
        if (total == 0) return false;
        if (pcm_.size() < total) pcm_.resize(total, 0.0f);
        if (!toflt(inf, pcm_.data(), total)) return false;

        return aud_->write(reinterpret_cast<const uint8_t*>(pcm_.data()),
                           total * sizeof(float)) > 0;
    }

private:
    // 按采样格式将负载归一化为单精度浮点
    static bool toflt(const PktInf& inf, float* dst, uint32_t total) {
        // 对齐官方 jack_convert_sample 的除数
        switch (inf.fmt) {
            case SmplFmt::Int16: {
                const auto* s = reinterpret_cast<const int16_t*>(inf.pyld);
                for (uint32_t i = 0; i < total; ++i) dst[i] = s[i] / 32768.0f;
                return true;
            }
            case SmplFmt::Int24: {
                const auto* b = inf.pyld;
                for (uint32_t i = 0; i < total; ++i) {
                    const int32_t v = (static_cast<int32_t>(b[i * 3 + 2]) << 16) |
                                      (static_cast<int32_t>(b[i * 3 + 1]) << 8) |
                                      (static_cast<int32_t>(b[i * 3 + 0]));
                    dst[i] = static_cast<float>(v) / 8388608.0f;
                }
                return true;
            }
            case SmplFmt::Int32: {
                const auto* s = reinterpret_cast<const int32_t*>(inf.pyld);
                for (uint32_t i = 0; i < total; ++i) dst[i] = s[i] / 2147483648.0f;
                return true;
            }
            case SmplFmt::Float32: {
                std::memcpy(dst, inf.pyld, total * sizeof(float));
                return true;
            }
            case SmplFmt::Int8: {
                const auto* s = reinterpret_cast<const int8_t*>(inf.pyld);
                for (uint32_t i = 0; i < total; ++i) dst[i] = s[i] / 128.0f;
                return true;
            }
            default:
                return false;
        }
    }

    std::shared_ptr<OffAud> aud_;
    std::string             strm_;
    std::vector<float>      pcm_;
};

#endif // __APPLE__

} // namespace vban

#endif // VBAN_OFFICIAL_STREAM_HPP
