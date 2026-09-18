#import "HeadBridge.h"
#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/VBAN/Protocol.hpp"
#include "../Core/VBAN/Parser.hpp"
#include "../Core/VBAN/Packetizer.hpp"
#include "../Core/Network/UdpSocket.hpp"
#include "../Core/Network/Demuxer.hpp"
#include "../Core/Audio/DeviceCatalog.hpp"
#include "../Core/Audio/CableManager.hpp"
#include "../Core/Routing/MatrixRouter.hpp"
#include "../Core/Monitoring/MetricsEngine.hpp"
#include <thread>
#include <atomic>

@implementation VbanStrmMetric
@end

@implementation VbanAppMetric
@end

@implementation VbanCableDesc
@end

@implementation VbanAudioDevDesc
@end

@implementation VbanRouteDesc
@end

@implementation VbanConflictProcess
@end

@interface VbanBridge () {
    std::shared_ptr<vban::UdpSck>     sck_;
    std::shared_ptr<vban::StrmDmx>    dmx_;
    std::shared_ptr<vban::CblMgr>     cbl_;
    std::shared_ptr<vban::MtrxRtr>    rtr_;
    std::shared_ptr<vban::MtrcsEngn>  mtr_;
    std::thread                       rx_th_;
    std::atomic<bool>                 th_run_;
    std::atomic<bool>                 is_run_;
    std::atomic<bool>                 port_conflict_;
    std::atomic<uint16_t>             bound_port_;
}
@end

@implementation VbanBridge

+ (instancetype)shared {
    // 获取单例桥接实例
    static VbanBridge *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[VbanBridge alloc] init];
    });
    return inst;
}

- (instancetype)init {
    // 初始化桥接并装载C++核心引擎
    self = [super init];
    if (self) {
        sck_           = std::make_shared<vban::UdpSck>();
        dmx_           = std::make_shared<vban::StrmDmx>();
        cbl_           = std::make_shared<vban::CblMgr>();
        rtr_           = std::make_shared<vban::MtrxRtr>();
        mtr_           = std::make_shared<vban::MtrcsEngn>(dmx_, cbl_, rtr_);
        th_run_        = false;
        is_run_        = false;
        port_conflict_ = false;
        bound_port_    = 6980;
    }
    return self;
}

- (void)dealloc {
    [self stopAll];
}

- (BOOL)startAll {
    return [self startAllWithPort:6980];
}

- (BOOL)startAllWithPort:(uint16_t)port {
    // 启动指定端口监听：严格不降级换绑，若冲突则记录并提醒
    if (is_run_.load()) {
        if (bound_port_.load() == port && !port_conflict_.load()) return YES;
        [self stopAll];
    }

    port_conflict_.store(false);
    bound_port_.store(port);

    if (!sck_->initsck()) {
        return NO;
    }

    // 绑定端口：若被占用绝不降级换绑，明确记录冲突
    if (!sck_->bndsck(port)) {
        port_conflict_.store(true);
        sck_->clssck();
        return NO;
    }

    th_run_.store(true);
    is_run_.store(true);

    auto sck_ptr = sck_;
    auto dmx_ptr = dmx_;
    std::atomic<bool>* run_flag = &th_run_;

    rx_th_ = std::thread([sck_ptr, dmx_ptr, run_flag]() {
        uint8_t buf[2048];
        char sip[32];
        uint16_t sprt = 0;
        while (run_flag->load()) {
            ssize_t n = sck_ptr->rcvsck(buf, sizeof(buf), sip, &sprt);
            if (n > 0) {
                dmx_ptr->dmxpkt(buf, n, sip, sprt);
            } else {
                std::this_thread::sleep_for(std::chrono::microseconds(200));
            }
        }
    });

    return YES;
}

- (BOOL)isPortConflict {
    return port_conflict_.load();
}

- (uint16_t)boundPort {
    return bound_port_.load();
}

