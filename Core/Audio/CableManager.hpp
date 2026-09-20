#ifndef VBAN_CABLE_MANAGER_HPP
#define VBAN_CABLE_MANAGER_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "DeviceCatalog.hpp"
#include <sys/stat.h>

namespace vban {

#if defined(__APPLE__)

// 虚拟线缆描述项
struct CblItem {
    std::string id;
    std::string name;
    uint32_t    chs{2};
    uint32_t    sr{96000};
    bool        en{true};
};

// 虚拟音频线缆生命周期管理器
class CblMgr {
public:
    explicit CblMgr(std::string cfg_dir = "") {
        if (cfg_dir.empty()) {
            const char* sys_dir = "/Library/Application Support/VBANUltimate";
            if (::access(sys_dir, W_OK) == 0) {
                cfg_dir_ = sys_dir;
            } else {
                const char* home = std::getenv("HOME");
                if (home) {
                    std::string user_dir = std::string(home) + "/Library/Application Support/VBANUltimate";
                    ::mkdir(user_dir.c_str(), 0755);
                    cfg_dir_ = user_dir;
                } else {
                    cfg_dir_ = sys_dir;
                }
            }
        } else {
            cfg_dir_ = std::move(cfg_dir);
        }
        cfg_path_ = cfg_dir_ + "/cables.plist";
        ldcfg();
    }

    // 添加新的虚拟音频线缆
    bool addcbl(const std::string& id, const std::string& name, uint32_t chs = 2, uint32_t sr = 96000) {
        // 向配置集合添加新线缆并同步保存
        if (id.empty() || name.empty() || chs == 0) {
            return false;
        }

        std::lock_guard<std::mutex> lock(mtx_);
        for (const auto& c : cbls_) {
            if (c.id == id) {
                return false; // UID已存在
            }
        }

        cbls_.push_back({id, name, chs, sr, true});
        svcfg();
        return true;
    }

    // 删除指定虚拟音频线缆
    bool rmvcbl(const std::string& id) {
        // 从配置集合中删除指定ID线缆并同步保存
        std::lock_guard<std::mutex> lock(mtx_);
        auto it = std::remove_if(cbls_.begin(), cbls_.end(), [&](const CblItem& item) {
            return item.id == id;
        });
        if (it != cbls_.end()) {
            cbls_.erase(it, cbls_.end());
            svcfg();
            return true;
        }
        return false;
    }

    // 重命名指定虚拟线缆
    bool rnmcbl(const std::string& id, const std::string& new_name) {
        if (new_name.empty()) return false;
        std::lock_guard<std::mutex> lock(mtx_);
        for (auto& c : cbls_) {
            if (c.id == id) {
                c.name = new_name;
                svcfg();
                return true;
            }
        }
        return false;
    }

    // 更新虚拟线缆全量配置参数
    bool updcbl(const std::string& id, const std::string& name, uint32_t chs, uint32_t sr) {
        if (id.empty() || name.empty() || chs == 0 || sr == 0) return false;
        std::lock_guard<std::mutex> lock(mtx_);
        for (auto& c : cbls_) {
            if (c.id == id) {
                c.name = name;
                c.chs = chs;
                c.sr = sr;
                svcfg();
                return true;
            }
        }
        return false;
    }

    // 获取当前全部受管虚拟线缆
    std::vector<CblItem> gtcbls() const {
        // 返回虚拟线缆配置列表副本
        std::lock_guard<std::mutex> lock(mtx_);
        return cbls_;
    }

