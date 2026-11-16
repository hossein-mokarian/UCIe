
import ucie_pkg::*;

module uice_tx_framer_v1 (
    
    //--- General ----
    input logic clk,
    input logic rst_n,

    //--- protocol layer ---
    input logic [PAYLOAD_W-1:0] txn_payload,
    input logic txn_valid,
    output logic txn_ready,

    //--- status ---
    input logic link_active, // ucie_link_s == S_ACTIVE
    input logic credit_grant, // credit_count != '0

    //--- flit ---
    output ucie_flit_t flit_out,
    output logic flit_valid
);

    logic [SEQ_W - 1 : 0] seq_count;
    logic flit_sent;

    assign txn_ready = link_active && credit_grant;
    assign flit_sent = txn_ready && txn_valid;

    assign flit_out.seq = seq_count;
    assign flit_out.sop = 1'b1;
    assign flit_out.eop = 1'b1;
    assign flit_out.payload = (txn_ready && txn_valid) ? txn_payload : '0;
    assign flit_out.crc = calc_crc16_f({flit.seq, flit.sop, flit.eop, flit.payload});

    assign flit_valid = flit_sent;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
                seq_count <= '0;
        end else if (flit_sent) begin
            seq_count <= seq_count + 1;
        end
    end


    //--- SVA ---

    logic [SEQ_W-1:0] exp_seq;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_seq <= '0;
        end else if (txn_valid && link_active && credit_grant) begin
            exp_seq <= exp_seq + 1;
        end
    end

    property p_ready_when_active_link_cerditgrant;
        @(posedge clk) disable iff (!rst_n)
        txn_ready |-> (link_active && credit_grant);
    endproperty

    property p_flit_valid;
        @(posedge clk) disable iff (!rst_n)
        flit_valid |-> (txn_valid && txn_ready);
    endproperty

    property p_stable_seq;
        @(posedge clk) disable iff (!rst_n)
        (txn_valid && link_active && credit_grant) |=> $stable(flit_out.seq);
    endproperty

    property p_expected_seq;
        @(posedge clk) disable iff (!rst_n)
        (txn_valid && link_active && credit_grant) |-> (flit_out.seq == exp_seq);
    endproperty

    property p_crc_valid;
        @(posedge clk) disable iff (!rst_n)
        flit_valid |-> (flit_out.crc == calc_crc16_f({flit_out.seq, flit_out.sop, flit_out.eop, flit_out.payload}));
    endproperty

    a_ready_when_active_link_cerditgrant: assert property(p_ready_when_active_link_cerditgrant)
        else $error("txn_reday is not high when the link_active and credit_grant are high.");

    a_flit_valid: assert property(p_flit_valid)
        else $error("flit_valid is not high when the input valid (txn_valid) and ready (txn_ready) are high.");
    
    a_stable_seq: assert property(p_stable_seq)
        else $error("flit_out.seq is not stable when there are not ant data transfering.");
    
    a_expected_seq: assert property(p_seq_advance)
        else $error("flit_out.seq is incorrect.");

    a_crc_valid: assert property(p_crc_valid)
        else $error("CRC is not correct.");

endmodule
