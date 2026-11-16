# UCIe Adapter Controller

A SystemVerilog implementation of the UCIe Adapter-layer digital core: framing, sequencing, CRC, credit-based flow control, go-back-N replay, and link training FSM.

> Scope: Adapter + simplified Protocol shim. PHY is a behavioral channel model in testbench only.

## 1. Why this exists

Monolithic SoCs hit reticle, yield, and process walls. Chiplets solve it by splitting logic across dies in one package, but dies must talk across 2-25mm of substrate/interposer.

UCIe solves it with wide parallel DDR + forward clock (no SerDes/CDR) + Adapter-layer reliability (CRC + replay + credits).

This repo implements the Adapter reliability core.

## 2. Architecture

```
txn_payload (Protocol shim, valid/ready)
  -> ucie_tx_framer (combinational pack: seq_in + sop/eop + payload + crc)
  -> ucie_tx_ctrl (seq_next, credits, replay_mem, replay FSM)
  -> ucie_chan (TB: FWD_LAT + corruptor) -> mainband
  -> ucie_rx_check (crc_ok + seq_ok -> accept / ACK / NACK / credit_return)
  -> ucie_chan back (RET_LAT) -> ucie_tx_ctrl

ucie_link_fsm -> link_active = (state == S_ACTIVE)
  gates: txn_ready, phy_valid, accept, nack
  storm: tx_ctrl.nack_storm -> fsm.nack_storm -> RETRAIN
```

### Files

* `rtl/ucie_pkg.sv` — `ucie_flit_t`, params, `calc_crc16_f()`, `ucie_link_state_e`
* `rtl/ucie_tx_framer.sv` — combinational packer, takes `seq_in` from ctrl, `sop=1,eop=1` in v0.1
* `rtl/ucie_tx_ctrl.sv` — owns `seq_next`, `credit_count`, `replay_buff`, replay logic
* `rtl/ucie_rx_check.sv` — CRC + in-order check, `ACK(expected)` / `NACK(expected)`
* `rtl/ucie_link_fsm.sv` — RESET/SBINIT/MBINIT/LINKINIT/ACTIVE/RETRAIN/LINKERROR
* `rtl/ucie_adapter_top.sv` — ties FSM + TX + RX, generates `link_active`
* `tb/ucie_chan.sv` — delay + CRC corruptor, forward + return path
* `tb/tb_ucie_loopback.sv` — v0.1 pass criteria tests

## 3. Flit format v0.1

1 transaction = 1 flit. `sop=1, eop=1` always in v0.1, kept for interface stability to v0.2 multi-flit.

```
| seq[7:0] | sop(1) | eop(1) | payload[63:0] | crc[15:0] | = 90 bits total
  <----------------- crc16_f() covers ------------------->
```

`payload[63:0]` lightweight TLP (CXL.io-inspired, documented as simplified):
`{id[3:0], cmd[3:0], addr[31:0], data[23:0]}` — define split yourself, keep stable.

CRC-16-CCITT poly 0x1021, init 0xFFFF. Placeholder vs spec CRC — documented, not hidden.

Why CRC covers seq+sop/eop+payload:
* seq covered -> corrupted seq fails CRC, prevents wrong ACK freeing wrong replay entry. Lost flit caught by `expected vs received` gap.
* sop/eop covered -> corrupted boundary becomes detectable CRC fail -> NACK -> replay, instead of silent deframer merge.

## 4. Core design rules

1. `flit_sent = txn_valid & txn_ready`, `txn_ready = link_active & ~replay_mode & (credit_count != 0)`. `seq` moves only on real transfer. Else hole -> permanent NACK -> storm.
2. PHY is push-only `DATA+CLK+VALID`, no `ready`. Backpressure = credits. TX sends only if `credit_count > 0`.
3. One send = -1 credit. One accept = +1 credit_return. Replay send = 0 credit change. Pairing is send-once / return-once, independent of latency.
4. RX accepts only if `crc_valid & seq_valid`. Else drop (even good-CRC wrong-seq flit dropped) + `NACK(expected_seq)`. This forces go-back-N order.
5. `nack_storm = (nack_storm_cnt >= 5)`. 1 random fail -> ACTIVE + replay. 5x same seq fail -> channel broken -> RETRAIN.