    // 检查驱动安装与健康状态
    bool chkdrvr(std::string* out_ver = nullptr) const {
        // 检查HAL驱动插件文件是否存在
        const char* drv_path = "/Library/Audio/Plug-Ins/HAL/VBANUltimateAudio.driver";
        if (::access(drv_path, F_OK) == 0) {
            if (out_ver) *out_ver = "1.0";
            return true;
        }
        return false;
    }

private:
    // 从plist加载已有配置
    void ldcfg() {
        // 读取并反序列化配置文件
        CFURLRef url = CFURLCreateFromFileSystemRepresentation(
            nullptr, (const UInt8*)cfg_path_.c_str(), cfg_path_.size(), false);
        if (!url) return;

        CFReadStreamRef stream = CFReadStreamCreateWithFile(nullptr, url);
        CFRelease(url);
        if (!stream || !CFReadStreamOpen(stream)) {
            if (stream) CFRelease(stream);
            return;
        }

        CFErrorRef err = nullptr;
        CFPropertyListRef plist = CFPropertyListCreateWithStream(
            nullptr, stream, 0, kCFPropertyListImmutable, nullptr, &err);
        CFReadStreamClose(stream);
        CFRelease(stream);
        if (err) CFRelease(err);

        if (!plist || CFGetTypeID(plist) != CFArrayGetTypeID()) {
            if (plist) CFRelease(plist);
            return;
        }

        std::lock_guard<std::mutex> lock(mtx_);
        cbls_.clear();
        CFArrayRef arr = (CFArrayRef)plist;
        for (CFIndex i = 0; i < CFArrayGetCount(arr); ++i) {
            CFDictionaryRef d = (CFDictionaryRef)CFArrayGetValueAtIndex(arr, i);
            if (CFGetTypeID(d) != CFDictionaryGetTypeID()) continue;
            std::string id   = cf2str((CFStringRef)CFDictionaryGetValue(d, CFSTR("id")));
            std::string name = cf2str((CFStringRef)CFDictionaryGetValue(d, CFSTR("name")));
            uint32_t chs = 2;
            CFNumberRef ch = (CFNumberRef)CFDictionaryGetValue(d, CFSTR("channels"));
            if (ch && CFGetTypeID(ch) == CFNumberGetTypeID()) {
                int v = 0;
                CFNumberGetValue(ch, kCFNumberIntType, &v);
                if (v >= 1 && v <= 256) chs = static_cast<uint32_t>(v);
            }
            uint32_t sr = 96000;
            CFNumberRef srv = (CFNumberRef)CFDictionaryGetValue(d, CFSTR("sampleRate"));
            if (srv && CFGetTypeID(srv) == CFNumberGetTypeID()) {
                int v = 0;
                CFNumberGetValue(srv, kCFNumberIntType, &v);
                if (v >= 8000 && v <= 384000) sr = static_cast<uint32_t>(v);
            }
            if (!id.empty() && !name.empty()) {
                cbls_.push_back({id, name, chs, sr, true});
            }
        }
        CFRelease(plist);
    }

    // 原子持久化写入plist配置
    bool svcfg() {
        // 将线缆列表以原子替换写入目标文件
        CFMutableArrayRef arr = CFArrayCreateMutable(kCFAllocatorDefault, cbls_.size(), &kCFTypeArrayCallBacks);
        for (const auto& c : cbls_) {
            CFMutableDictionaryRef dict = CFDictionaryCreateMutable(
                kCFAllocatorDefault, 4,
                &kCFTypeDictionaryKeyCallBacks,
                &kCFTypeDictionaryValueCallBacks);

            CFStringRef cid = CFStringCreateWithCString(kCFAllocatorDefault, c.id.c_str(), kCFStringEncodingUTF8);
            CFStringRef cnm = CFStringCreateWithCString(kCFAllocatorDefault, c.name.c_str(), kCFStringEncodingUTF8);
            int ch = static_cast<int>(c.chs);
            int sr = static_cast<int>(c.sr);
            CFNumberRef cch = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &ch);
            CFNumberRef csr = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &sr);

            CFDictionarySetValue(dict, CFSTR("id"), cid);
            CFDictionarySetValue(dict, CFSTR("name"), cnm);
            CFDictionarySetValue(dict, CFSTR("channels"), cch);
            CFDictionarySetValue(dict, CFSTR("sampleRate"), csr);

            CFArrayAppendValue(arr, dict);

            CFRelease(cid);
            CFRelease(cnm);
            CFRelease(cch);
            CFRelease(csr);
            CFRelease(dict);
        }

        CFDataRef xml_data = CFPropertyListCreateData(
            kCFAllocatorDefault, arr, kCFPropertyListXMLFormat_v1_0, 0, nullptr);
        CFRelease(arr);

        if (!xml_data) {
            return false;
        }

        // 写入临时文件并通过 rename 原子替换
        ::mkdir(cfg_dir_.c_str(), 0755);
        std::string tmp_path = cfg_path_ + ".tmp";
        FILE* fp = std::fopen(tmp_path.c_str(), "wb");
        if (!fp) {
            CFRelease(xml_data);
            return false;
        }

        const UInt8* bytes = CFDataGetBytePtr(xml_data);
        const CFIndex len  = CFDataGetLength(xml_data);
        size_t written = std::fwrite(bytes, 1, len, fp);
        std::fclose(fp);
        CFRelease(xml_data);

        if (written == static_cast<size_t>(len)) {
            ::rename(tmp_path.c_str(), cfg_path_.c_str());
            return true;
        }
        return false;
    }

    std::string          cfg_dir_;
    std::string          cfg_path_;
    mutable std::mutex   mtx_;
    std::vector<CblItem> cbls_;
};

#endif // __APPLE__

} // namespace vban

#endif // VBAN_CABLE_MANAGER_HPP
