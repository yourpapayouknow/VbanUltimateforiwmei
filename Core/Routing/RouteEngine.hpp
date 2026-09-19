#ifndef VBAN_ROUTE_ENGINE_HPP
#define VBAN_ROUTE_ENGINE_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../Common/RingBuffer.hpp"

namespace vban {

// 独占发送通路枚举
enum class AsgnDir : uint8_t {
    Rx = 0, // 接收流回放至指定输出设备
    Tx = 1  // 指定输入设备采集并推流
};

// 单条流的设备指派记录
struct AsgnRec {
    std::string strm;   // 流名称
    std::string uid;    // 目标设备唯一标识
    uint32_t    ch{2};  // 设备声道数
    uint32_t    sr{48000};
};

// 流到设备的独占指派引擎
class RtEngn {
public:
    RtEngn() = default;

    // 依据接收流规格重建回放缓冲
    void rstbuf(const std::string& strm, uint32_t ch, uint32_t sr) {
        // 以流规格建立容量充足的缓冲
        if (ch == 0) ch = 2;
        if (sr == 0) sr = 48000;
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = rx_.find(strm);
        if (it != rx_.end() && it->second.ch == ch && it->second.sr == sr) {
            return;
        }
        auto& ent = rx_[strm];
        ent.ch = ch;
        ent.sr = sr;
        ent.buf = std::make_shared<RingBuf<float>>(kBufCap);
    }

    // 收取接收流浮点样本
    bool wrrx(const std::string& strm, const float* src, size_t cnt) {
        // 将接收样本写入对应流的回放缓冲
        if (!src || cnt == 0) return false;
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = rx_.find(strm);
        if (it == rx_.end() || !it->second.buf) return false;
        return it->second.buf->wrblks(src, cnt) == cnt;
    }

    // 提取接收流回放样本
    size_t rdrx(const std::string& strm, float* dst, size_t cnt) {
        // 从对应流缓冲读取待回放样本
        if (!dst || cnt == 0) return 0;
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = rx_.find(strm);
        if (it == rx_.end() || !it->second.buf) return 0;
        return it->second.buf->rdblks(dst, cnt);
    }

    // 查询接收流的已指派设备
    std::string gtrxdev(const std::string& strm) const {
        // 返回该流绑定的输出设备标识
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = rx_.find(strm);
        return (it == rx_.end() || !it->second.en) ? std::string() : it->second.dev;
    }

    // 将接收流指派到输出设备
    void setrxdev(const std::string& strm, const std::string& dev, uint32_t ch, uint32_t sr) {
        // 绑定接收流与其独占回放设备
        std::lock_guard<std::mutex> lock(mtx_);
        auto& ent = rx_[strm];
        ent.dev = dev;
        ent.en  = !dev.empty();
        ent.ch  = ch ? ch : ent.ch;
        ent.sr  = sr ? sr : ent.sr;
        if (!ent.buf) {
            ent.buf = std::make_shared<RingBuf<float>>(kBufCap);
        }
    }

    // 解除接收流的设备指派
    void clrrxdev(const std::string& strm) {
        // 取消该流的回放设备绑定
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = rx_.find(strm);
        if (it != rx_.end()) {
            it->second.dev.clear();
            it->second.en = false;
        }
    }

    // 将发送流指派到输入设备
    void settxdev(const std::string& strm, const std::string& dev, uint32_t ch, uint32_t sr) {
        // 绑定发送流与其独占采集设备
        std::lock_guard<std::mutex> lock(mtx_);
        auto& ent = tx_[strm];
        ent.dev = dev;
        ent.en  = !dev.empty();
        ent.ch  = ch ? ch : ent.ch;
        ent.sr  = sr ? sr : ent.sr;
        if (!ent.buf) {
            ent.buf = std::make_shared<RingBuf<float>>(kBufCap);
        }
    }

    // 查询发送流的已指派设备
    std::string gttxdev(const std::string& strm) const {
        // 返回该流绑定的输入设备标识
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = tx_.find(strm);
        return (it == tx_.end() || !it->second.en) ? std::string() : it->second.dev;
    }

    // 收取发送流采集样本
    bool wrtx(const std::string& strm, const float* src, size_t cnt) {
        // 将采集样本写入对应流的发送缓冲
        if (!src || cnt == 0) return false;
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = tx_.find(strm);
        if (it == tx_.end() || !it->second.buf) return false;
        return it->second.buf->wrblks(src, cnt) == cnt;
    }

    // 提取发送流采集样本
    size_t rdtx(const std::string& strm, float* dst, size_t cnt) {
        // 从对应流缓冲读取待发送样本
        if (!dst || cnt == 0) return 0;
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = tx_.find(strm);
        if (it == tx_.end() || !it->second.buf) return 0;
        return it->second.buf->rdblks(dst, cnt);
    }

    // 清空全部指派记录
    void clrall() {
        // 重置接收与发送两侧指派表
        std::lock_guard<std::mutex> lock(mtx_);
        rx_.clear();
        tx_.clear();
    }

private:
    // 单侧指派条目
    struct AsgnEnt {
        std::string                     dev;
        bool                            en{false};
        uint32_t                        ch{2};
        uint32_t                        sr{48000};
        std::shared_ptr<RingBuf<float>> buf;
    };

    static constexpr size_t kBufCap = 1u << 16;

    mutable std::mutex                    mtx_;
    std::unordered_map<std::string, AsgnEnt> rx_;
    std::unordered_map<std::string, AsgnEnt> tx_;
};

} // namespace vban

#endif // VBAN_ROUTE_ENGINE_HPP
