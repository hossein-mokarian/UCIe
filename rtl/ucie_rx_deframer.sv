import uci_pkg::*;

module ucie_rx_deframer(
    //--- Genral ---
    input logic clk,
    input logic rst_n,

    //--- rx ---
    input logic sop,
    input logic eop,
    input logic [PAYLOAD_W-1:0] payload,
    input logic payload_valid,

    //--- output ---
    output logic [(MAX_FLITS*PAYLOAD_W)-1:0] txn_data,
    output logic [$clog2(MAX_FLITS):0] txn_len,
    output logic txn_valid,

    //--- status ---
    output logic pkt_error
);

    typedef enum logic [1:0] { 
        S_DF_WAIT_FOR_SOP,
        S_DF_COLLECT,
    } s_df_state_e;

    s_df_state_e state;

    logic [PAYLOAD_W-1:0] sr_data [MAX_FLITS-1];
    logic [$clog2(MAX_FLITS):0] flit_cnt;
    logic start_flit;
    logic collect_flit;
    logic last_flit;
    logic single_flit;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_DF_WAIT_FOR_SOP;
        end else begin
            case (state)
                S_DF_WAIT_FOR_SOP: if (payload_valid && sop && !eop) state <= S_DF_COLLECT;
                S_DF_COLLECT: if (last_flit || pkt_error) state <= S_DF_WAIT_FOR_SOP;
                default: state <= S_DF_WAIT_FOR_SOP;
            endcase
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MAX_FLITS; i++) begin
                sr_data[i] <= '0;
            end
        end else if (payload_valid) begin
            sr_data[0] <= payload;
            for (int i = 0; i < (MAX_FLITS - 2); i++) begin
                sr_data[i+1] <= sr_data[i];
            end
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flit_cnt <= 'd0;
        end else begin
            if (pkt_error || last_flit) begin
                flit_cnt <= 'd0;
            end else if (start_flit || collect_flit) begin
                flit_cnt <= flit_cnt + 1;
            end
        end
    end


    assign start_flit = (state == S_DF_WAIT_FOR_SOP) && payload_valid && sop && !eop;
    assign collect_flit = (state == S_DF_COLLECT) && payload_valid && !sop && !eop;
    assign last_flit = (state == S_DF_COLLECT) && payload_valid && !sop && eop;
    assign single_flit = (state == S_DF_WAIT_FOR_SOP) && payload_valid && sop && eop;


    assign txn_valid = (!pkt_error && (single_flit || last_flit)) ? 1'b1 : 1'b0;

    
    always_comb begin
        txn_data[PAYLOAD_W-1:0] = payload;
        if (last_flit) begin
            for (int i = 0; i < (flit_cnt); i++) begin
                txn_data[(i+1)*PAYLOAD_W-1:(i * PAYLOAD_W)] = sr_data[i];
            end
        end
    end

    always_comb begin
        txn_len = 'd0;
        if (!pkt_error) begin
            if (single_flit) begin
                txn_len = 'd1;
            end else if (last_flit) begin
                txn_len = flit_cnt + 1;
            end
        end
    end


    assign pkt_error = ( ((flit_cnt == MAX_FLITS - 1) && payload_valid && !eop)
                            || (state == S_DF_COLLECT && sop)
                            || (state == S_DF_WAIT_FOR_SOP && ({sop,eop} == 1'b01))
                        ) 
                        ? 1'b1 
                        : 1'b0;
    

    //--- SVA ---

    property p_txn_valid;
        @(posedge clk) disable iff (!rst_n)
        txn_valid |-> (payload_valid && eop);
    endproperty

    property p_txn_len_max;
        @(posedge clk) disable iff (!rst_n)
        (txn_len <= MAX_FLITS);
    endproperty

    a_txn_valid: assert property(p_txn_valid)
        else $error("txn_valid is high while payload_valid and eop are not high.");
    
    a_txn_len_max: assert property(p_txn_len_max)
        else $error("txn_len is greater than MAX_FLITS.");

endmodule
