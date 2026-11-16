import uci_pkg::*;

module ucie_rx_deframer(
    //--- Genral ---
    input logic clk,
    input logic rst_n,

    //--- rx ---
    input logic sop,
    input logic eop,
    input logic [PAYLOAD_W-1:0] payload_out,
    input logic payload_valid,

    //--- output ---
    output logic [(MAX_FLITS*PAYLOAD_W)-1:0] txn_data,
    output logic [$clog2(MAX_FLITS)-1:0] txn_len,
    output logic txn_valid,

    //--- status ---
    output logic pkt_error
);

    

endmodule
