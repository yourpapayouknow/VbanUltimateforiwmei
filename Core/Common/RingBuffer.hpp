#ifndef VBAN_RING_BUFFER_HPP
#define VBAN_RING_BUFFER_HPP

#include "Head.hpp"

namespace vban {

// 无锁单读单写音频环形缓冲区 (RT-Safe SPSC)
template <typename T>
class RingBuf {
public:
    // 构造指定容量环形缓冲 (自动对齐为2的幂)
    explicit RingBuf(size_t cap = 16384)
        : cap_(rndpow2(cap)),
          mask_(cap_ - 1),
          buf_(new T[cap_]),
          wridx_(0),
          rdidx_(0) {
        std::memset(buf_.get(), 0, sizeof(T) * cap_);
    }

    ~RingBuf() = default;

    // 禁止拷贝
    RingBuf(const RingBuf&) = delete;
    RingBuf& operator=(const RingBuf&) = delete;

    // 重置缓冲区读写游标
    void rstbuf() {
        // 重置游标为零
        wridx_.store(0, std::memory_order_relaxed);
        rdidx_.store(0, std::memory_order_relaxed);
    }

    // 获取当前可读元素数量
    size_t gtavlr() const {
        // 计算已写入但尚未读取的样本量
        const size_t w = wridx_.load(std::memory_order_acquire);
        const size_t r = rdidx_.load(std::memory_order_relaxed);
        return w - r;
    }

    // 获取当前可写剩余空间
    size_t gtavlw() const {
        // 计算剩余未被填写的样本空位
        const size_t w = wridx_.load(std::memory_order_relaxed);
        const size_t r = rdidx_.load(std::memory_order_acquire);
        return cap_ - (w - r);
    }

    // 写入指定数量数据
    size_t wrblks(const T* src, size_t cnt) {
        // 将源连续数据拷贝进环形区
        if (!src || cnt == 0) {
            return 0;
        }

        const size_t avl = gtavlw();
        const size_t to_wr = std::min(cnt, avl);
        if (to_wr == 0) {
            return 0;
        }

        const size_t w = wridx_.load(std::memory_order_relaxed);
        const size_t idx = w & mask_;

        const size_t first = std::min(to_wr, cap_ - idx);
        std::memcpy(&buf_[idx], src, first * sizeof(T));

        const size_t second = to_wr - first;
        if (second > 0) {
            std::memcpy(&buf_[0], src + first, second * sizeof(T));
        }

        wridx_.store(w + to_wr, std::memory_order_release);
        return to_wr;
    }

    // 读取指定数量数据 (不足部分用静音填充)
    size_t rdblks(T* dst, size_t cnt) {
        // 从环形区读取连续数据
        if (!dst || cnt == 0) {
            return 0;
        }

        const size_t avl = gtavlr();
        const size_t to_rd = std::min(cnt, avl);

        if (to_rd > 0) {
            const size_t r = rdidx_.load(std::memory_order_relaxed);
            const size_t idx = r & mask_;

            const size_t first = std::min(to_rd, cap_ - idx);
            std::memcpy(dst, &buf_[idx], first * sizeof(T));

            const size_t second = to_rd - first;
            if (second > 0) {
                std::memcpy(dst + first, &buf_[0], second * sizeof(T));
            }

            rdidx_.store(r + to_rd, std::memory_order_release);
        }

        // 不足部分静音填充
        if (to_rd < cnt) {
            std::memset(dst + to_rd, 0, (cnt - to_rd) * sizeof(T));
        }

        return to_rd;
    }

    // 获取缓冲区物理总容量
    size_t gtcap() const {
        // 返回对齐后的容量
        return cap_;
    }

private:
    // 计算不小于输入值的最小2次幂
    static size_t rndpow2(size_t val) {
        // 对齐容量至2的整数幂
        size_t r = 1;
        while (r < val) {
            r <<= 1;
        }
        return r;
    }

    const size_t               cap_;
    const size_t               mask_;
    std::unique_ptr<T[]>       buf_;
    alignas(64) std::atomic<size_t> wridx_;
    alignas(64) std::atomic<size_t> rdidx_;
};

} // namespace vban

#endif // VBAN_RING_BUFFER_HPP
