#include "Vwrapper_aes128.h"
#include "verilated.h"
#include <iostream>
#include <iomanip>
#include <cstdint>
#include <cassert>

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

// MSKcst 仿真：将 128-bit unmasked 扩展为 128*d-bit masked，插入 d-1 个 0
void expand_masked_input(uint32_t* out, uint64_t umsk_low, uint64_t umsk_high, int d) {
    // out 是一个 128*d bit 的输出，存储在 32-bit * N 数组里
    int total_bits = 128 * d;
    int num_words = (total_bits + 31) / 32;
    for (int i = 0; i < num_words; ++i) out[i] = 0;

    for (int i = 0; i < 128; ++i) {
        int bit_val = (i < 64) ? ((umsk_low >> i) & 1) : ((umsk_high >> (i - 64)) & 1);
        if (bit_val) {
            int bit_index = i * d;  // 放在 sh_key 的 d*i 位置
            int word_index = bit_index / 32;
            int offset = bit_index % 32;
            out[word_index] |= (1U << offset);
        }
    }
}

// 将 128*d 位 masked ciphertext 重新组合为 128-bit unmasked
void recombine(uint8_t* out, const uint32_t* sh_ciphertext, int d) {
    for (int i = 0; i < 128; ++i) {
        int val = 0;
        for (int j = 0; j < d; ++j) {
            int bit_pos = d * i + j;
            int word = bit_pos / 32;
            int offset = bit_pos % 32;
            val ^= (sh_ciphertext[word] >> offset) & 1;
        }
        out[127 - i] = val;
    }
}

void tick(Vwrapper_aes128* dut) {
    dut->clk = 0; dut->eval(); main_time++;
    dut->clk = 1; dut->eval(); main_time++;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vwrapper_aes128* dut = new Vwrapper_aes128;

    const int d = 3; // 可变参数，但注意要与 verilator -DDEFAULTSHARES=2 保持一致
    const int wide_words = (128 * d + 31) / 32;

    uint64_t plaintext_low = 0x0000000000000000ULL;
    uint64_t plaintext_high = 0x0000000000000000ULL;
    uint64_t key_low = 0x0000000000000000ULL;
    uint64_t key_high = 0x0000000000000000ULL;

    plaintext_low = 0x8d305a88a8f64332ULL;
    plaintext_high = 0x340737e0a2983131ULL;
    key_low = 0xa6d2ae2816157e2bULL;
    key_high = 0x3c4fcf098815f7abULL;

    // expand umsk_key -> sh_key
    uint32_t sh_key[8] = {0};
    expand_masked_input(sh_key, key_low, key_high, d);
    for (int i = 0; i < wide_words; ++i)
        dut->sh_key[i] = sh_key[i];

    // expand umsk_plaintext -> sh_plaintext
    uint32_t sh_plaintext[8] = {0};
    expand_masked_input(sh_plaintext, plaintext_low, plaintext_high, d);
    for (int i = 0; i < wide_words; ++i)
        dut->sh_plaintext[i] = sh_plaintext[i];

    // Reset
    dut->nrst = 0;
    for (int i = 0; i < 5; ++i) tick(dut);
    dut->nrst = 1;
    dut->prng_start_reseed = 1;
    tick(dut);
    dut->prng_start_reseed = 0;

    for (int i = 0; i < 30; ++i) tick(dut);

    dut->valid_in = 1;
    tick(dut);
    dut->valid_in = 0;

    while (!dut->cipher_valid && main_time < 500) tick(dut);

    if (!dut->cipher_valid) {
        std::cerr << "Timeout!" << std::endl;
        return 1;
    }

    uint8_t recombined[128] = {0};
    recombine(recombined, dut->sh_ciphertext, d);

    std::cout << "Recombined ciphertext: 0x";
    for (int i = 0; i < 128; i += 8) {
        uint8_t byte = 0;
        for (int j = 0; j < 8; ++j)
            byte |= (recombined[i + j] << (7 - j));
        std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)byte;
    }
    std::cout << std::endl;

    delete dut;
    return 0;
}
