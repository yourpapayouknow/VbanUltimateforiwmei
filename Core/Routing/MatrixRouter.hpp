#ifndef VBAN_MATRIX_ROUTER_HPP
#define VBAN_MATRIX_ROUTER_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"

namespace vban {

// 矩阵端点类型
enum class EndpntTyp : uint8_t {
    Physical = 0, // 物理声卡麦克风/扬声器
    Cable    = 1, // 虚拟音频线缆
    Vban     = 2  // 网络VBAN数据流
};

// 矩阵端点描述
struct Endpnt {
    EndpntTyp   typ{EndpntTyp::Physical};
    std::string id;
    std::string name;
};

// 单条路由映射关系
struct RoutRule {
    std::string id;
    Endpnt      src;
    Endpnt      dst;
    bool        mut{false};
    bool        en{true};
};

// 矩阵路由处理器
class MtrxRtr {
public:
    MtrxRtr() = default;

    // 添加或更新路由规则
    bool addrout(const std::string& rid, const Endpnt& src, const Endpnt& dst) {
        // 创建新的源至目标映射规则
        if (rid.empty() || src.id.empty() || dst.id.empty()) {
            return false;
        }

        std::lock_guard<std::mutex> lock(mtx_);
        for (auto& r : rts_) {
            if (r.id == rid) {
                r.src  = src;
                r.dst  = dst;
                return true;
            }
        }

        rts_.push_back({rid, src, dst, false, true});
        return true;
    }

    // 移除指定路由
    bool rmvrout(const std::string& rid) {
        // 从矩阵中删除对应规则
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = std::remove_if(rts_.begin(), rts_.end(), [&](const RoutRule& r) {
            return r.id == rid;
        });
        if (it != rts_.end()) {
            rts_.erase(it, rts_.end());
            return true;
        }
        return false;
    }

    // 设置路由使能状态
    void tglrout(const std::string& rid, bool en) {
        // 切换规则开关
        std::lock_guard<std::mutex> lock(mtx_);
        for (auto& r : rts_) {
            if (r.id == rid) {
                r.en = en;
                break;
            }
        }
    }

    // 获取全部路由规则列表
    std::vector<RoutRule> gtrouts() const {
        // 返回全部路由规则副本
        std::lock_guard<std::mutex> lock(mtx_);
        return rts_;
    }

    // 针对指定源查找所有激活的目的地端点
    std::vector<Endpnt> fnddsts(const std::string& src_id) const {
        // 检索该源分发的目标端点
        std::vector<Endpnt> res;
        std::lock_guard<std::mutex> lock(mtx_);
        for (const auto& r : rts_) {
            if (r.en && !r.mut && r.src.id == src_id) {
                res.push_back(r.dst);
            }
        }
        return res;
    }

private:
    mutable std::mutex    mtx_;
    std::vector<RoutRule> rts_;
};

} // namespace vban

#endif // VBAN_MATRIX_ROUTER_HPP
