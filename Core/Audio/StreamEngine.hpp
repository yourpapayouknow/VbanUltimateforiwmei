#ifndef VBAN_STREAM_ENGINE_HPP
#define VBAN_STREAM_ENGINE_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "DeviceCatalog.hpp"
#include "../Routing/RouteEngine.hpp"

namespace vban {

#if defined(__APPLE__)

// 流的音频规格
struct StrmCfg {
    uint32_t ch{0};
    uint32_t sr{0};
    SmplFmt  fmt{SmplFmt::Int16};

    // 比对流规格是否一致
    bool opeq(const StrmCfg& o) const {
        // 三者完全相同方视为同一规格
        return ch == o.ch && sr == o.sr && fmt == o.fmt;
    }
};

// 单条 VBAN 流的设备收发引擎
class StrmEngn {
public:
    explicit StrmEngn(std::shared_ptr<RtEngn> rt) : rt_(std::move(rt)) {}
    ~StrmEngn() { stpall(); }

    // 按网络质量档位换算起播预填帧数
    static uint32_t qltfrms(uint8_t qlt, uint32_t ch, uint32_t sr) {
        // 对齐官方 computeSize：档位决定可吸收的抖动时长
        uint32_t smpls = 1024;
        switch (qlt) {
            case 0: smpls = 512;  break;
            case 1: smpls = 1024; break;
            case 2: smpls = 2048; break;
            case 3: smpls = 4096; break;
            case 4: smpls = 8192; break;
            default: break;
        }
        // 档位值按采样率折算为对应时长
        uint32_t frms = (sr ? sr : 48000) * smpls / 48000;
        if (frms < 128) frms = 128;
        return frms;
    }

    // 设置网络质量档位
    void setqlt(uint8_t qlt) {
        // 记录档位供起播预填使用
        qlt_ = qlt;
    }

    // 启动接收流回放：按流规格打开输出设备并直写样本
    bool strtrx(const DevInf& dev, const std::string& strm, const StrmCfg& cfg) {
        // 建立输出音频单元并绑定流回放回调
        if (!rt_) return false;
        if (!cfg.ch || !cfg.sr) return false;

        if (rx_run_ && rx_strm_ == strm && rx_cfg_.opeq(cfg)) {
            return true;
        }

        stprx();
        if (openunit(dev.id, cfg, false) != noErr) return false;

        rx_strm_ = strm;
        rx_cfg_  = cfg;
        rx_cb_.inputProc       = &StrmEngn::rxcall;
        rx_cb_.inputProcRefCon = this;

        if (AudioUnitSetProperty(rx_unit_, kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input, 0, &rx_cb_, sizeof(rx_cb_)) != noErr) {
            clsunit(rx_unit_);
            return false;
        }
        if (AudioUnitInitialize(rx_unit_) != noErr) {
            clsunit(rx_unit_);
            return false;
        }
        if (AudioOutputUnitStart(rx_unit_) != noErr) {
            AudioUnitUninitialize(rx_unit_);
            clsunit(rx_unit_);
            return false;
        }

        // 起播预填静音，吸收初期的网络抖动
        const uint32_t pre = qltfrms(qlt_, cfg.ch, cfg.sr);
        if (rt_) {
            std::vector<float> sil(static_cast<size_t>(pre) * cfg.ch, 0.0f);
            rt_->wrrx(strm, sil.data(), sil.size());
        }

        rx_run_ = true;
        return true;
    }

    // 停止接收流回放
    void stprx() {
        // 停止并释放接收流输出音频单元
        if (rx_unit_ && rx_run_) {
            AudioOutputUnitStop(rx_unit_);
        }
        if (rx_unit_) {
            AudioUnitUninitialize(rx_unit_);
            clsunit(rx_unit_);
        }
        rx_run_ = false;
    }

    // 启动发送流采集：按流规格打开输入设备并直读样本
    bool strttx(const DevInf& dev, const std::string& strm, const StrmCfg& cfg) {
        // 建立输入音频单元并绑定流采集回调
        if (!rt_) return false;
        if (!cfg.ch || !cfg.sr) return false;

        if (tx_run_ && tx_strm_ == strm && tx_cfg_.opeq(cfg)) {
            return true;
        }

        stptx();
        if (openunit(dev.id, cfg, true) != noErr) return false;

        tx_strm_ = strm;
        tx_cfg_  = cfg;
        tx_cb_.inputProc       = &StrmEngn::txcall;
        tx_cb_.inputProcRefCon = this;

        if (AudioUnitSetProperty(tx_unit_, kAudioOutputUnitProperty_SetInputCallback,
                                 kAudioUnitScope_Global, 0, &tx_cb_, sizeof(tx_cb_)) != noErr) {
            clsunit(tx_unit_);
            return false;
        }
        if (AudioUnitInitialize(tx_unit_) != noErr) {
            clsunit(tx_unit_);
            return false;
        }
        if (AudioOutputUnitStart(tx_unit_) != noErr) {
            AudioUnitUninitialize(tx_unit_);
            clsunit(tx_unit_);
            return false;
        }

        tx_run_ = true;
        return true;
    }

    // 停止发送流采集
    void stptx() {
        // 停止并释放发送流输入音频单元
        if (tx_unit_ && tx_run_) {
            AudioOutputUnitStop(tx_unit_);
        }
        if (tx_unit_) {
            AudioUnitUninitialize(tx_unit_);
            clsunit(tx_unit_);
        }
        tx_run_ = false;
    }

    // 停止全部设备通路
    void stpall() {
        // 释放接收与发送两侧音频单元
        stprx();
        stptx();
    }

    // 查询接收通路是否运行
    bool gtrxrun() const { return rx_run_; }

