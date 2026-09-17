#ifndef VBAN_AUDIO_ENGINE_HPP
#define VBAN_AUDIO_ENGINE_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"
#include "../Common/RingBuffer.hpp"
#include "DeviceCatalog.hpp"

namespace vban {

#if defined(__APPLE__)

// 音频渲染提供者函数签名 (从外界拉取样本)
using OutRndrCb = std::function<void(float* dst, uint32_t smpls, uint32_t ch)>;

// 音频输入采集接收者函数签名 (向外界提供录音样本)
using InCptCb   = std::function<void(const float* src, uint32_t smpls, uint32_t ch)>;

// CoreAudio 原生物理设备输入输出调度引擎
class AudEngn {
public:
    AudEngn() : au_out_(nullptr), au_in_(nullptr), run_out_(false), run_in_(false) {}

    ~AudEngn() {
        stpio();
        clsio();
    }

    // 初始化物理音频输出流
    bool initout(AudioDeviceID dev_id, uint32_t sr, uint32_t ch, OutRndrCb cb) {
        // 配置并打开物理输出音频单元
        clsout();
        out_cb_ = std::move(cb);

        AudioComponentDescription desc{};
        desc.componentType         = kAudioUnitType_Output;
        desc.componentSubType      = kAudioUnitSubType_HALOutput;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;

        AudioComponent comp = AudioComponentFindNext(nullptr, &desc);
        if (!comp) return false;

        if (AudioComponentInstanceNew(comp, &au_out_) != noErr) {
            return false;
        }

        // 启用输出端 (Element 0)
        UInt32 en = 1;
        AudioUnitSetProperty(au_out_, kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Output, 0, &en, sizeof(en));

        // 禁用输入端 (Element 1)
        UInt32 dis = 0;
        AudioUnitSetProperty(au_out_, kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input, 1, &dis, sizeof(dis));

        // 设置当前输出设备
        AudioUnitSetProperty(au_out_, kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global, 0, &dev_id, sizeof(dev_id));

        // 设置标准浮点音频格式
        AudioStreamBasicDescription asbd{};
        asbd.mSampleRate       = static_cast<Float64>(sr);
        asbd.mFormatID         = kAudioFormatLinearPCM;
        asbd.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        asbd.mBitsPerChannel   = 32;
        asbd.mChannelsPerFrame = ch;
        asbd.mBytesPerFrame    = ch * sizeof(float);
        asbd.mFramesPerPacket  = 1;
        asbd.mBytesPerPacket   = asbd.mBytesPerFrame;

        AudioUnitSetProperty(au_out_, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0, &asbd, sizeof(asbd));

        // 注册实时渲染回调
        AURenderCallbackStruct cbs{};
        cbs.inputProc       = &AudEngn::rndrcall;
        cbs.inputProcRefCon = this;
        AudioUnitSetProperty(au_out_, kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input, 0, &cbs, sizeof(cbs));

        return AudioUnitInitialize(au_out_) == noErr;
    }

    // 启动音频硬件引擎
    bool strtio() {
        // 启动音频单元流水线
        if (au_out_ && !run_out_) {
            if (AudioOutputUnitStart(au_out_) == noErr) {
                run_out_ = true;
            }
        }
        return run_out_;
    }

    // 停止音频流水线
    void stpio() {
        // 停止音频单元运行
        if (au_out_ && run_out_) {
            AudioOutputUnitStop(au_out_);
            run_out_ = false;
        }
    }

    // 关闭音频输出句柄
    void clsout() {
        // 释放音频单元实例
        if (au_out_) {
            stpio();
            AudioUnitUninitialize(au_out_);
            AudioComponentInstanceDispose(au_out_);
            au_out_ = nullptr;
        }
    }

    // 关闭所有音频硬件资源
    void clsio() {
        // 关闭输入与输出全部实例
        clsout();
    }

private:
    // CoreAudio 实时播放回调函数
    static OSStatus rndrcall(void* ref,
                             AudioUnitRenderActionFlags*,
                             const AudioTimeStamp*,
                             UInt32,
                             UInt32 frames,
                             AudioBufferList* data) {
        // 填充音频缓冲区样本
        auto* self = static_cast<AudEngn*>(ref);
        if (!self || !data || data->mNumberBuffers == 0) {
            return noErr;
        }

        float* dst = static_cast<float*>(data->mBuffers[0].mData);
        const uint32_t ch = data->mBuffers[0].mNumberChannels;
        if (self->out_cb_) {
            self->out_cb_(dst, frames, ch);
        } else {
            std::memset(dst, 0, frames * ch * sizeof(float));
        }

        return noErr;
    }

    AudioUnit   au_out_;
    AudioUnit   au_in_;
    bool        run_out_;
    bool        run_in_;
    OutRndrCb   out_cb_;
    InCptCb     in_cb_;
};

#endif // __APPLE__

} // namespace vban

#endif // VBAN_AUDIO_ENGINE_HPP
