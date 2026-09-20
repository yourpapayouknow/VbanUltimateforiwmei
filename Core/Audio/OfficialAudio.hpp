#ifndef VBAN_OFFICIAL_AUDIO_HPP
#define VBAN_OFFICIAL_AUDIO_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../Common/RingBuffer.hpp"
#include "DeviceCatalog.hpp"

namespace vban {

#if defined(__APPLE__)

// 音频数据方向
enum class AudDir : uint8_t {
    In  = 0, // 采集并推流
    Out = 1  // 接收并回放
};

// 流的音频规格
struct StrmCfg {
    uint32_t ch{0};
    uint32_t sr{0};
    uint32_t bit{1};
};

// 对照官方 audio_t：持有设备、当前流规格与后端句柄
class OffAud {
public:
    OffAud() = default;
    ~OffAud() { rels(); }

    // 初始化方向与目标设备
    bool init(AudDir dir, AudioDeviceID dev_id) {
        // 记录方向与设备标识
        dir_ = dir;
        dev_ = dev_id;
        return true;
    }

    // 对照官方 audio_set_stream_config：规格相同则直接返回
    bool setcfg(const StrmCfg& cfg) {
        // 三字段一致时不做任何重配
        if (cfg_.ch == cfg.ch && cfg_.sr == cfg.sr && cfg_.bit == cfg.bit) {
            return true;
        }

        close();
        cfg_ = cfg;
        return open();
    }

    // 对照官方 audio_write：将负载直接写往设备
    ssize_t write(const uint8_t* buf, size_t size) {
        // 输出方向不承载写入
        if (dir_ != AudDir::Out || !unit_ || !buf) return -1;
        if (cfg_.ch == 0) return -1;

        const size_t frms = size / (cfg_.ch * 4);
        if (frms == 0) return 0;

        const size_t fit = std::min(frms, play_.gtavlw() / cfg_.ch);
        return static_cast<ssize_t>(play_.wrblks(
            reinterpret_cast<const float*>(buf), fit * cfg_.ch) * sizeof(float));
    }

    // 对照官方 audio_read：从设备取出采集负载
    ssize_t read(uint8_t* buf, size_t size) {
        // 输入方向不承载读取
        if (dir_ != AudDir::In || !unit_ || !buf) return -1;
        if (cfg_.ch == 0) return -1;

        const size_t frms = size / (cfg_.ch * 4);
        if (frms == 0) return 0;

        const size_t use = std::min(cap_.gtavlr(), frms * cfg_.ch);
        if (use == 0) return 0;
        cap_.rdblks(reinterpret_cast<float*>(buf), use);
        return static_cast<ssize_t>(use * sizeof(float));
    }

    // 关闭后端
    void close() {
        // 停止并释放音频单元
        if (unit_ && run_) {
            AudioOutputUnitStop(unit_);
        }
        if (unit_) {
            AudioUnitUninitialize(unit_);
            AudioComponentInstanceDispose(unit_);
            unit_ = nullptr;
        }
        run_ = false;
        cap_.rstbuf();
        play_.rstbuf();
    }

    // 释放全部资源
    void rels() {
        // 关闭后端并清空规格
        close();
        cfg_ = StrmCfg{};
    }

    // 查询当前流规格
    const StrmCfg& gtcfg() const { return cfg_; }

    // 查询后端是否运行
    bool gtrun() const { return run_; }

    // 查询绑定的音频设备
    AudioDeviceID gtdev() const { return dev_; }

    // 由采集回调填入样本
    void pshcap(const float* src, size_t cnt) {
        // 供输入回调写入采集样本
        const size_t fit = std::min(cnt / cfg_.ch, cap_.gtavlw() / cfg_.ch);
        cap_.wrblks(src, fit * cfg_.ch);
    }

    // 由回放回调取出样本
    size_t poppnd(float* dst, size_t cnt) {
        // 供输出回调取出待回放样本
        return play_.rdblks(dst, cnt);
    }

