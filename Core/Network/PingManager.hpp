#ifndef VBAN_PING_MANAGER_HPP
#define VBAN_PING_MANAGER_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../VBAN/Protocol.hpp"
#include "UdpSocket.hpp"

namespace vban {

// 已接收节点数据描述
struct PingNode {
    std::string ip;
    uint16_t    port{6980};
    std::string userName;
    std::string hostName;
    std::string applicationName;
    std::string langCountry;
    std::string timeStamp;
    std::string version{"1.0"};
    uint32_t    colorRgb{0};
    bool        isReceived{true};
};

// VBAN Ping 服务协议管理器
class PingMgr {
public:
    // 获取单例实例
    static PingMgr& inst() {
        static PingMgr instance;
        return instance;
    }

    // 解析收到的服务探测报文
    bool prspkt(const uint8_t* dat, size_t len, const char* sip, uint16_t sprt) {
        if (!dat || len < kHdrSz + sizeof(VbanPing0Payload) || !sip) {
            return false;
        }

        const auto* hdr = reinterpret_cast<const HdrRaw*>(dat);
        if (hdr->mgc[0] != 'V' || hdr->mgc[1] != 'B' || hdr->mgc[2] != 'A' || hdr->mgc[3] != 'N') {
            return false;
        }

        // 校验 0x60 服务协议与标识服务
        if ((hdr->sr_prt & 0xE0) != 0x60) {
            return false;
        }
        if (hdr->nbc != kServiceIdentification) {
            return false;
        }
        if ((hdr->nbs & 0x7F) != kServiceFnctPing0) {
            return false;
        }

        const auto* pyld = reinterpret_cast<const VbanPing0Payload*>(dat + kHdrSz);

        PingNode node;
        node.ip = sip;
        node.port = sprt > 0 ? sprt : 6980;

        char buf[129];
        // 提取用户名
        std::memset(buf, 0, sizeof(buf));
        std::memcpy(buf, pyld->userName, sizeof(pyld->userName));
        node.userName = buf;

        // 提取主机名
        std::memset(buf, 0, sizeof(buf));
        std::memcpy(buf, pyld->hostName, sizeof(pyld->hostName));
        node.hostName = buf;

        // 提取应用程序名
        std::memset(buf, 0, sizeof(buf));
        std::memcpy(buf, pyld->applicationName, sizeof(pyld->applicationName));
        node.applicationName = buf;

        // 提取语言地区代码
        std::memset(buf, 0, sizeof(buf));
        std::memcpy(buf, pyld->langCode, sizeof(pyld->langCode));
        node.langCountry = buf;

        // 提取版本号
        node.version = std::to_string(pyld->nVersion[0]) + "." + std::to_string(pyld->nVersion[1]);

        // 生成当前时间戳
        auto now = std::chrono::system_clock::now();
        std::time_t tt = std::chrono::system_clock::to_time_t(now);
        std::tm localTm{};
        localtime_r(&tt, &localTm);
        char timeBuf[32];
        std::snprintf(timeBuf, sizeof(timeBuf), "%02d:%02d:%02d",
                      localTm.tm_hour, localTm.tm_min, localTm.tm_sec);
        node.timeStamp = timeBuf;
        node.colorRgb = pyld->colorRgb;
        node.isReceived = true;

        {
            std::lock_guard<std::mutex> lock(mtx_);
            nodes_[node.ip] = node;
            latest_ = node;
            has_latest_ = true;
        }

        return true;
    }

    // 获取最新接收到的 Ping 节点
    bool gtlatest(PingNode* out) {
        std::lock_guard<std::mutex> lock(mtx_);
        if (!has_latest_ || !out) {
            return false;
        }
        *out = latest_;
        return true;
    }

    // 获取全部发现的节点列表
    std::vector<PingNode> gtall() {
        std::lock_guard<std::mutex> lock(mtx_);
        std::vector<PingNode> res;
        res.reserve(nodes_.size());
        for (const auto& kv : nodes_) {
            res.push_back(kv.second);
        }
        return res;
    }

    // 发送包含本机信息的探测报文
    bool sndping(const char* dst_ip, uint16_t dst_port,
                 const char* app_name, const char* user_name,
                 const char* host_name, const char* lang_code) {
        if (!dst_ip) {
            return false;
        }

        uint8_t pkt[kHdrSz + sizeof(VbanPing0Payload)];
        std::memset(pkt, 0, sizeof(pkt));

        auto* hdr = reinterpret_cast<HdrRaw*>(pkt);
        hdr->mgc[0] = 'V';
        hdr->mgc[1] = 'B';
        hdr->mgc[2] = 'A';
        hdr->mgc[3] = 'N';
        hdr->sr_prt = 0x60;
        hdr->nbs    = kServiceFnctPing0;
        hdr->nbc    = kServiceIdentification;
        hdr->fmt_cdc= 0;
        std::strncpy(hdr->strm, "VBAN Ping", sizeof(hdr->strm) - 1);
        hdr->frm_cnt = ++frm_cnt_;

        auto* pyld = reinterpret_cast<VbanPing0Payload*>(pkt + kHdrSz);
        pyld->bitType = 0x0000004C; // MATRIX | RECEPTORSPOT | TRANSMITTERSPOT
        pyld->bitfeature = 0x00010001; // AUDIO | TXT
        pyld->preferedRate = 48000;
        pyld->minRate = 44100;
        pyld->maxRate = 192000;
        pyld->nVersion[0] = 1;
        pyld->nVersion[1] = 0;
        pyld->nVersion[2] = 0;
        pyld->nVersion[3] = 0;

        if (lang_code) std::strncpy(pyld->langCode, lang_code, sizeof(pyld->langCode) - 1);
        if (dst_ip) std::strncpy(pyld->distantIp, dst_ip, sizeof(pyld->distantIp) - 1);
        pyld->distantPort = dst_port > 0 ? dst_port : 6980;

        std::strncpy(pyld->deviceName, "Mac Audio Engine", sizeof(pyld->deviceName) - 1);
        std::strncpy(pyld->manufacturerName, "iwmei", sizeof(pyld->manufacturerName) - 1);
        if (app_name) std::strncpy(pyld->applicationName, app_name, sizeof(pyld->applicationName) - 1);
        if (host_name) std::strncpy(pyld->hostName, host_name, sizeof(pyld->hostName) - 1);
        if (user_name) std::strncpy(pyld->userName, user_name, sizeof(pyld->userName) - 1);
        std::strncpy(pyld->userComment, "VBAN Ultimate for macOS", sizeof(pyld->userComment) - 1);

        UdpSck sck;
        if (!sck.initsck()) {
            return false;
        }
        sck.enbldcast();

        ssize_t sent = sck.sndsck(dst_ip, dst_port > 0 ? dst_port : 6980, pkt, sizeof(pkt));
        return sent == static_cast<ssize_t>(sizeof(pkt));
    }

private:
    PingMgr() = default;

    std::mutex                      mtx_;
    std::unordered_map<std::string, PingNode> nodes_;
    PingNode                        latest_{};
    bool                            has_latest_{false};
    std::atomic<uint32_t>           frm_cnt_{0};
};

} // namespace vban

#endif // VBAN_PING_MANAGER_HPP
