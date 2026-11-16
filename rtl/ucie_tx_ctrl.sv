import ucie_pkg::*;

module ucie_tx_ctrl #(
    parameter int REPLAY_BUFF_W = CREDIT_INIT,
    parameter int CNT_W = 5
)(
    //--- General ---
    input logic clk,
    input logic rst_n,

    //--- protocol layer ---
    input logic txn_valid,
    output logic txn_ready,

    //--- rx ---
    input logic ack,
    input logic [SEQ_W-1:0] ack_seq,
    input logic nack,
    input logic [SEQ_W-1:0] nack_seq,
    input logic credit_return,

    //--- tx framer ---
    output [SEQ_W-1:0] seq_next,
    input ucie_flit_t new_flit,

    //--- phy ---
    output ucie_flit_t phy_flit,
    output logic phy_valid,

    //--- status ---
    input logic link_active,
    output logic nack_storm

);

    typedef enum logic [2:0] { 
        S_IDLE,
        S_NEW_FLIT,
        S_REPLAY
     } state_t;

     state_t state;

    logic [@clog2(CREDIT_INIT)-1:0] credit_count;
    logic credit_grant;

    logic [SEQ_W-1:0] seq;
    logic new_flit_mode;

    ucie_flit_t replay_buff[REPLAY_BUFF_W];
    logic replay_mode;
    logic [$clog2(REPLAY_BUFF_W)-1:0] replay_ptr;

    logic [CNT_W-1:0] nack_storm_cnt;


    always_ff @(posedge clk or negedge rst_n) begin
        if !(rst_n) begin
            state <= S_IDLE;
        end else begin
            if (!link_active || nack_storm) begin
                state <= S_IDLE;
            end else begin
                case (state)
                    S_IDLE: if (link_active && !nack_storm) state <= S_NEW_FLIT;
                    S_NEW_FLIT: if (nack) state <= S_REPLAY;
                    S_REPLAY: if (replay_ptr == seq) state <= S_NEW_FLIT;
                    default: state <= S_IDLE;
                endcase
            end
        end
    end

    
    assign new_flit_mode = (state == S_NEW_FLIT);
    assign replay_mode = (state == S_REPLAY);


    //--- seq ---
    always_ff @posedge clk or negedge rst_n) begin
        if (!rst) begin
            seq <= '0;
        end else if (new_flit_mode && phy_valid) begin
            seq <= seq + 1;
        end
    end

    assign seq_next = seq;


    //--- credit counter ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_count <= CREDIT_INIT;
        end else if ((state == S_NEW_FLIT) && (credit_count > 0) && phy_valid) begin
            credit_count <= credit_count - 1 + (credit_count ? 1'b1 : 1'b0);
        end if ((state != S_IDLE) && credit_return) begin
            credit_count <= credit_count + 1;
        end
    end

    assign credit_grant = (credit_count != '0);


    //--- replat buffer ---
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (int i = 0; i < REPLAY_BUFF_W; i++) begin
                replay_buff[i] <= '0;
            end
        end else if (new_flit_mode && phy_valid) begin
            replay_buff[seq] <= phy_flit;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            replay_ptr <= '0;
        end else if (state != S_IDLE && nack) begin
            replay_ptr <= nack_seq;
        end else if (replay_mode) begin
            replay_ptr <= replay_ptr + 1;
        end
    end


    //--- protocol layer ---
    assign txn_ready = new_flit_mode ? (link_active && credit_grant && new_flit_mode) : 1'b0;


    //--- phy ---
    always_comb begin
        if (new_flit_mode) begin
            phy_flit = new_flit;
            phy_valid = (txn_ready && txn_valid);
        end else if (replay_mode) begin
             phy_flit = replay_buff[replay_ptr];
             phy_valid = credit_grant;
        end else begin
            phy_flit = '0;
            phy_valid = 1'b0;
        end
    end


    //--- nack strom ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nack_storm_cnt <= '0;
        end else if (state != S_IDLE) begin
            if (nack) begin
                nack_storm_cnt <= nack_storm_cnt + 1;
            end else (ack) begin
                nack_storm_cnt <= '0;
            end
        end
    end

    assign  nack_storm = (nack_storm_cnt >= NACK_STORM_THRESH);
    
    
endmodule
