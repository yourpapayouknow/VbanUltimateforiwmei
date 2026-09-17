#ifndef VBAN_HEAD_BRIDGE_H
#define VBAN_HEAD_BRIDGE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 桥接层流统计数据结构
@interface VbanStrmMetric : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *srcIp;
@property (nonatomic, assign) uint16_t srcPort;
@property (nonatomic, assign) uint32_t sampleRate;
@property (nonatomic, assign) uint32_t channels;
@property (nonatomic, copy) NSString *format;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) uint64_t packetCount;
@property (nonatomic, assign) uint64_t frameCount;
@property (nonatomic, assign) uint64_t lostCount;
@property (nonatomic, assign) uint64_t duplicateCount;
@property (nonatomic, assign) uint64_t orderErrorCount;
@property (nonatomic, assign) uint32_t packetsPerSec;
@property (nonatomic, assign) uint32_t kbps;
@property (nonatomic, assign) double jitterMs;
@end

// 桥接层全局状态结构
@interface VbanAppMetric : NSObject
@property (nonatomic, assign) uint32_t activeRx;
@property (nonatomic, assign) uint32_t activeTx;
@property (nonatomic, assign) uint32_t cableCount;
@property (nonatomic, assign) uint64_t totalLost;
@property (nonatomic, assign) BOOL audioRunning;
@property (nonatomic, assign) BOOL driverInstalled;
@property (nonatomic, strong) NSArray<VbanStrmMetric *> *rxStreams;
@end

// 虚拟线缆数据结构
@interface VbanCableDesc : NSObject
@property (nonatomic, copy) NSString *cableId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) uint32_t channels;
@property (nonatomic, assign) uint32_t sampleRate;
@property (nonatomic, assign) BOOL enabled;
@end

// 音频设备结构
@interface VbanAudioDevDesc : NSObject
@property (nonatomic, assign) uint32_t devId;
@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) uint32_t inChannels;
@property (nonatomic, assign) uint32_t outChannels;
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) BOOL isDefaultIn;
@property (nonatomic, assign) BOOL isDefaultOut;
@end

// 路由规则描述结构
@interface VbanRouteDesc : NSObject
@property (nonatomic, copy) NSString *routeId;
@property (nonatomic, copy) NSString *srcId;
@property (nonatomic, copy) NSString *srcName;
@property (nonatomic, copy) NSString *dstId;
@property (nonatomic, copy) NSString *dstName;
@property (nonatomic, assign) float gain;
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL enabled;
@end

// 桥接层中央管理类
@interface VbanBridge : NSObject

+ (instancetype)shared;

// 启动与停止后台网络与音频引擎
- (BOOL)startAll;
- (void)stopAll;

// 虚拟音频线缆管理
- (NSArray<VbanCableDesc *> *)getCables;
- (BOOL)addCableWithId:(NSString *)cId name:(NSString *)name channels:(uint32_t)ch sampleRate:(uint32_t)sr;
- (BOOL)removeCableWithId:(NSString *)cId;
- (BOOL)renameCableWithId:(NSString *)cId newName:(NSString *)newName;

// 系统设备枚举
- (NSArray<VbanAudioDevDesc *> *)getDevices;

// 矩阵路由管理
- (NSArray<VbanRouteDesc *> *)getRoutes;
- (BOOL)addRouteWithId:(NSString *)rId srcId:(NSString *)sId srcName:(NSString *)sName dstId:(NSString *)dId dstName:(NSString *)dName gain:(float)gain;
- (BOOL)removeRouteWithId:(NSString *)rId;
- (void)toggleRouteWithId:(NSString *)rId enabled:(BOOL)en;

// 全局指标快照 (500ms 轮询)
- (VbanAppMetric *)getSnapshot;

@end

NS_ASSUME_NONNULL_END

#endif // VBAN_HEAD_BRIDGE_H
