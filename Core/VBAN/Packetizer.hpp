#ifndef VBAN_PACKETIZER_HPP
#define VBAN_PACKETIZER_HPP

#include "Protocol.hpp"

namespace vban {

// 构建VBAN数据包报头
inline bool bldhdr(HdrRaw* hdr,
                   const char* strm,
                   uint32_t sr,
                   uint32_t ch,
                   uint32_t smpls,
                   SmplFmt fmt,
                   uint32_t frmcnt) {
    // 组装28字节标准报头字段
    if (!hdr || !strm || ch == 0 || ch > 256 || smpls == 0 || smpls > 256) {
        return false;
    }

    const int32_t sridx = fndsridx(sr);
    if (sridx < 0) {
        return false;
    }

    hdr->mgc[0] = 'V';
    hdr->mgc[1] = 'B';
    hdr->mgc[2] = 'A';
    hdr->mgc[3] = 'N';

    // 默认音频子协议 (0x00) | 采样率索引 (0x1F)
    hdr->sr_prt = static_cast<uint8_t>(sridx & 0x1F);
    hdr->nbs    = static_cast<uint8_t>(smpls - 1);
    hdr->nbc    = static_cast<uint8_t>(ch - 1);

    // 默认PCM编码 (0x00) | 格式格式掩码 (0x07)
    hdr->fmt_cdc = static_cast<uint8_t>(static_cast<uint8_t>(fmt) & 0x07);

    std::memset(hdr->strm, 0, kStrmSz);
    const size_t slen = std::min(std::strlen(strm), static_cast<size_t>(kStrmSz));
    std::memcpy(hdr->strm, strm, slen);

    hdr->frm_cnt = frmcnt;
    return true;
}

// 打包完整VBAN网络音频数据报文
inline size_t bldpkt(uint8_t* dst,
                     size_t maxlen,
                     const char* strm,
                     uint32_t sr,
                     uint32_t ch,
                     uint32_t smpls,
                     SmplFmt fmt,
                     uint32_t frmcnt,
                     const void* pyld,
                     size_t pyldlen) {
    // 打包头部与PCM负载到目标缓冲区
    if (!dst || maxlen < kHdrSz + pyldlen || !pyld) {
        return 0;
    }

    auto* hdr = reinterpret_cast<HdrRaw*>(dst);
    if (!bldhdr(hdr, strm, sr, ch, smpls, fmt, frmcnt)) {
        return 0;
    }

    std::memcpy(dst + kHdrSz, pyld, pyldlen);
    return kHdrSz + pyldlen;
}

} // namespace vban

#endif // VBAN_PACKETIZER_HPP
