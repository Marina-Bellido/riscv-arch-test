///////////////////////////////////////////
// ExceptionsZaamo.S
//
// Written: Roman De Santos rdesantos@hmc.edu 31 March 2025
//
// Purpose: Functional coverage test for Exceptions from the Zaamo Extension
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#define SKIP_MTVAL  # flags to skip mtval and mepc checks since we an Instruction Access Fault (IAF) test
#define IAF # Instruction Access Fault: logic to adjust mepc to return to ra for instruction access fault

#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32IA_Zicsr, RV64IA_Zicsr")
# Test code region
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

#ifdef TEST_CASE_1
    RVTEST_CASE(1,"//check ISA:=regex(.*I.*A.*Zicsr.*blocked.*)); def rvtest_mtrap_routine=True; def rvtest_strap_routine=True; def rvtest_dtrap_routine=True; def TEST_CASE_1=True",ExceptionsZaamo)
    RVTEST_SIGBASE( x3,signature_base)
//BLOCKED.*
	.attribute unaligned_access, 0
	.attribute stack_align, 16
  	.align	2   
  	.option norvc

main:


 # set up PMP so user and supervisor mode can access full address space
    csrw pmpcfg0, 0xF   # configure PMP0 to TOR RWX
    LI(t0, 0xFFFFFFFF)
    csrw pmpaddr0, t0   # configure PMP0 top of range to 0xFFFFFFFF to allow all 32-bit addresses
    csrw satp, x0       # turn off satp to disable VM 


    RVTEST_GOTO_MMODE   


/////////////////////////////////
//cp_load_address_misaligned
/////////////////////////////////

// Test values 0-7 as the LSB for rs1 of the AMO instructions

    li   a2, 0         // loop counter
    li   a3, 8         // loop limit
loop:

    // Call the Zaamo_Instructions function
    // a2 = misalignment value, No instruction access fault (a1 = 0)
    mv  a0, a2
    li  a1, 0
    jal Zaamo_Instructions

    addi a2, a2, 1      // Increment loop counter by 1
    blt  a2, a3, loop   // If a2 is less than 8, branch back to 'loop'

/////////////////////////////////
//cp_load_access_fault
/////////////////////////////////

    // Call the Zaamo_Instructions function
    // No missalignment (a2 = 0),
    // Enable Instruction access fault (a1 = 1)
    li  a0, 0
    li  a1, 1
    jal Zaamo_Instructions

finished:
    j test_end

// Function: Zaamo_Instructions
// Purpose: Tests the atomic memory operations (AMOs) in RISC-V.
// The function performs a series of atomic memory operations from the Zaamo extension
//
// The function takes two arguments:
// a0: The misalignment value of rs1.
// a1: A flag indicating whether to load the Access Fault address.

Zaamo_Instructions:
    //initialize scratch memory
    la      t0, scratch

    li      t1, 0xDEADBEEF

    sw      t1, 0(t0)
    sw      t1, 4(t0)
    sw      t1, 8(t0)
    sw      t1, 12(t0)

    // Update scratch address to be misaligned based a0 argument
    add t0, a0, t0

    // If testing for an instruction
    // load the Access Fault address to the base address
    li t1, 1
    bne a1, t1, skipIAF
    li    t0, ACCESS_FAULT_ADDRESS

 skipIAF:

    amoswap.w t2, t1, (t0)

    amoadd.w t3, t2, (t0)

    amoxor.w t4, t3, (t0)

    amoand.w t5, t4, (t0)

    amoor.w t6, t5, (t0)

    amomin.w t1, t6, (t0)

    amomax.w t2, t1, (t0)

    amominu.w t3, t2, (t0)

    amomaxu.w t4, t3, (t0)

    // Test Rv64 AMO instructions
    #ifdef __riscv_xlen
        #if __riscv_xlen == 64
            amoswap.d t2, t1, (t0)

            amoadd.d t3, t2, (t0)

            amoxor.d t4, t3, (t0)

            amoand.d t5, t4, (t0)

            amoor.d t6, t5, (t0)

            amomin.d t1, t6, (t0)

            amomax.d t2, t1, (t0)

            amominu.d t3, t2, (t0)

            amomaxu.d t4, t3, (t0)
        #endif
    #endif

    ret


test_end:



#endif

 # ---------------------------------------------------------------------------------------------
    # HALT

RVTEST_CODE_END
RVMODEL_HALT

# Allocate scratch memory in .bss section
.section .bss
.align 4
scratch:
    .space 136  # Reserve 136 bytes of uninitialized memory


RVTEST_DATA_BEGIN
# Input data section.
.data
.align 4
rvtest_data:
.word 0xb0bacafe
.word 0xb0bacafe
RVTEST_DATA_END

# Output data section.
RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;
signature_base:
    .fill 20*(XLEN/32),4,0xdeadbeef

#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
.fill 5000*(XLEN/32),4,0xb0bacafe


#Prof Harris mentioned we should probably start with 10000
tsig_end_canary:
CANARY;

#endif

#ifdef rvtest_gpr_save
gpr_save:
  .fill 32*(XLEN/32), 4, 0xdeadbeef
#endif



sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END


