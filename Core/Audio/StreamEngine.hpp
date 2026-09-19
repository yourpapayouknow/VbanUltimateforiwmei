#ifndef VBAN_STREAM_ENGINE_HPP
#define VBAN_STREAM_ENGINE_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "DeviceCatalog.hpp"
#include "../Routing/RouteEngine.hpp"

namespace vban {

#if defined(__APPLE__)

// 单条 VBAN 流的设备回放与采集调度引擎
class StrmEngn {
public:
    // 抖动缓冲解析函数签名
    using JtrResl = std::function<std::shared_ptr<JtrBuf>(const std::string&)>;

    explicit StrmEngn(std::shared_ptr<RtEngn> rt) : rt_(std::move(rt)) {}

    // 挂载抖动缓冲解析器
    void setjtr(JtrResl cb) {
        // 注册按流名取抖动缓冲的回调
        jtr_ = std::move(cb);
    }
    ~StrmEngn() { stpall(); }

    // 启动接收流回放：在指定输出设备上回放该流样本
    bool strtrx(const DevInf& dev, const std::string& strm, uint32_t ch, uint32_t sr, uint32_t srch = 0) {
        // 建立输出音频单元并绑定流回放回调
        if (!rt_) return false;
        stprx();

        if (openunit(dev.id, ch, false, sr) != noErr) return false;

        rx_strm_ = strm;
        rx_ch_   = ch ? ch : dev.outchs;
        rx_srch_ = srch;
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

    // 启动发送流采集：从指定输入设备采集样本
    bool strttx(const DevInf& dev, const std::string& strm, uint32_t ch, uint32_t sr) {
        // 建立输入音频单元并绑定流采集回调
        if (!rt_) return false;
        stptx();

        if (openunit(dev.id, ch, true, sr) != noErr) return false;

        tx_strm_ = strm;
        tx_ch_   = ch ? ch : (dev.inchs ? dev.inchs : 1);
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
    OSStatus openunit(AudioDeviceID dev_id, uint32_t ch, bool for_in, uint32_t sr) {
        // 按方向配置 HAL 音频单元与浮点流格式
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

        // 统一采用 32 位浮点非线性交织格式交换样本
        AudioStreamBasicDescription asbd{};
        asbd.mSampleRate       = sr > 0 ? static_cast<Float64>(sr) : 0;
        asbd.mFormatID         = kAudioFormatLinearPCM;
        asbd.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        asbd.mBitsPerChannel   = 32;
        asbd.mChannelsPerFrame = ch ? ch : 2;
        asbd.mFramesPerPacket  = 1;
        asbd.mBytesPerFrame    = asbd.mChannelsPerFrame * sizeof(float);
        asbd.mBytesPerPacket   = asbd.mBytesPerFrame;

        // 向设备侧作用域写入格式
        const AudioUnitScope scp  = for_in ? kAudioUnitScope_Output : kAudioUnitScope_Input;
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
            // 预取输入侧缓冲参数供实时回调使用
            UInt32 bsz = sizeof(tx_bmax_);
            if (AudioUnitGetProperty(unit, kAudioDevicePropertyBufferFrameSize,
                                     kAudioUnitScope_Global, 0, &tx_bmax_, &bsz) != noErr) {
                tx_bmax_ = 4096;
            }
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
        // 从流缓冲提取样本并按设备声道映射输出
        auto* self = static_cast<StrmEngn*>(ref);
        if (!self || !data || data->mNumberBuffers == 0) return noErr;

        float* dst = static_cast<float*>(data->mBuffers[0].mData);
        const uint32_t dch = data->mBuffers[0].mNumberChannels ? data->mBuffers[0].mNumberChannels : 1;
        const size_t dcnt = static_cast<size_t>(frames) * dch;

        // 经抗抖动缓冲取数，保证网络抖动与乱序被平滑
        auto jb = self->jtr_ ? self->jtr_(self->rx_strm_) : nullptr;
        if (!jb) {
            std::memset(dst, 0, dcnt * sizeof(float));
            return noErr;
        }
        jb->popblks(dst, dcnt);
        return noErr;
    }

    // 发送流采集实时回调
    static OSStatus txcall(void* ref, AudioUnitRenderActionFlags* flags,
                           const AudioTimeStamp* ts, UInt32, UInt32 frames,
                           AudioBufferList*) {
        // 从输入设备采集样本写入流缓冲
        auto* self = static_cast<StrmEngn*>(ref);
        if (!self || !self->tx_unit_ || self->tx_strm_.empty()) return noErr;

        const uint32_t ch = self->tx_ch_ ? self->tx_ch_ : 1;
        const size_t cnt = static_cast<size_t>(frames) * ch;
        if (self->cap_.size() < cnt) {
            self->cap_.resize(cnt, 0.0f);
        }

        // 构造输入总线渲染请求并回填设备样本
        AudioBufferList* abl = reinterpret_cast<AudioBufferList*>(self->abl_.data());
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
    JtrResl                 jtr_;
    AudioUnit               rx_unit_{nullptr};
    AudioUnit               tx_unit_{nullptr};
    bool                    rx_run_{false};
    bool                    tx_run_{false};
    std::string             rx_strm_;
    std::string             tx_strm_;
    uint32_t                rx_ch_{2};
    uint32_t                rx_srch_{0};
    uint32_t                tx_ch_{1};
    AURenderCallbackStruct  rx_cb_{};
    AURenderCallbackStruct  tx_cb_{};
    std::vector<float>      cap_;
    std::vector<float>      rx_tmp_;
    std::vector<uint8_t>    abl_;       // 输入渲染缓冲描述区
    uint32_t                tx_bmax_{4096};
};

#endif // __APPLE__

} // namespace vban

#endif // VBAN_STREAM_ENGINE_HPP