- (NSArray<VbanConflictProcess *> *)scanPortOccupants:(uint16_t)port {
    // 扫描占用目标UDP端口的外部进程
    NSMutableArray *res = [NSMutableArray array];
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "/usr/sbin/lsof -nP -iUDP:%u -Fpcf 2>/dev/null", port);
    FILE *fp = popen(cmd, "r");
    if (!fp) return res;

    char line[512];
    pid_t cur_pid = 0;
    while (fgets(line, sizeof(line), fp)) {
        size_t len = strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r')) {
            line[--len] = '\0';
        }
        if (line[0] == 'p') {
            cur_pid = (pid_t)atoi(line + 1);
        } else if (line[0] == 'c' && cur_pid > 0) {
            NSString *pName = [NSString stringWithUTF8String:line + 1];
            VbanConflictProcess *p = [[VbanConflictProcess alloc] init];
            p.pid = cur_pid;
            p.name = pName;
            [res addObject:p];
            cur_pid = 0;
        }
    }
    pclose(fp);
    return res;
}

- (BOOL)killProcessByPid:(pid_t)pid {
    // 终止指定冲突进程以释放端口
    if (pid <= 1) return NO;
    kill(pid, SIGTERM);
    usleep(150000);
    if (kill(pid, 0) == 0) {
        kill(pid, SIGKILL);
    }
    return YES;
}

- (void)stopAll {
    // 停止网络与流分发线程
    if (!is_run_.load()) return;

    th_run_.store(false);
    if (rx_th_.joinable()) {
        rx_th_.join();
    }

    sck_->clssck();
    is_run_.store(false);
}

- (NSArray<VbanCableDesc *> *)getCables {
    // 提取虚拟音频线缆列表
    NSMutableArray *arr = [NSMutableArray array];
    auto items = cbl_->gtcbls();
    for (const auto& it : items) {
        VbanCableDesc *d = [[VbanCableDesc alloc] init];
        d.cableId    = [NSString stringWithUTF8String:it.id.c_str()];
        d.name       = [NSString stringWithUTF8String:it.name.c_str()];
        d.channels   = it.chs;
        d.sampleRate = it.sr;
        d.enabled    = it.en;
        [arr addObject:d];
    }
    return arr;
}

- (BOOL)addCableWithId:(NSString *)cId name:(NSString *)name channels:(uint32_t)ch sampleRate:(uint32_t)sr {
    // 添加虚拟线缆
    return cbl_->addcbl([cId UTF8String], [name UTF8String], ch, sr);
}

- (BOOL)removeCableWithId:(NSString *)cId {
    // 删除虚拟线缆
    return cbl_->rmvcbl([cId UTF8String]);
}

- (BOOL)renameCableWithId:(NSString *)cId newName:(NSString *)newName {
    // 重命名虚拟线缆
    return cbl_->rnmcbl([cId UTF8String], [newName UTF8String]);
}

- (NSArray<VbanAudioDevDesc *> *)getDevices {
    // 枚举系统 CoreAudio 物理和虚拟设备
    NSMutableArray *arr = [NSMutableArray array];
    auto devs = vban::enumdevs();
    for (const auto& d : devs) {
        VbanAudioDevDesc *desc = [[VbanAudioDevDesc alloc] init];
        desc.devId       = d.id;
        desc.uid         = [NSString stringWithUTF8String:d.uid.c_str()];
        desc.name        = [NSString stringWithUTF8String:d.name.c_str()];
        desc.inChannels  = d.inchs;
        desc.outChannels = d.outchs;
        desc.sampleRate  = d.sr;
        desc.isDefaultIn  = d.is_dfltin;
        desc.isDefaultOut = d.is_dfltout;
        [arr addObject:desc];
    }
    return arr;
}

- (NSArray<VbanRouteDesc *> *)getRoutes {
    // 获取当前矩阵路由映射关系
    NSMutableArray *arr = [NSMutableArray array];
    auto rts = rtr_->gtrouts();
    for (const auto& r : rts) {
        VbanRouteDesc *rd = [[VbanRouteDesc alloc] init];
        rd.routeId = [NSString stringWithUTF8String:r.id.c_str()];
        rd.srcId   = [NSString stringWithUTF8String:r.src.id.c_str()];
        rd.srcName = [NSString stringWithUTF8String:r.src.name.c_str()];
        rd.dstId   = [NSString stringWithUTF8String:r.dst.id.c_str()];
        rd.dstName = [NSString stringWithUTF8String:r.dst.name.c_str()];
        rd.gain    = r.gain;
        rd.muted   = r.mut;
        rd.enabled = r.en;
        [arr addObject:rd];
    }
    return arr;
}

