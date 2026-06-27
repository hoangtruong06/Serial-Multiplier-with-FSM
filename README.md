# Serial Multiplier with FSM

This repository features a digital design of an **8-bit Serial Multiplier** implemented in Verilog. The core architecture focuses on the fundamental hardware design principle of separating the **Control Unit (Finite State Machine)** from the **Datapath** (consisting of registers, adders, and shifters).

> **Language:** Verilog HDL  
> **Synthesis & Simulation Tool:** AMD Xilinx Vivado 2025.2  
> **Target Board:** ZCU104 (Synthesis only)  

---

## Part 1: The Shift-and-Add Algorithm 

### 1.1 — How Binary Multiplication Works
Multiplying in binary follows the same principle as decimal long multiplication. Consider multiplying `13 × 11` (binary: `1101 × 1011`):

```text
        1 1 0 1     (13, multiplicand)
    ×   1 0 1 1     (11, multiplier)
    -----------
        1 1 0 1     bit 0 of multiplier = 1, so add multiplicand
      1 1 0 1 0     bit 1 = 1, so add multiplicand shifted left by 1
    0 0 0 0 0 0 0   bit 2 = 0, so add nothing
  1 1 0 1 0 0 0 0   bit 3 = 1, so add multiplicand shifted left by 3
  ---------------
  1 0 0 0 1 1 1 1   = 143 in decimal  ✓
```

The shift-and-add algorithm does this iteratively rather than all at once:
1. Start with a 16-bit accumulator = `0`, the 8-bit multiplicand (`A`), and the 8-bit multiplier (`B`).
2. **For each bit of B (8 iterations):**
   - If the LSB (least significant bit) of `B` is `1`: add `A` to the upper 8 bits of the accumulator.
   - Shift the entire accumulator right by 1 bit (this effectively shifts `A`'s contribution left for the next iteration).
   - Shift `B` right by 1 bit (to examine the next bit).
3. After 8 iterations, the accumulator holds the 16-bit product.

### 1.2 — Worked Example: 5 × 3
`A = 5` (`00000101`), `B = 3` (`00000011`). Accumulator is 16 bits: `[upper 8 | lower 8]`.

| Step | `B[0]` | Action | Accumulator (16 bits) | `B` (8 bits) |
| :---: | :---: | :--- | :--- | :--- |
| **Init** | — | — | `00000000 00000000` | `00000011` |
| **1** | `1` | Add `A` to upper, then shift right | `00000010 10000000` | `00000001` |
| **2** | `1` | Add `A` to upper, then shift right | `00000011 11000000` | `00000000` |
| **3** | `0` | Shift right only | `00000001 11100000` | `00000000` |
| **4** | `0` | Shift right only | `00000000 11110000` | `00000000` |
| **5** | `0` | Shift right only | `00000000 01111000` | `00000000` |
| **6** | `0` | Shift right only | `00000000 00111100` | `00000000` |
| **7** | `0` | Shift right only | `00000000 00011110` | `00000000` |
| **8** | `0` | Shift right only | `00000000 00001111` | `00000000` |

*Final accumulator = `00000000 00001111` = 15. Correct! (5 × 3 = 15)*

---

## Part 2: Architecture Design

### 2.1 — Block Diagram
The serial multiplier is split into two interacting parts: a controller (FSM) and a datapath (registers + arithmetic). The controller tells the datapath what to do each cycle; the datapath reports status back to the controller.

The FSM generates four control signals that drive the datapath, and receives two status signals back:

| Signal | Direction | Description |
| :--- | :---: | :--- |
| `load` | FSM → Datapath | Load `A`, `B` into registers and clear accumulator. |
| `do_add` | FSM → Datapath | Add `a_reg` to the upper half of accumulator. |
| `do_shift` | FSM → Datapath | Shift accumulator and `b_reg` right by 1, increment counter. |
| `set_done` | FSM → Datapath | Copy accumulator to product output, assert done flag. |
| `b_lsb` | Datapath → FSM | Least significant bit of multiplier register (`B[0]`). |
| `count_done`| Datapath → FSM | High when iteration counter reaches WIDTH (all bits processed). |

### 2.2 — Datapath Detail
Inside the datapath, the registers and arithmetic are connected to respond to the FSM's control signals on each clock cycle:

* **`load`**: `a_reg ← A`, `b_reg ← B`, `acc ← 0`, `count ← 0`
* **`do_add`**: `acc[15:8] ← acc[15:8] + a_reg` *(add multiplicand to upper half)*
* **`do_shift`**: `acc ← acc >> 1`, `b_reg ← b_reg >> 1`, `count ← count + 1`
* **`set_done`**: `product ← acc`, `done ← 1`

### 2.3 — FSM States

| State | Description | Control Signals Asserted | Transition Logic |
| :--- | :--- | :--- | :--- |
| **`IDLE`** | Waiting for start | `load` *(when start=1)* | `start=1` → **`CALC`**; else stay **`IDLE`** |
| **`CALC`** | One iteration: check bit, add if needed, shift | `do_add` *(if b_lsb=1)*, `do_shift` | `count_done=1` → **`DONE`**; else stay **`CALC`** |
| **`DONE`** | Multiplication complete | `set_done` | Stay **`DONE`** until reset |
