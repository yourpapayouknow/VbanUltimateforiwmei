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

// 服务协议常量
inline constexpr uint8_t kServiceIdentification = 0;
inline constexpr uint8_t kServiceFnctPing0       = 0;
inline constexpr uint8_t kServiceFnctReply       = 0x80;

#pragma pack(push, 1)
// VBAN PING0 官方数据载荷结构
struct VbanPing0Payload {
    uint32_t bitType;             // VBAN 设备能力类型
    uint32_t bitfeature;          // 支持的协议特性
    uint32_t bitfeatureEx;        // 扩展特性掩码
    uint32_t preferedRate;        // 首选采样率
    uint32_t minRate;             // 支持的最低采样率
    uint32_t maxRate;             // 支持的最高采样率
    uint32_t colorRgb;            // 用户颜色值
    uint8_t  nVersion[4];         // 应用版本号
    char     gpsPosition[8];      // GPS 定位数据
    char     userPosition[8];     // 用户进程定位数据
    char     langCode[8];         // 用户主要语言地区代码
    char     reservedAscii[8];    // 保留字段
    char     reservedEx[64];      // 扩展保留字段
    char     distantIp[32];       // 对端 IP
    uint16_t distantPort;         // 对端端口
    uint16_t distantReserved;     // 对端保留
    char     deviceName[64];      // 物理设备名称
    char     manufacturerName[64];// 制造商品牌名称
    char     applicationName[64]; // 应用程序名称
    char     hostName[64];        // 网络主机名
    char     userName[128];       // 用户名
    char     userComment[128];    // 用户备注信息
};
#pragma pack(pop)

static_assert(sizeof(VbanPing0Payload) == 676, "VBAN PING0 payload must be exactly 676 bytes");

} // namespace vban

#endif // VBAN_PROTOCOL_HPP
