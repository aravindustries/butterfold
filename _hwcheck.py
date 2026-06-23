"""Temporary bit-exactness harness for the hierarchical (top+kernel) split.

Usage:
  python _hwcheck.py emit     # write golden TB with inlined seed-42 input + expected.npy
  python _hwcheck.py compare  # parse generated/logs/hwcheck.log, report EVM vs expected
"""
import sys, pathlib, numpy as np

ROOT = pathlib.Path(__file__).parent
sys.path.insert(0, str(ROOT))
from butterfold_sim.waveform import qam_symbols, tx_chain
from butterfold_sim.fixed_point import quantize_complex_stream

K, M, CP = 12, 128, 9
LOG = ROOT / "generated" / "logs" / "hwcheck.log"
EXP = ROOT / "generated" / "logs" / "hwcheck_expected.npy"
TB  = ROOT / "_tb_hwcheck.v"


def _vectors():
    rng = np.random.default_rng(42)
    sym = qam_symbols(K, rng=rng)
    ib, _ = quantize_complex_stream(sym, scale=127.0)
    tx = tx_chain(sym, m=M, cp_len=CP, folded=True)
    exp, _ = quantize_complex_stream(tx.time_with_cp, scale=127.0)
    return ib, exp


def emit():
    ib, exp = _vectors()
    EXP.parent.mkdir(parents=True, exist_ok=True)
    np.save(EXP, exp.astype(np.int8))
    inits = "\n".join(f"    tx_input[{i}] = 8'h{v & 0xFF:02x};" for i, v in enumerate(ib.tolist()))
    n = len(ib)
    TB.write_text(f"""\
`timescale 1ns/1ps
module tb_hwcheck;
  reg clk=0, rst_n=0, mode=0, din_valid=0; reg [7:0] din=0;
  wire [7:0] dout; wire dout_valid, busy, done;
  butterfold_top dut(.clk(clk),.rst_n(rst_n),.mode(mode),.din(din),.din_valid(din_valid),
                     .dout(dout),.dout_valid(dout_valid),.busy(busy),.done(done));
  always #5 clk = ~clk;
  reg [7:0] tx_input [0:{n-1}]; integer i; reg timeout=0;
  initial begin
{inits}
  end
  initial begin
    rst_n=0; mode=0; repeat(4) @(posedge clk); rst_n=1; @(posedge clk);
    din_valid=1;
    for (i=0;i<{n};i=i+1) begin din=tx_input[i]; @(posedge clk); end
    din_valid=0; wait(done||timeout); repeat(5) @(posedge clk); $finish;
  end
  initial begin #500000; timeout=1; $display("HW_TIMEOUT"); $finish; end
  always @(posedge clk) if (dout_valid) $display("OUT: %02x", dout);
endmodule
""")
    print(f"[hwcheck] wrote {TB.name} ({n} input bytes) and {EXP.name} ({len(exp)} expected bytes)")


def compare():
    exp = np.load(EXP)
    raw = []
    for line in LOG.read_text().splitlines():
        if line.startswith("OUT: "):
            v = int(line[5:].strip(), 16)
            raw.append(v if v < 128 else v - 256)
    if "HW_TIMEOUT" in LOG.read_text():
        print("[hwcheck] FAIL: simulation timed out"); return
    n = len(exp)
    if len(raw) < n:
        print(f"[hwcheck] FAIL: got {len(raw)} bytes, expected {n}"); return
    act = np.array(raw[:n], dtype=np.int8)
    mism = int(np.sum(act != exp))
    ac = act[0::2].astype(float) + 1j*act[1::2].astype(float)
    ec = exp[0::2].astype(float) + 1j*exp[1::2].astype(float)
    evm = 100.0*np.sqrt(np.mean(np.abs(ac-ec)**2)/np.mean(np.abs(ec)**2))
    print(f"[hwcheck] hierarchical top+kernel: EVM={evm:.4f}%  mismatches={mism}/{n}  "
          f"-> {'BIT-EXACT PASS' if mism == 0 else ('PASS' if evm < 2.0 else 'FAIL')}")


if __name__ == "__main__":
    {"emit": emit, "compare": compare}[sys.argv[1]]()
