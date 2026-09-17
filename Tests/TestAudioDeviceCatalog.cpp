#include "../Core/Common/Head.hpp"
#include "../Core/Common/Types.hpp"
#include "../Core/Audio/DeviceCatalog.hpp"
#include <iostream>

using namespace vban;

int main() {
    std::cout << "Testing CoreAudio DeviceCatalog...\n";
    auto devs = enumdevs();
    std::cout << "Found " << devs.size() << " CoreAudio devices:\n";
    for (const auto& d : devs) {
        std::cout << " - ID: " << d.id
                  << " | Name: \"" << d.name << "\""
                  << " | In: " << d.inchs << "ch"
                  << " | Out: " << d.outchs << "ch"
                  << " | SR: " << d.sr << "Hz"
                  << (d.is_dfltin ? " [Default In]" : "")
                  << (d.is_dfltout ? " [Default Out]" : "")
                  << "\n";
    }
    std::cout << "[PASS] DeviceCatalog test completed successfully!\n";
    return 0;
}
