import ucie_pkg::*;

module ucie_tx_packetizer(
    //--- Genral ---
    input logic clk,
    input logic rst_n,

    //--- status ---
    input logic link_active,

    //--- protocol layer ---
    input logic [MAX_FLITS*PAYLOAD_W-1:0] txn_payload,
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

    typedef enum logic[2:0] { 
        S_PT_IDLE,
        S_PT_SOP,
        S_PT_IN_PKT,
        S_PT_EOP
    } pt_state_e;

    pt_state_e state;

    logic [MAX_FLITS*PAYLOAD_W-1:0] payload;
    logic [$clog2(MAX_FLITS)-1:0] flit_cnt;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_PT_IDLE;
        end else begin
            case(state)
                S_PT_IDLE: if (link_active && txn_valid) state <= S_PT_SOP;
                S_PT_SOP: state <= S_PT_IN_PKT;
                S_PT_IN_PKT: if (flit_cnt == (MAX_FLITS - 1)) state <= S_PT_EOP;
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


    assign sop = (state == S_PT_SOP);
    assign eop = (state == S_PT_EOP);


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            payload <= '0;
        end else if (link_active && valid state == S_PT_IDLE) begin
            payload <= txn_payload;
        end
    end

    
    assign chunk_data = payload[((flit_cnt + 1)*PAYLOAD_W-1) : (flit_cnt*PAYLOAD_W)];
    assign chunk_valid = (status != S_PT_IDLE);


    assign txn_reday = ctrl_ready && (state == S_PT_EOP);

endmodule
