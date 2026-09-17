#ifndef VBAN_PARSER_HPP
#define VBAN_PARSER_HPP

#include "Protocol.hpp"

namespace vban {

// 校验头部魔数有效性
inline bool chkmgc(const HdrRaw* hdr) {
    // 校验前四字节是否为VBAN标识
    return hdr->mgc[0] == 'V' &&
           hdr->mgc[1] == 'B' &&
           hdr->mgc[2] == 'A' &&
           hdr->mgc[3] == 'N';
}

// 零拷贝解析VBAN网络数据包
inline bool prspkt(const uint8_t* dat, size_t len, PktInf* out) {
    // 解析传入的网络原始字节流为结构体
    if (!dat || len < kHdrSz || !out) {
        return false;
    }

    const auto* hdr = reinterpret_cast<const HdrRaw*>(dat);
    if (!chkmgc(hdr)) {
        return false;
    }

    const uint8_t prtval = hdr->sr_prt & 0xE0;
    out->proto = static_cast<ProtoSub>(prtval);

    const uint8_t sridx = hdr->sr_prt & 0x1F;
    if (sridx >= 21) {
        return false;
    }
    out->sr = gtsrval(sridx);

    out->smpls = static_cast<uint32_t>(hdr->nbs) + 1;
    out->ch    = static_cast<uint32_t>(hdr->nbc) + 1;

    const uint8_t fmtval = hdr->fmt_cdc & 0x07;
    out->fmt   = static_cast<SmplFmt>(fmtval);
    out->bpsz  = gtbpsz(out->fmt);
    if (out->bpsz == 0) {
        return false;
    }

    const uint32_t exp_pyld = out->smpls * out->ch * out->bpsz;
    if (len < kHdrSz + exp_pyld) {
        return false;
    }

    out->pyldsz = exp_pyld;
    out->frmcnt = hdr->frm_cnt;
    out->pyld   = dat + kHdrSz;

    std::memcpy(out->strm, hdr->strm, kStrmSz);
    out->strm[kStrmSz] = '\0';

    return true;
}

} // namespace vban

#endif // VBAN_PARSER_HPP