- (BOOL)addRouteWithId:(NSString *)rId srcId:(NSString *)sId srcName:(NSString *)sName dstId:(NSString *)dId dstName:(NSString *)dName gain:(float)gain {
    // 添加或更新矩阵规则
    vban::Endpnt src{vban::EndpntTyp::Physical, [sId UTF8String], [sName UTF8String]};
    vban::Endpnt dst{vban::EndpntTyp::Physical, [dId UTF8String], [dName UTF8String]};
    return rtr_->addrout([rId UTF8String], src, dst, gain);
}

- (BOOL)removeRouteWithId:(NSString *)rId {
    // 移除矩阵规则
    return rtr_->rmvrout([rId UTF8String]);
}

- (void)toggleRouteWithId:(NSString *)rId enabled:(BOOL)en {
    // 切换矩阵规则开关
    rtr_->tglrout([rId UTF8String], en);
}

- (VbanAppMetric *)getSnapshot {
    // 获取全局快照数据供UI刷新
    auto snap = mtr_->gtsnap(is_run_.load());
    VbanAppMetric *m = [[VbanAppMetric alloc] init];
    m.activeRx        = snap.actv_rx;
    m.activeTx        = snap.actv_tx;
    m.cableCount      = snap.cbl_cnt;
    m.totalLost       = snap.totl_lost;
    m.audioRunning    = snap.aud_run;
    m.driverInstalled = snap.drv_ok;
    m.portConflict    = port_conflict_.load();
    m.boundPort       = bound_port_.load();

    NSMutableArray<VbanStrmMetric *> *strms = [NSMutableArray array];
    for (const auto& s : snap.rx_snaps) {
        VbanStrmMetric *sm = [[VbanStrmMetric alloc] init];
        sm.name            = [NSString stringWithUTF8String:s.strm];
        sm.srcIp           = [NSString stringWithUTF8String:s.srcip];
        sm.srcPort         = s.srcprt;
        sm.sampleRate      = s.sr;
        sm.channels        = s.ch;
        uint32_t bdepth = 16;
        switch (s.fmt) {
            case vban::SmplFmt::Int8:    bdepth = 8; break;
            case vban::SmplFmt::Int16:   bdepth = 16; break;
            case vban::SmplFmt::Int24:   bdepth = 24; break;
            case vban::SmplFmt::Int32:   bdepth = 32; break;
            case vban::SmplFmt::Float32: bdepth = 32; break;
            case vban::SmplFmt::Float64: bdepth = 64; break;
            case vban::SmplFmt::Int12:   bdepth = 12; break;
            case vban::SmplFmt::Int10:   bdepth = 10; break;
            default:                     bdepth = 16; break;
        }
        sm.bitDepth        = bdepth;
        sm.format          = (s.fmt == vban::SmplFmt::Float32 || s.fmt == vban::SmplFmt::Float64)
                             ? [NSString stringWithFormat:@"Float %ubit", bdepth]
                             : [NSString stringWithFormat:@"PCM %ubit", bdepth];
        sm.status          = (s.stt == vban::StrmStt::Active) ? @"Active" : @"Offline";
        sm.packetCount     = s.pktcnt;
        sm.frameCount      = s.frmcnt;
        sm.lostCount       = s.lostcnt;
        sm.duplicateCount  = s.dupcnt;
        sm.orderErrorCount = s.ordrcnt;
        sm.packetsPerSec   = s.pkts;
        sm.kbps            = s.kbps;
        sm.jitterMs        = s.jtr_ms;
        [strms addObject:sm];
    }
    m.rxStreams = strms;
    return m;
}

@end
