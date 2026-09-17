#ifndef VBAN_UDP_SOCKET_HPP
#define VBAN_UDP_SOCKET_HPP

#include "../Common/Head.hpp"
#include "../Common/Types.hpp"

namespace vban {

// UDP套接字封装
class UdpSck {
public:
    // 初始化空套接字
    UdpSck() : fd_(-1) {}

    // 析构关闭套接字
    ~UdpSck() {
        clssck();
    }

    // 禁止拷贝
    UdpSck(const UdpSck&) = delete;
    UdpSck& operator=(const UdpSck&) = delete;

    // 移动构造
    UdpSck(UdpSck&& o) noexcept : fd_(o.fd_) {
        o.fd_ = -1;
    }

    // 移动赋值
    UdpSck& operator=(UdpSck&& o) noexcept {
        if (this != &o) {
            clssck();
            fd_ = o.fd_;
            o.fd_ = -1;
        }
        return *this;
    }

    // 创建非阻塞套接字
    bool initsck() {
        // 创建UDP文件描述符并置为非阻塞
        clssck();
        fd_ = ::socket(AF_INET, SOCK_DGRAM, 0);
        if (fd_ < 0) {
            return false;
        }

        int opt = 1;
        ::setsockopt(fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
#ifdef SO_REUSEPORT
        ::setsockopt(fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));
#endif

        int flg = ::fcntl(fd_, F_GETFL, 0);
        if (flg >= 0) {
            ::fcntl(fd_, F_SETFL, flg | O_NONBLOCK);
        }

        return true;
    }

    // 绑定本地监听端口
    bool bndsck(uint16_t prt) {
        // 将套接字绑定至指定端口
        if (fd_ < 0 && !initsck()) {
            return false;
        }

        struct sockaddr_in addr{};
        addr.sin_family      = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port        = htons(prt);

        return ::bind(fd_, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) == 0;
    }

    // 发送数据报文到目标地址
    ssize_t sndsck(const char* ip, uint16_t prt, const void* dat, size_t len) {
        // 向指定IPv4与端口发送UDP报文
        if (fd_ < 0 || !ip || !dat || len == 0) {
            return -1;
        }

        struct sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port   = htons(prt);
        if (::inet_pton(AF_INET, ip, &addr.sin_addr) <= 0) {
            return -1;
        }

        return ::sendto(fd_, dat, len, 0,
                        reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr));
    }

    // 接收非阻塞UDP报文
    ssize_t rcvsck(void* buf, size_t maxlen, char* srcip = nullptr, uint16_t* srcprt = nullptr) {
        // 从套接字读取单个数据包并提取源地址
        if (fd_ < 0 || !buf || maxlen == 0) {
            return -1;
        }

        struct sockaddr_in from{};
        socklen_t flen = sizeof(from);

        ssize_t rc = ::recvfrom(fd_, buf, maxlen, 0,
                                reinterpret_cast<struct sockaddr*>(&from), &flen);
        if (rc > 0) {
            if (srcip) {
                ::inet_ntop(AF_INET, &from.sin_addr, srcip, INET_ADDRSTRLEN);
            }
            if (srcprt) {
                *srcprt = ntohs(from.sin_port);
            }
        }
        return rc;
    }

    // 关闭套接字
    void clssck() {
        // 关闭底层套接字句柄
        if (fd_ >= 0) {
            ::close(fd_);
            fd_ = -1;
        }
    }

    // 获取文件描述符
    int gtfd() const {
        // 返回底层文件句柄
        return fd_;
    }

private:
    int fd_;
};

} // namespace vban

#endif // VBAN_UDP_SOCKET_HPP