    // 查询待回放样本是否充足
    bool hspend(size_t cnt) const {
        // 判断待回放区是否够取
        return play_.gtavlr() >= cnt;
    }

private:
    // 按当前规格打开音频单元
    bool open() {
        // 依据方向建立 HAL 音频单元
        AudioComponentDescription desc{};
        desc.componentType         = kAudioUnitType_Output;
        desc.componentSubType      = kAudioUnitSubType_HALOutput;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;

        AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
        if (!comp) return false;
        if (AudioComponentInstanceNew(comp, &unit_) != noErr) return false;

        AudioDeviceID dev = dev_;
        const UInt32 en = 1, dis = 0;
        const bool for_in = (dir_ == AudDir::In);

        if (for_in) {
            AudioUnitSetProperty(unit_, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input, 1, &en, sizeof(en));
            AudioUnitSetProperty(unit_, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Output, 0, &dis, sizeof(dis));
        } else {
            AudioUnitSetProperty(unit_, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Output, 0, &en, sizeof(en));
            AudioUnitSetProperty(unit_, kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input, 1, &dis, sizeof(dis));
        }

        if (AudioUnitSetProperty(unit_, kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global, 0, &dev, sizeof(dev)) != noErr) {
            close();
            return false;
        }

        AudioStreamBasicDescription asbd{};
        asbd.mSampleRate       = static_cast<Float64>(cfg_.sr);
        asbd.mFormatID         = kAudioFormatLinearPCM;
        asbd.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        asbd.mBitsPerChannel   = 32;
        asbd.mChannelsPerFrame = cfg_.ch;
        asbd.mFramesPerPacket  = 1;
        asbd.mBytesPerFrame    = cfg_.ch * sizeof(float);
        asbd.mBytesPerPacket   = asbd.mBytesPerFrame;

        const AudioUnitScope scp   = for_in ? kAudioUnitScope_Output : kAudioUnitScope_Input;
        const AudioUnitElement elm = for_in ? 1 : 0;
        if (AudioUnitSetProperty(unit_, kAudioUnitProperty_StreamFormat,
                                 scp, elm, &asbd, sizeof(asbd)) != noErr) {
            close();
            return false;
        }
        cb_.inputProc       = for_in ? &OffAud::incall : &OffAud::outcall;
        cb_.inputProcRefCon = this;
        if (for_in) {
            if (AudioUnitSetProperty(unit_, kAudioOutputUnitProperty_SetInputCallback,
                                     kAudioUnitScope_Global, 0, &cb_, sizeof(cb_)) != noErr) {
                close();
                return false;
            }
            abl_.assign(sizeof(AudioBufferList) + sizeof(AudioBuffer), 0);
        } else {
            if (AudioUnitSetProperty(unit_, kAudioUnitProperty_SetRenderCallback,
                                     kAudioUnitScope_Input, 0, &cb_, sizeof(cb_)) != noErr) {
                close();
                return false;
            }
        }

        if (AudioUnitInitialize(unit_) != noErr) {
            close();
            return false;
        }
        if (for_in) {
            UInt32 frames = 0;
            UInt32 size = sizeof(frames);
            if (AudioUnitGetProperty(unit_, kAudioUnitProperty_MaximumFramesPerSlice,
                                     kAudioUnitScope_Global, 0, &frames, &size) != noErr || frames == 0) {
                close();
                return false;
            }
            tmp_.resize(static_cast<size_t>(frames) * cfg_.ch);
        }
        if (AudioOutputUnitStart(unit_) != noErr) {
            close();
            return false;
        }

        run_ = true;
        return true;
    }

    // 回放回调：取出待回放样本
    static OSStatus outcall(void* ref, AudioUnitRenderActionFlags*,
                            const AudioTimeStamp*, UInt32, UInt32 frames,
                            AudioBufferList* data) {
        // 填充输出缓冲，不足则静音
        auto* self = static_cast<OffAud*>(ref);
        if (!self || !data || data->mNumberBuffers == 0) return noErr;

        float* dst = static_cast<float*>(data->mBuffers[0].mData);
        const uint32_t ch = data->mBuffers[0].mNumberChannels;
        const size_t cnt = static_cast<size_t>(frames) * ch;

        self->poppnd(dst, cnt);
        return noErr;
    }

    // 采集回调：取设备样本供推流
    static OSStatus incall(void* ref, AudioUnitRenderActionFlags* flags,
                           const AudioTimeStamp* ts, UInt32, UInt32 frames,
                           AudioBufferList*) {
        // 从输入设备取值存入采集区
        auto* self = static_cast<OffAud*>(ref);
        if (!self || !self->unit_) return noErr;

        const uint32_t ch = self->cfg_.ch ? self->cfg_.ch : 1;
        const size_t cnt = static_cast<size_t>(frames) * ch;
        if (self->tmp_.size() < cnt) return noErr;

        auto* abl = reinterpret_cast<AudioBufferList*>(self->abl_.data());
        abl->mNumberBuffers = 1;
        abl->mBuffers[0].mNumberChannels = ch;
        abl->mBuffers[0].mDataByteSize   = static_cast<UInt32>(cnt * sizeof(float));
        abl->mBuffers[0].mData           = self->tmp_.data();

        if (AudioUnitRender(self->unit_, flags, ts, 1, frames, abl) != noErr) {
            return noErr;
        }
        self->pshcap(self->tmp_.data(), cnt);
        return noErr;
    }

    AudDir          dir_{AudDir::Out};
    AudioDeviceID   dev_{0};
    AudioUnit       unit_{nullptr};
    bool            run_{false};
    StrmCfg         cfg_{};
    AURenderCallbackStruct cb_{};
    std::vector<uint8_t>   abl_;
    std::vector<float>     tmp_;
    RingBuf<float>         cap_{65536};
    RingBuf<float>         play_{65536};
};

#endif // __APPLE__

} // namespace vban

#endif // VBAN_OFFICIAL_AUDIO_HPP
