#include <aspl/Driver.hpp>
#include <aspl/Device.hpp>
#include <aspl/Plugin.hpp>
#include <aspl/IORequestHandler.hpp>
#include <aspl/ControlRequestHandler.hpp>
#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <atomic>
#include <cmath>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

// 配置文件与全局监视路径
static const char* kCfgDir  = "/Library/Application Support/VBANUltimate";
static const char* kCfgPath = "/Library/Application Support/VBANUltimate/cables.plist";

// 虚拟线缆无锁环形缓冲区
struct CblRing {
    static constexpr uint32_t kFrms = 16384;
    uint32_t chs;
    uint32_t total;
    std::vector<float> buf;
    std::atomic<int64_t> last_frm{0};

    explicit CblRing(uint32_t c)
        : chs(c), total(kFrms * c), buf(kFrms * c, 0.0f) {}
};

// 虚拟音频硬件输入输出处理句柄
class CblIOHndlr : public aspl::IORequestHandler,
                   public aspl::ControlRequestHandler {
public:
    explicit CblIOHndlr(std::shared_ptr<CblRing> r)
        : own_ring_(std::move(r)), ring_(*own_ring_) {}

    // 音频写出处理：将外部App输出数据存入环形总线
    void OnWriteMixedOutput(
        const std::shared_ptr<aspl::Stream>&,
        Float64, Float64 ts,
        const void* buf, UInt32 bytes) override
    {
        const float* src = static_cast<const float*>(buf);
        const uint32_t n = bytes / sizeof(float);
        const int64_t frm = llround(ts);
        const uint64_t base = (uint64_t)frm * ring_.chs;
        for (uint32_t i = 0; i < n; ++i) {
            ring_.buf[(base + i) % ring_.total] = src[i];
        }
        ring_.last_frm.store(frm + n / ring_.chs, std::memory_order_release);
    }

    // 音频读取处理：将环形总线数据回环给外部App输入
    void OnReadClientInput(
        const std::shared_ptr<aspl::Client>&,
        const std::shared_ptr<aspl::Stream>&,
        Float64, Float64 ts,
        void* buf, UInt32 bytes) override
    {
        float* dst = static_cast<float*>(buf);
        const uint32_t n = bytes / sizeof(float);
        const int64_t frm = llround(ts);
        const int64_t frms = n / ring_.chs;
        if (ring_.last_frm.load(std::memory_order_acquire) - frms < frm) {
            std::memset(dst, 0, bytes);
            return;
        }
        const uint64_t base = (uint64_t)frm * ring_.chs;
        for (uint32_t i = 0; i < n; ++i) {
            dst[i] = ring_.buf[(base + i) % ring_.total];
        }
    }

private:
    std::shared_ptr<CblRing> own_ring_;
    CblRing&                 ring_;
};

// 虚拟设备配置结构
struct CblCfg {
    std::string id;
    std::string name;
    uint32_t    chs;
    uint32_t    sr;
};

// 工具函数：CFString转std::string
static std::string cf2str(CFStringRef s) {
    // 将CFString转为标准字符串
    if (!s) return {};
    if (const char* c = CFStringGetCStringPtr(s, kCFStringEncodingUTF8)) return c;
    CFIndex len = CFStringGetLength(s) * 4 + 1;
    std::string out(len, '\0');
    CFStringGetCString(s, out.data(), len, kCFStringEncodingUTF8);
    out.resize(std::strlen(out.c_str()));
    return out;
}

// 读取系统配置文件
static std::vector<CblCfg> rdcfg() {
    // 解析cables.plist设备定义文件
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        nullptr, (const UInt8*)kCfgPath, std::strlen(kCfgPath), false);
    if (!url) return {};

    CFReadStreamRef stream = CFReadStreamCreateWithFile(nullptr, url);
    CFRelease(url);
    if (!stream || !CFReadStreamOpen(stream)) {
        if (stream) CFRelease(stream);
        return {};
    }

    CFErrorRef err = nullptr;
    CFPropertyListRef plist = CFPropertyListCreateWithStream(
        nullptr, stream, 0, kCFPropertyListImmutable, nullptr, &err);
    CFReadStreamClose(stream);
    CFRelease(stream);
    if (err) CFRelease(err);

    if (!plist || CFGetTypeID(plist) != CFArrayGetTypeID()) {
        if (plist) CFRelease(plist);
        return {};
    }

    std::vector<CblCfg> out;
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
            if (v >= 1 && v <= 256) chs = (uint32_t)v;
        }
        uint32_t sr = 48000;
        CFNumberRef srv = (CFNumberRef)CFDictionaryGetValue(d, CFSTR("sampleRate"));
        if (srv && CFGetTypeID(srv) == CFNumberGetTypeID()) {
            int v = 0;
            CFNumberGetValue(srv, kCFNumberIntType, &v);
            if (v >= 8000 && v <= 384000) sr = (uint32_t)v;
        }
        if (!id.empty() && !name.empty()) {
            out.push_back({id, name, chs, sr});
        }
    }
    CFRelease(plist);
    return out;
}

