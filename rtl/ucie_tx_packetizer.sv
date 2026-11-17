import ucie_pkg::*;

module ucie_tx_packetizer(
    //--- Genral ---
    input logic clk,
    input logic rst_n,

    //--- status ---
    input logic link_active,

    //--- protocol layer ---
    input logic [MAX_FLITS*PAYLOAD_W-1:0] txn_payload,
    input logic [$clog2(MAX_FLITS)-1:0] txn_len,
    input logic txn_valid,
    output logic txn_reday,

    //--- chunk data ---
    output logic sop,
    output logic eop,
    output logic [PAYLOAD_W-1:0] chunk_data,
    output logic chunk_valid,

    //--- ctrl ---
    input logic ctrl_ready
);

    typedef enum logic[1:0] { 
        S_PT_IDLE,
        S_PT_SOP,
        S_PT_IN_PKT,
        S_PT_EOP
    } pt_state_e;

    pt_state_e state;

    logic [MAX_FLITS*PAYLOAD_W-1:0] payload;
    logic [$clog2(MAX_FLITS)-1:0] flit_cnt;
    logic [$clog2(MAX_FLITS)-1:0] pkt_len;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_PT_IDLE;
        end else begin
            case(state)
                S_PT_IDLE: if (link_active && txn_valid) state <= S_PT_SOP;
                S_PT_SOP: if (pkt_len == 'd1) state <= S_PT_IDLE; else state <= S_PT_IN_PKT;
                S_PT_IN_PKT: if (flit_cnt == (pkt_len - 1)) state <= S_PT_EOP;
                S_PT_EOP: state <= S_PT_IDLE;
                default: state <= S_PT_IDLE;
            endcase
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flit_cnt <= '0;
        end else if (state != S_PT_IDLE) begin
            flit_cnt <= flit_cnt + 1;
        end else begin
            flit_cnt <= '0;
        end
    end


    assign sop = pkt_len == 'd1 || (state == S_PT_SOP);
    assign eop = pkt_len == 'd1 || (state == S_PT_EOP);


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            payload <= '0;
            pkt_len <= '0;
        end else if (link_active && valid state == S_PT_IDLE) begin
            payload <= txn_payload;
            pkt_len <= txn_len;
        end
    end

    
    assign chunk_data = payload[((flit_cnt + 1)*PAYLOAD_W-1) : (flit_cnt*PAYLOAD_W)];
    assign chunk_valid = (status != S_PT_IDLE);


    assign txn_reday = ctrl_ready && (state == S_PT_EOP);


    //--- SVA ---
    
    property p_txn_ready;
        @(posedge clk) disable iff (!rst_n)
        txn_ready |-> ctrl_ready;
    endproperty

    property p_sop;
        @(posedge clk or negedge rst_n)
        sop |-> (flit_cnt == '0 && state == S_PT_SOP);
    endproperty

    property p_eop;
        @(posedge clk or negedge rst_n)
        eop |-> (flit_cnt == (txn_len - 1) && state == S_PT_EOP);
    endproperty

    property p_single_flit;
        @(posedge clk or negedge rst_n)
        (sop && eop) |-> (txn_len == 'd1);
    endproperty

    a_txn_ready: assert property(p_txn_ready)
        else $error("txn_ready is high while ctrl is not ready.");

    a_sop: assert property(p_sop)
        else $error("sop must be one for the first flit.");
    
    a_eop: assert property(p_eop)
        else $error("eop must be one for the latest flit.");

    a_single_flit: assert property(p_single_flit)
        else $error("sop and eop must be one for the single flit.");

endmodule
