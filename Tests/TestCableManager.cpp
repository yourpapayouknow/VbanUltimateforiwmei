#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/Audio/CableManager.hpp"
#include <cassert>
#include <iostream>
#include <filesystem>

using namespace vban;

// 测试虚拟线缆动态配置管理与原子写入
void tstcblmgr() {
    // 验证虚拟线缆增删改查与plist落盘
    const std::string test_dir = "/tmp/vban_cable_test_" + std::to_string(::getpid());
    std::filesystem::create_directories(test_dir);

    {
        CblMgr mgr(test_dir);
        assert(mgr.gtcbls().empty());

        // 添加 4 条独立线缆
        assert(mgr.addcbl("vban_a", "VBAN - PC A", 2, 48000));
        assert(mgr.addcbl("vban_b", "VBAN - PC B", 2, 48000));
        assert(mgr.addcbl("vban_c", "VBAN - Music", 2, 48000));
        assert(mgr.addcbl("vban_d", "VBAN - Talkback", 2, 48000));

        // 杜绝重复ID
        assert(!mgr.addcbl("vban_a", "Duplicate", 2, 48000));

        auto list = mgr.gtcbls();
        assert(list.size() == 4);
        assert(list[0].id == "vban_a");
        assert(list[0].name == "VBAN - PC A");

        // 重命名
        assert(mgr.rnmcbl("vban_c", "VBAN - Studio Music"));
        // 删除
        assert(mgr.rmvcbl("vban_b"));

        list = mgr.gtcbls();
        assert(list.size() == 3);
    }

    // 重新从磁盘载入验证持久化
    {
        CblMgr mgr2(test_dir);
        auto list = mgr2.gtcbls();
        assert(list.size() == 3);
        assert(list[0].name == "VBAN - PC A");
        assert(list[1].name == "VBAN - Studio Music");
        assert(list[2].name == "VBAN - Talkback");
    }

    std::filesystem::remove_all(test_dir);
    std::cout << "[PASS] tstcblmgr: CableManager add/remove/rename/persistence OK\n";
}

int main() {
    std::cout << "Running CableManager Tests...\n";
    tstcblmgr();
    std::cout << "All CableManager Tests PASSED successfully!\n";
    return 0;
}