// 缓存条目
struct DevEnt {
    std::shared_ptr<aspl::Device>   dev;
    std::shared_ptr<CblIOHndlr>     hndlr;
    uint32_t                        chs;
    uint32_t                        sr;
};

static std::shared_ptr<aspl::Context> gCtx;
static std::shared_ptr<aspl::Plugin>  gPlg;
static std::map<std::string, DevEnt>  gDevs;
static std::mutex                     gMtx;

// 构造浮点音频流格式
static AudioStreamBasicDescription bldfmt(UInt32 chs, Float64 sr) {
    // 构造原生单精度浮点流格式描述
    AudioStreamBasicDescription f{};
    f.mSampleRate       = sr;
    f.mFormatID         = kAudioFormatLinearPCM;
    f.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    f.mBitsPerChannel   = 32;
    f.mChannelsPerFrame = chs;
    f.mBytesPerFrame    = chs * sizeof(float);
    f.mFramesPerPacket  = 1;
    f.mBytesPerPacket   = chs * sizeof(float);
    return f;
}

// 依据配置构造虚拟设备实例
static DevEnt blddev(const CblCfg& cfg) {
    // 创建虚拟设备并绑定输入输出流与回环句柄
    auto ring  = std::make_shared<CblRing>(cfg.chs);
    auto hndlr = std::make_shared<CblIOHndlr>(ring);

    aspl::DeviceParameters params;
    params.Name         = cfg.name;
    params.Manufacturer = "VBAN Ultimate";
    params.DeviceUID    = "com.iwmei.vbanultimate.audio." + cfg.id;
    params.ModelUID     = "com.iwmei.vbanultimate.audio.model";
    params.SampleRate   = cfg.sr;
    params.ChannelCount = cfg.chs;
    params.EnableMixing = true;

    auto dev = std::make_shared<aspl::Device>(gCtx, params);
    dev->SetIOHandler(hndlr);
    dev->SetControlHandler(hndlr);

    aspl::StreamParameters out_strm;
    out_strm.Direction = aspl::Direction::Output;
    out_strm.Format = bldfmt(params.ChannelCount, params.SampleRate);
    dev->AddStreamWithControlsAsync(out_strm);

    aspl::StreamParameters in_strm;
    in_strm.Direction = aspl::Direction::Input;
    in_strm.Format = bldfmt(params.ChannelCount, params.SampleRate);
    dev->AddStreamWithControlsAsync(in_strm);

    return {dev, hndlr, cfg.chs, cfg.sr};
}

// 动态同步设备集合
static void syncdevs() {
    // 比对配置文件并动态执行添加与移除设备
    const auto cfgs = rdcfg();
    std::lock_guard<std::mutex> lock(gMtx);

    for (auto it = gDevs.begin(); it != gDevs.end();) {
        const auto* c = [&]() -> const CblCfg* {
            for (const auto& item : cfgs) if (item.id == it->first) return &item;
            return nullptr;
        }();

        if (!c || c->chs != it->second.chs || c->sr != it->second.sr || c->name != it->second.dev->GetName()) {
            gPlg->RemoveDevice(it->second.dev);
            it = gDevs.erase(it);
        } else {
            ++it;
        }
    }

    for (const auto& c : cfgs) {
        if (gDevs.count(c.id)) continue;
        auto ent = blddev(c);
        gPlg->AddDevice(ent.dev);
        gDevs.emplace(c.id, std::move(ent));
    }
}

static void strtwtch();

// 启动目录文件监听
static void strtwtch() {
    // 监听配置文件目录变动信号
    int fd = open(kCfgDir, O_EVTONLY);
    if (fd < 0) return;

    dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_source_t src = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_VNODE, fd,
        DISPATCH_VNODE_WRITE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_DELETE, q);
    if (!src) {
        close(fd);
        return;
    }

    dispatch_source_set_event_handler(src, ^{
        const unsigned long flgs = dispatch_source_get_data(src);
        syncdevs();
        if (flgs & (DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME)) {
            dispatch_source_cancel(src);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), q, ^{
                strtwtch();
            });
        }
    });

    dispatch_source_set_cancel_handler(src, ^{
        close(fd);
        dispatch_release(src);
    });

    dispatch_resume(src);
}

// 驱动构造器
static std::shared_ptr<aspl::Driver> crtdrv() {
    // 初始化CoreAudio插件驱动实例
    gCtx = std::make_shared<aspl::Context>();
    gPlg = std::make_shared<aspl::Plugin>(gCtx);

    auto drv = std::make_shared<aspl::Driver>(gCtx, gPlg);
    syncdevs();
    strtwtch();
    return drv;
}

// 驱动标准导出符号入口
extern "C" void* EntryPoint(CFAllocatorRef, CFUUIDRef type_uuid) {
    // 导出AudioServerPlugIn插件工厂句柄
    if (!CFEqual(type_uuid, kAudioServerPlugInTypeUUID)) return nullptr;
    static std::shared_ptr<aspl::Driver> drv = crtdrv();
    return drv->GetReference();
}
