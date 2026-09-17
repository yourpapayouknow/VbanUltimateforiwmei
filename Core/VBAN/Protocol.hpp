#ifndef VBAN_PROTOCOL_HPP
#define VBAN_PROTOCOL_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"

namespace vban {

#pragma pack(push, 1)
// VBAN 官方 28 字节紧凑报头结构
struct HdrRaw {
    char     mgc[4];     // 'V', 'B', 'A', 'N'
    uint8_t  sr_prt;     // 协议与采样率索引复合字段
    uint8_t  nbs;        // 帧采样数减1
    uint8_t  nbc;        // 声道数减1
    uint8_t  fmt_cdc;    // 格式与编解码掩码
    char     strm[16];   // 流标识名称
    uint32_t frm_cnt;    // 递增包计数器
};
#pragma pack(pop)

static_assert(sizeof(HdrRaw) == 28, "VBAN header must be exactly 28 bytes");

inline constexpr uint32_t kHdrSz   = 28;
inline constexpr uint32_t kMaxPkt  = 1464;
inline constexpr uint32_t kMaxPyld = kMaxPkt - kHdrSz;
inline constexpr uint32_t kStrmSz  = 16;

// 结构化解析结果
struct PktInf {
    ProtoSub proto;
    uint32_t sr;
    uint32_t ch;
    uint32_t smpls;
    SmplFmt  fmt;
    uint32_t bpsz;
    uint32_t pyldsz;
    uint32_t frmcnt;
    char     strm[kStrmSz + 1];
    const uint8_t* pyld;
};

} // namespace vban

#endif // VBAN_PROTOCOL_HPP
