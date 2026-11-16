import ucie_pkg::*;

module ucie_chan #(
    parameter int TX_CH_DELAY = 2,
    parameter int RX_CH_DELAY = 2
)(
    //--- General ---
    input logic clk,
    input logic rst_n,

    //--- transmiter phy ---
    input ucie_flit_t phy_flit_in,
    input logic phy_valid_in,
    
    output ucie_flit_t phy_flit_out,
    output logic phy_valid_out,

    //--- receiver phy ---
    input logic ack_in,
    input logic [SEQ_W-1:0] ack_seq_in,
    input logic nack_in,
    input logic [SEQ_W-1:0] nack_seq_in,
    input logic credit_return_in,

    output logic ack_out,
    output logic [SEQ_W-1:0] ack_seq_out,
    output logic nack_out,
    output logic [SEQ_W-1:0] nack_seq_out,
    output logic credit_return_out,

    //--- crtl ---
    input logic corrupt_en
);

    ucie_flit_t corrupted_phy_flit;

    ucie_flit_t phy_flit[TX_CH_DELAY];
    logic phy_valid [TX_CH_DELAY];

    logic ack[RX_CH_DELAY];
    logic [SEQ_W-1:0] ack_seq[RX_CH_DELAY];
    logic nack_out[RX_CH_DELAY];
    logic [SEQ_W-1:0] nack_seq[RX_CH_DELAY];
    logic credit_return[RX_CH_DELAY];


    assign corrupted_phy_flit = phy_flit_in >> 1;
    

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < TX_CH_DELAY; i++) begin
                phy_flit[i] <= '0;
                phy_valid <= 1'b0;
            end
        end else begin
            phy_flit[0] <= corrupt_en ? corrupted_phy_flit : phy_flit_in;
            phy_valid[0] <= phy_valid_in;

            for (int i = 0; i < TX_CH_DELAY - 1; i++) begin
                phy_flit[i + 1] <= phy_flit[i];
                phy_valid[i + 1] <= phy_flit[i];
            end
        end
    end

    assign phy_flit_out = phy_flit[TX_CH_DELAY - 1];
    assign phy_valid_out = phy_valid[TX_CH_DELAY - 1];


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < RX_CH_DELAY; i++) begin
                ack[i] <= 1'b0;
                ack_seq[i] <= '0;
                nack[i] <= 1'b0;
                nack_seq[i] <= '0;
                credit_return[i] <= 1'b0;
            end
        end else begin
            ack[0] <= ack_in;
            ack_seq[0] <= ack_seq_in;
            nack[0] <= nack_in;
            nack_seq[0] <= nack_seq_in;
            credit_return[0] <= credit_return_in;

            for (int i = 0; i < RX_CH_DELAY - 1; i++) begin
                ack[i + 1] <= ack[i];
                ack_seq[i + 1] <= ack_seq[i];
                nack[i + 1] <= nack[i];
                nack_seq[i + 1] <= nack_seq[i];
                credit_return[i + 1] <= credit_return[i];
            end
        end
    end

    assign ack_out = ack[RX_CH_DELAY - 1];
    assign ack_seq_out = ack_seq[RX_CH_DELAY - 1];
    assign nack_out = nack[RX_CH_DELAY - 1];
    assign nack_seq_out = nack_seq[RX_CH_DELAY - 1];
    assign credit_return_out = credit_return[RX_CH_DELAY - 1];

endmodule
