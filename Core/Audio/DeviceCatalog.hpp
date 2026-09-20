#ifndef VBAN_DEVICE_CATALOG_HPP
#define VBAN_DEVICE_CATALOG_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"

namespace vban {

#if defined(__APPLE__)

// 系统物理/虚拟音频设备信息
struct DevInf {
    AudioDeviceID id{0};
    std::string   uid;
    std::string   name;
    uint32_t      inchs{0};
    uint32_t      outchs{0};
    double        sr{96000.0};
    bool          is_dfltin{false};
    bool          is_dfltout{false};
};

// 工具函数：CFString转std::string
inline std::string cf2str(CFStringRef s) {
    // 将CFString安全转为标准字符串
    if (!s) return {};
    if (const char* c = CFStringGetCStringPtr(s, kCFStringEncodingUTF8)) {
        return c;
    }
    CFIndex len = CFStringGetLength(s) * 4 + 1;
    std::string out(len, '\0');
    CFStringGetCString(s, out.data(), len, kCFStringEncodingUTF8);
    out.resize(std::strlen(out.c_str()));
    return out;
}

// 计算指定设备指定方向的通道数
inline uint32_t calcchs(AudioDeviceID dev, AudioObjectPropertyScope scp) {
    // 查询流配置并累计声道数
    AudioObjectPropertyAddress addr{
        kAudioDevicePropertyStreamConfiguration,
        scp,
        kAudioObjectPropertyElementMain
    };

    UInt32 sz = 0;
    if (AudioObjectGetPropertyDataSize(dev, &addr, 0, nullptr, &sz) != noErr || sz == 0) {
        return 0;
    }

    auto buf = std::make_unique<uint8_t[]>(sz);
    auto* b = reinterpret_cast<AudioBufferList*>(buf.get());
    if (AudioObjectGetPropertyData(dev, &addr, 0, nullptr, &sz, b) != noErr) {
        return 0;
    }

    uint32_t total = 0;
    for (UInt32 i = 0; i < b->mNumberBuffers; ++i) {
        total += b->mBuffers[i].mNumberChannels;
    }
    return total;
}

// 枚举 macOS 系统内所有已加载的 CoreAudio 物理与虚拟设备
inline std::vector<DevInf> enumdevs() {
    // 遍历系统硬件属性获取全部音频设备
    std::vector<DevInf> list;

    AudioObjectPropertyAddress addr{
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };

    UInt32 sz = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, nullptr, &sz) != noErr) {
        return list;
    }

    UInt32 count = sz / sizeof(AudioDeviceID);
    std::vector<AudioDeviceID> devs(count);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, nullptr, &sz, devs.data()) != noErr) {
        return list;
    }

    // 获取默认输入与输出设备
    AudioDeviceID dflt_in = 0, dflt_out = 0;
    UInt32 dsz = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress in_addr{
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &in_addr, 0, nullptr, &dsz, &dflt_in);

    AudioObjectPropertyAddress out_addr{
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &out_addr, 0, nullptr, &dsz, &dflt_out);

    for (auto dev : devs) {
        DevInf inf{};
        inf.id = dev;
        inf.is_dfltin  = (dev == dflt_in);
        inf.is_dfltout = (dev == dflt_out);

        // 获取设备名称
        CFStringRef cfn = nullptr;
        UInt32 nsz = sizeof(CFStringRef);
        AudioObjectPropertyAddress n_addr{
            kAudioDevicePropertyDeviceNameCFString,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        if (AudioObjectGetPropertyData(dev, &n_addr, 0, nullptr, &nsz, &cfn) == noErr && cfn) {
            inf.name = cf2str(cfn);
            CFRelease(cfn);
        }

        // 获取设备UID
        CFStringRef cfu = nullptr;
        UInt32 usz = sizeof(CFStringRef);
        AudioObjectPropertyAddress u_addr{
            kAudioDevicePropertyDeviceUID,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        if (AudioObjectGetPropertyData(dev, &u_addr, 0, nullptr, &usz, &cfu) == noErr && cfu) {
            inf.uid = cf2str(cfu);
            CFRelease(cfu);
        }

        // 获取标称采样率
        Float64 sr = 48000.0;
        UInt32 srsz = sizeof(Float64);
        AudioObjectPropertyAddress sr_addr{
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        if (AudioObjectGetPropertyData(dev, &sr_addr, 0, nullptr, &srsz, &sr) == noErr) {
            inf.sr = sr;
        }

        inf.inchs  = calcchs(dev, kAudioDevicePropertyScopeInput);
        inf.outchs = calcchs(dev, kAudioDevicePropertyScopeOutput);

        list.push_back(std::move(inf));
    }

    return list;
}

#endif // __APPLE__

} // namespace vban

#endif // VBAN_DEVICE_CATALOG_HPP
