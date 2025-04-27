#include "Vsoc_lite_top.h" // Verilator生成的模型头文件
#include "verilated.h"
#include "verilated_vcd_c.h" // 用于生成VCD波形文件
#include <iostream>
#include <fstream>
#include <sstream> // 添加对 std::istringstream 的支持
#include <iomanip>

#define TRACE_REF_FILE "./golden_trace.txt"
#define END_PC 0x1c000100

vluint64_t main_time = 0; // 当前仿真时间

double sc_time_stamp()
{
    return main_time; // 返回当前仿真时间
}

VerilatedContext *contextp = NULL;
VerilatedVcdC *tfp = NULL;

static Vsoc_lite_top *top; // 修改2

void step_and_dump_wave()
{
    top->eval();
    tfp->dump(contextp->time());
    contextp->timeInc(1);
}

void sim_init()
{
    contextp = new VerilatedContext;
    tfp = new VerilatedVcdC;
    top = new Vsoc_lite_top; // 修改3
    contextp->traceEverOn(true);
    top->trace(tfp, 0);
    tfp->open("dump.vcd");
}

void sim_exit()
{
    step_and_dump_wave();
    delete top;
    tfp->close();
    delete contextp;
}

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    sim_init();

    // 打开参考文件
    std::ifstream trace_ref(TRACE_REF_FILE);
    if (!trace_ref.is_open())
    {
        std::cerr << "Failed to open trace reference file: " << TRACE_REF_FILE << std::endl;
        return -1;
    }

    // 初始化信号
    top->resetn = 0;
    top->clk = 0;

    // 执行至少6个完整的时钟周期用于复位
    for (int i = 0; i < 6; i++) {
        top->clk = !top->clk;
        step_and_dump_wave();
    }

    // 现在释放复位
    top->resetn = 1;
    step_and_dump_wave();

    // 声明变量
    uint8_t trace_cmp_flag = 0;
    uint32_t ref_wb_pc = 0;
    uint8_t ref_wb_rf_wnum = 0;
    uint32_t ref_wb_rf_wdata = 0;

    // 仿真循环
    while (!Verilated::gotFinish())
    {
        // 时钟信号
        top->clk = !top->clk;
        // 复位信号
        // if (contextp->time() >= 6)
        // {
        //     top->resetn = 1;
        // }

        top->switch_1 = 0xff;
        top->btn_key_row = 0;
        top->btn_step = 3;

        step_and_dump_wave();

        // 读取参考文件并比较数据    if(|debug_wb_rf_we && debug_wb_rf_wnum!=5'd0 && !debug_end && `CONFREG_OPEN_TRACE)
        if ((top->debug_wb_rf_wen != 0) && (top->debug_wb_rf_wnum != 0) && !trace_ref.eof() && top->open_trace)
        {
            // std::cout << "==============================================================" << std::endl;
            if (top->clk == 1)
            {
                std::string line;
                if (std::getline(trace_ref, line))
                {
                    std::istringstream iss(line);
                    std::string trace_cmp_flag_str, ref_wb_pc_str, ref_wb_rf_wnum_str, ref_wb_rf_wdata_str;
                    // 逐个读取字符串
                    iss >> trace_cmp_flag_str >> ref_wb_pc_str >> ref_wb_rf_wnum_str >> ref_wb_rf_wdata_str;

                    // 转换为数值
                    trace_cmp_flag = static_cast<uint8_t>(std::stoul(trace_cmp_flag_str, nullptr, 16)); // 第一列
                    ref_wb_pc = std::stoul(ref_wb_pc_str, nullptr, 16);                                 // 第二列
                    ref_wb_rf_wnum = static_cast<uint8_t>(std::stoul(ref_wb_rf_wnum_str, nullptr, 16)); // 第三列
                    ref_wb_rf_wdata = std::stoul(ref_wb_rf_wdata_str, nullptr, 16);                     // 第四列
                    // 重置输入流状态
                    iss.clear();
                    // 打印参考数据和仿真数据
                    std::cout << "    reference: PC = 0x" << std::left << std::setw(10) << std::hex << ref_wb_pc
                              << ", wb_rf_wnum = 0x" << std::left << std::setw(10) << static_cast<int>(ref_wb_rf_wnum)
                              << ", wb_rf_wdata = 0x" << std::left << std::setw(10) << ref_wb_rf_wdata << std::endl;
                } // end if (std::getline(trace_ref, line))
                std::cout << "    debug    : PC = 0x" << std::left << std::setw(10) << std::hex << top->debug_wb_pc
                          << ", wb_rf_wnum = 0x" << std::left << std::setw(10) << static_cast<int>(top->debug_wb_rf_wnum)
                          << ", wb_rf_wdata = 0x" << std::left << std::setw(10) << top->debug_wb_rf_wdata << std::endl;

                // 比较参考数据和仿真数据
                if (top->debug_wb_pc != ref_wb_pc || top->debug_wb_rf_wnum != ref_wb_rf_wnum ||
                    top->debug_wb_rf_wdata != ref_wb_rf_wdata)
                {
                    std::cerr << "Error: Simulation data does not match reference data!" << std::endl;

                    std::cout << "    debug    : PC = 0x" << std::left << std::setw(10) << std::hex << top->debug_wb_pc
                              << ", wb_rf_wnum = 0x" << std::left << std::setw(10) << static_cast<int>(top->debug_wb_rf_wnum)
                              << ", wb_rf_wdata = 0x" << std::left << std::setw(10) << top->debug_wb_rf_wdata << std::endl;

                    std::cout << "    reference: PC = 0x" << std::left << std::setw(10) << std::hex << ref_wb_pc
                              << ", wb_rf_wnum = 0x" << std::left << std::setw(10) << static_cast<int>(ref_wb_rf_wnum)
                              << ", wb_rf_wdata = 0x" << std::left << std::setw(10) << ref_wb_rf_wdata << std::endl;

                    break;
                } // end if (top->debug_wb_pc != ref_wb_pc || top->debug_wb_rf_wnum != ref_wb_rf_wnum ||
            }
        }

        // 检查仿真结束条件
        if (top->debug_wb_pc == END_PC || (contextp->time() > 1000000))
        {
            std::cout << "==============================================================" << std::endl;
            std::cout << "Test end!" << std::endl;
            // if (top->debug_wb_err) {
            //     std::cout << "Fail!!! Simulation error detected!" << std::endl;
            // } else {
            //     std::cout << "----PASS!!!" << std::endl;
            // }
            break;
        }
        // top->clk = !top->clk;
        // step_and_dump_wave();
    }

    // 关闭文件
    trace_ref.close();
    sim_exit();
    return 0;
}