    // 查询发送通路是否运行
    bool gttxrun() const { return tx_run_; }

private:
    // 打开指定设备的音频单元
    OSStatus openunit(AudioDeviceID dev_id, const StrmCfg& cfg, bool for_in) {
        // 按流规格配置 HAL 音频单元与浮点流格式
        AudioComponentDescription desc{};
        desc.componentType         = kAudioUnitType_Output;
        desc.componentSubType      = kAudioUnitSubType_HALOutput;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;

        AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
        if (!comp) return -1;

        AudioUnit unit = nullptr;
        if (AudioComponentInstanceNew(comp, &unit) != noErr) return -1;

        const UInt32 en  = 1;
        const UInt32 dis = 0;

        if (for_in) {
            // 输入端开启 Element 1，关闭输出端 Element 0
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input, 1, &en, sizeof(en));
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Output, 0, &dis, sizeof(dis));
        } else {
            // 输出端开启 Element 0，关闭输入端 Element 1
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Output, 0, &en, sizeof(en));
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input, 1, &dis, sizeof(dis));
        }

        if (AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global, 0, &dev_id, sizeof(dev_id)) != noErr) {
            clsunit(unit);
            return -1;
        }

        // 设备以流自身采样率与声道数打开
        AudioStreamBasicDescription asbd{};
        asbd.mSampleRate       = static_cast<Float64>(cfg.sr);
        asbd.mFormatID         = kAudioFormatLinearPCM;
        asbd.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        asbd.mBitsPerChannel   = 32;
        asbd.mChannelsPerFrame = cfg.ch;
        asbd.mFramesPerPacket  = 1;
        asbd.mBytesPerFrame    = cfg.ch * sizeof(float);
        asbd.mBytesPerPacket   = asbd.mBytesPerFrame;

        // 向设备侧作用域写入格式
        const AudioUnitScope scp   = for_in ? kAudioUnitScope_Output : kAudioUnitScope_Input;
        const AudioUnitElement elm = for_in ? 1 : 0;
        if (AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat,
                                 scp, elm, &asbd, sizeof(asbd)) != noErr) {
            clsunit(unit);
            return -1;
        }
        // 客户端侧作用域同步同格式
        const AudioUnitScope cscp  = for_in ? kAudioUnitScope_Input : kAudioUnitScope_Output;
        AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat,
                             cscp, 0, &asbd, sizeof(asbd));

        if (for_in) {
            // 预分配渲染请求描述区，避免实时回调内分配
            abl_.assign(sizeof(AudioBufferList) + sizeof(AudioBuffer), 0);
            tx_unit_ = unit;
        } else {
            rx_unit_ = unit;
        }
        return noErr;
    }

    // 释放指定音频单元实例
    static void clsunit(AudioUnit& unit) {
        // 销毁传入的 HAL 音频单元引用
        if (unit) {
            AudioComponentInstanceDispose(unit);
            unit = nullptr;
        }
    }

    // 接收流回放实时回调
    static OSStatus rxcall(void* ref, AudioUnitRenderActionFlags*,
                           const AudioTimeStamp*, UInt32, UInt32 frames,
                           AudioBufferList* data) {
        // 从流缓冲取样本直写输出设备
        auto* self = static_cast<StrmEngn*>(ref);
        if (!self || !data || data->mNumberBuffers == 0) return noErr;

        float* dst = static_cast<float*>(data->mBuffers[0].mData);
        const uint32_t ch = data->mBuffers[0].mNumberChannels ? data->mBuffers[0].mNumberChannels : 1;
        const size_t cnt = static_cast<size_t>(frames) * ch;

        if (self->rx_strm_.empty() || self->rt_->rdrx(self->rx_strm_, dst, cnt) != cnt) {
            std::memset(dst, 0, cnt * sizeof(float));
        }
        return noErr;
    }

    // 发送流采集实时回调
    static OSStatus txcall(void* ref, AudioUnitRenderActionFlags* flags,
                           const AudioTimeStamp* ts, UInt32, UInt32 frames,
                           AudioBufferList*) {
        // 从输入设备取样本写入流缓冲
        auto* self = static_cast<StrmEngn*>(ref);
        if (!self || !self->tx_unit_ || self->tx_strm_.empty()) return noErr;

        const uint32_t ch = self->tx_cfg_.ch ? self->tx_cfg_.ch : 1;
        const size_t cnt = static_cast<size_t>(frames) * ch;
        if (self->cap_.size() < cnt) {
            self->cap_.resize(cnt, 0.0f);
        }

        auto* abl = reinterpret_cast<AudioBufferList*>(self->abl_.data());
        abl->mNumberBuffers = 1;
        abl->mBuffers[0].mNumberChannels = ch;
        abl->mBuffers[0].mDataByteSize   = static_cast<UInt32>(cnt * sizeof(float));
        abl->mBuffers[0].mData           = self->cap_.data();

        if (AudioUnitRender(self->tx_unit_, flags, ts, 1, frames, abl) != noErr) {
            return noErr;
        }
        self->rt_->wrtx(self->tx_strm_, self->cap_.data(), cnt);
        return noErr;
    }

    std::shared_ptr<RtEngn> rt_;
    AudioUnit               rx_unit_{nullptr};
    AudioUnit               tx_unit_{nullptr};
    bool                    rx_run_{false};
    bool                    tx_run_{false};
    std::string             rx_strm_;
    std::string             tx_strm_;
    StrmCfg                 rx_cfg_{};
    StrmCfg                 tx_cfg_{};
    AURenderCallbackStruct  rx_cb_{};
    AURenderCallbackStruct  tx_cb_{};
    std::vector<float>      cap_;
    std::vector<uint8_t>    abl_;
    uint8_t                 qlt_{1};
};

#endif // __APPLE__

} // namespace vban

#endif // VBAN_STREAM_ENGINE_HPP
