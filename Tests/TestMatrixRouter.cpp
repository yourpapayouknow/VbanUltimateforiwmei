#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/Routing/MatrixRouter.hpp"
#include "../Core/Monitoring/MetricsEngine.hpp"
#include <cassert>
#include <iostream>

using namespace vban;

// 测试矩阵路由添加、增益与分发检索
void tstmtrxrtr() {
    // 验证矩阵端点映射与静音控制
    MtrxRtr rtr;

    Endpnt rx_a{EndpntTyp::Vban, "rx_pc_a", "VBAN RX (PC-A)"};
    Endpnt cbl_a{EndpntTyp::Cable, "vban_cbl_a", "Virtual Cable A"};
    Endpnt spk{EndpntTyp::Physical, "spk_out", "MacBook Pro Speakers"};

    // 路由1: RX A -> Cable A
    assert(rtr.addrout("r1", rx_a, cbl_a, 1.0f));
    // 路由2: RX A -> Speaker
    assert(rtr.addrout("r2", rx_a, spk, 0.8f));

    auto dsts = rtr.fnddsts("rx_pc_a");
    assert(dsts.size() == 2);
    assert(dsts[0].first.id == "vban_cbl_a" && dsts[0].second == 1.0f);
    assert(dsts[1].first.id == "spk_out" && std::abs(dsts[1].second - 0.8f) < 0.001f);

    // 禁用路由2
    rtr.tglrout("r2", false);
    dsts = rtr.fnddsts("rx_pc_a");
    assert(dsts.size() == 1);
    assert(dsts[0].first.id == "vban_cbl_a");

    // 移除路由1
    assert(rtr.rmvrout("r1"));
    dsts = rtr.fnddsts("rx_pc_a");
    assert(dsts.empty());

    std::cout << "[PASS] tstmtrxrtr: MatrixRouter routes and fanout OK\n";
}

int main() {
    std::cout << "Running MatrixRouter Tests...\n";
    tstmtrxrtr();
    std::cout << "All MatrixRouter Tests PASSED successfully!\n";
    return 0;
}