## 5. Link FSM

```
RESET -> SBINIT -> MBINIT -> LINKINIT -> ACTIVE
                      ^                    |
                      |------ RETRAIN <-----|
                                             -> LINKERROR (sticky, needs rst_n)
```

* RESET: sideband down, nothing sent.
* SBINIT: sideband handshake, caps, CREDIT_INIT, flit size.
* MBINIT: training pattern + forward clock, RX `mb_locked` after K good patterns.
* LINKINIT: `seq_tx=0, seq_exp=0, credit=CREDIT_INIT, clear replay_byff`, handshake flits.
* ACTIVE: framing + credits + CRC + replay.
* RETRAIN: pause `phy_valid`, re-run MBTRAIN, resume same seq.
* LINKERROR: excessive retrain / sb_lost / fatal. Sticky.

### Preserve vs clear

| Register | RESET / LINKINIT entry | RETRAIN entry + exit |
|---|---|---|
| `seq_next` (TX next seq) | clear to 0 | HOLD (e.g. 10 stays 10) |
| `expected_seq` (RX expected) | clear to 0 | HOLD (e.g. 8 stays 8) |
| `credit_count` | init to CREDIT_INIT (16) | HOLD (e.g. 14 stays 14) |
| `replay_buff` replay buffer | clear all to 0 | HOLD (flits 8,9 kept) |
| `nack_storm_cnt` | clear to 0 | HOLD (storm count kept) |
| `replay_buff / replay_ptr` | clear to 0 | HOLD (resume 8,9 on ACTIVE) |
| `phy_valid` | 0 | forced 0 during RETRAIN, resume after |

Why clearing on RETRAIN corrupts: TX cleared to 0 sends seq 0, RX expects 8 -> drop + NACK(8) forever, replay mem empty, `credit_count=16` lies. Livelock -> storm again.

## 6. What is simplified vs real UCIe (read this in interview)

* Flit 64-bit, not 64B/256B. Parameterized width to grow. Simulates fast.
* Single-flit packets only in v0.1. Multi-flit + deframer reassembly FSM in v0.2.
* CRC-16 placeholder, not spec CRC/FEC.
* One credit pool, not per-class pools. `CREDIT_INIT=16`.
* `credit_return` coupled with `ACK` in v0.1 (`accept -> ack + credit`). Real UCIe separates them. Kept as two signals to split later.
* Sideband = TB behavioral pulses, not pin-accurate.
* PHY = synchronous abstraction + delay, no DDR flops, no analog.

## 7. v0.1 pass criteria (tb_ucie_loopback.sv)

1. Clean: LINKINIT->ACTIVE, 10 flits, FWD_LAT=2 RET_LAT=2, no corrupt. `seq_next 0..9`, `expected_seq 0..10`, `credit_count` dips then back to 16.
2. One error: corrupt flit 2 once. NACK(2), replay 2,3, no storm.
3. Storm: corrupt same seq 5x. `nack_storm=1`, ACTIVE->RETRAIN, hold seq/credit, `mb_locked`->ACTIVE, resume same seq.
4. Reset: `rst_n` in ACTIVE. All cleared, full SBINIT->MBINIT->LINKINIT required.

## 8. Roadmap

* v0.1: single-flit (SOP=1/EOP1). It is done.
* v0.2: multi-flit (SOP/EOP + length), deframer reassembly FSM, separate credit_return vs ACK latency. It is done.
* v0.3: UVM env + SVA suite + coverage, sideband message protocol, v1.0 release. In progress.

## 9. How to run

```bash
# Verilator / Questa / VCS
# compile rtl/ucie_pkg.sv + rtl/*.sv + tb/*.sv, run tb_ucie_loopback
```

## 10. One-flit trace

Protocol TLP -> Adapter assigns seq=5, sop/eop, CRC -> check `credit>0 & ACTIVE` -> send, `credit--`, store copy -> channel 2cyc -> RX recompute CRC + `seq==expected?` -> if ok consume + ACK(5) + credit_return -> TX on ACK frees entry, on return `credit++`. If CRC fail -> NACK(5) -> TX replays 5,6.. go-back-N. 5x fail same seq -> RETRAIN (hold state, relock), sb_lost/excessive -> LINKERROR.