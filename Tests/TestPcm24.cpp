#include "../Core/Audio/OfficialStream.hpp"
#include <cassert>

// 验证24位PCM正负满幅与零值转换
int main() {
    const uint8_t zero[3]{0x00, 0x00, 0x00};
    const uint8_t positive[3]{0xFF, 0xFF, 0x7F};
    const uint8_t negative[3]{0x00, 0x00, 0x80};
    const uint8_t minus_one[3]{0xFF, 0xFF, 0xFF};
    assert(vban::cnv24(zero) == 0.0f);
    assert(vban::cnv24(positive) > 0.999f);
    assert(vban::cnv24(negative) == -1.0f);
    assert(vban::cnv24(minus_one) < 0.0f);
}
