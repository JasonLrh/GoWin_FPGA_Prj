cmake_minimum_required(VERSION 3.16)
project(firmware.elf)

enable_language(C ASM CXX)

set(CMAKE_SYSTEM_NAME riscv-32i)
set(CMAKE_C_COMPILER   riscv64-unknown-elf-gcc) 
set(CMAKE_ASM_COMPILER riscv64-unknown-elf-gcc)
set(CMAKE_CXX_COMPILER riscv64-unknown-elf-g++)
set(CMAKE_FIND_ROOT_PATH /opt/riscv/)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(RISCV_ARCH "-mabi=ilp32 -march=rv32i")
set(ASM_OPTIONS "-x assembler-with-cpp")
set(CMAKE_C_FLAGS "${RISCV_ARCH} -Os --std=c11 -Wall -ffreestanding -nostdlib")
set(CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS} ${ASM_OPTIONS}")

set(CMAKE_EXE_LINKER_FLAGS "-T../def.ld -Wl,-Map=map.map")

# set(CMAKE_EXE_LINKER_FLAGS "-T,../def.ld")
file(GLOB_RECURSE ASM_SOURCES "src/*.s")
file(GLOB_RECURSE C_SOURCES   "src/*.c")
file(GLOB_RECURSE CXX_SOURCES "src/*.cpp")

add_executable(${PROJECT_NAME} ${ASM_SOURCES} ${C_SOURCES} ${CXX_SOURCES})

# add_custom_target(POST_GENERATE DEPENDS ${PROJECT_NAME})

add_custom_target(OutTask ALL
    COMMAND "riscv64-unknown-elf-size" ${PROJECT_NAME}
    COMMAND "riscv64-unknown-elf-objcopy" "-O" "verilog" ${PROJECT_NAME} "verilog.bin"
    COMMAND "riscv64-unknown-elf-objcopy" "-O" "binary" ${PROJECT_NAME} "binary.bin"
    COMMAND "../tools/gen_gowin_mi.py"     "binary.bin" "gowin.mi"
    COMMAND "riscv64-unknown-elf-objdump" "-D" ${PROJECT_NAME} ">" "hack.S"
)
