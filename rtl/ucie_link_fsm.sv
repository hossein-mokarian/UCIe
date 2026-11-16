import ucie_pkg::*;

module ucie_link_fsm (
    //--- General ---
    input logic clk,
    input logic rst_n,

    //--- rx ---
    input logic mb_locked,

    //--- tx ctrl ---
    input logic nack_storm,

    //--- status ---
    output logic link_init,
    output logic link_active
);

    ucie_link_state_e state;

    logic [1:0] reset_cnt;
    logic sb_peer_ready;

    logic [2:0] idle_ptn_cnt;

    logic linkinit_ack;
    logic retrain_ack;

    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RESET;
        end else begin
            case(state)
                S_RESET: if (reset_cnt == 2'd2) state <= S_SBINIT;
                S_SBINIT: if (sb_peer_ready) state <= S_MBINIT;
                S_MBINIT: if (mb_locked) state <= S_LINKINIT;
                S_LINKINIT: if (linkinit_ack) state <= S_ACTIVE;
                S_ACTIVE: if (nack_storm) state <= S_RETRAIN;
                S_RETRAIN: if (retrain_ack) state <= S_ACTIVE;
                default: state <= S_RESET;
            endcase
        end
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_cnt <= '0;
        end else if (state == S_RESET) begin
            reset_cnt <= reset_cnt + 1'b1;
        end else begin
            reset_cnt <= '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sb_peer_ready <= 1'b0;
        end else if (state == S_SBINIT) begin
            sb_peer_ready <= 1'b1; // Todo:
        end else begin
            sb_peer_ready <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idle_ptn_cnt <= '0;
        end else if (state == S_MBINIT) begin
            if (idle_ptn_cnt < 3) begin
                idle_ptn_cnt <= idle_ptn_cnt + 1;
                // Todo: send idle pattern here
            end
        end else begin
            idle_ptn_cnt <= '0;
        end
    end


    assign retrain_ack = mb_locked;


    assign link_init = (state == link_init);
    assign link_active = (state == link_active);


endmodule