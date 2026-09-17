#ifndef VBAN_COMMON_HEAD_HPP
#define VBAN_COMMON_HEAD_HPP

// 统一标准库与系统底层依赖引用
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <string>
#include <vector>
#include <memory>
#include <atomic>
#include <chrono>
#include <array>
#include <optional>
#include <functional>
#include <mutex>
#include <unordered_map>
#include <algorithm>
#include <cmath>

// POSIX 与网络系统依赖
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>

#if defined(__APPLE__)
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreFoundation/CoreFoundation.h>
#endif

#endif // VBAN_COMMON_HEAD_HPP
