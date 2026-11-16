
import ucie_pkg::*;

module uice_tx_framer (
    
    //--- General ----
    input logic clk,
    input logic rst_n,

    //--- protocol layer ---
    input logic [PAYLOAD_W-1:0] txn_payload,

    //--- ctrl ---
    input logic [SEQ_W-1:0] seq_next,

    //--- flit ---
    output ucie_flit_t flit_out
);

    assign flit_out.seq = seq_next;
    assign flit_out.sop = 1'b1;
    assign flit_out.eop = 1'b1;
    assign flit_out.payload = txn_payload;
    assign flit_out.crc = calc_crc16_f({flit.seq, flit.sop, flit.eop, flit.payload});


    //--- SVA ---
    property p_crc_valid;
        @(posedge clk) disable iff (!rst_n)
        flit_valid |-> (flit_out.crc == calc_crc16_f({flit_out.seq, flit_out.sop, flit_out.eop, flit_out.payload}));
    endproperty

    a_crc_valid: assert property(p_crc_valid)
        else $error("CRC is not correct.");

endmodule
