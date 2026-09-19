#ifndef VBAN_COMMON_TYPES_HPP
#define VBAN_COMMON_TYPES_HPP

#include "Head.hpp"

namespace vban {

// 官方标准采样率列表 (21种)
inline constexpr uint32_t kSrList[21] = {
    6000, 12000, 24000, 48000, 96000, 192000, 384000,
    8000, 16000, 32000, 64000, 128000, 256000, 512000,
    11025, 22050, 44100, 88200, 176400, 352800, 705600
};

// 协议子类型枚举
enum class ProtoSub : uint8_t {
    Audio   = 0x00,
    Serial  = 0x20,
    Txt     = 0x40,
    Service = 0x60,
    Undef1  = 0x80,
    Undef2  = 0xA0,
    Undef3  = 0xC0,
    Undef4  = 0xE0
};

// 采样位深与编码格式
enum class SmplFmt : uint8_t {
    Int8    = 0,
    Int16   = 1,
    Int24   = 2,
    Int32   = 3,
    Float32 = 4,
    Float64 = 5,
    Int12   = 6,
    Int10   = 7
};

// 流方向
enum class StrmDir : uint8_t {
    Rx = 0,
    Tx = 1
};

// 流状态
enum class StrmStt : uint8_t {
    Offline = 0,
    Active  = 1,
    Muted   = 2,
    Err     = 3
};

// 获取位深字节大小
inline uint32_t gtbpsz(SmplFmt fmt) {
    // 获取格式对应的字节宽度
    switch (fmt) {
        case SmplFmt::Int8:    return 1;
        case SmplFmt::Int16:   return 2;
        case SmplFmt::Int24:   return 3;
        case SmplFmt::Int32:   return 4;
        case SmplFmt::Float32: return 4;
        case SmplFmt::Float64: return 8;
        default:               return 0;
    }
}

// 依据采样率查询索引
inline int32_t fndsridx(uint32_t sr) {
    // 匹配采样率在列表中的索引
    for (int32_t i = 0; i < 21; ++i) {
        if (kSrList[i] == sr) {
            return i;
        }
    }
    return -1;
}

// 依据索引获取采样率数值
inline uint32_t gtsrval(uint8_t idx) {
    // 获取指定索引的标准采样率
    if (idx < 21) {
        return kSrList[idx];
    }
    return 0;
}

} // namespace vban

#endif // VBAN_COMMON_TYPES_HPP
