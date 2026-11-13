
import ucie_pkg::*;

module ucie_rx_ckeck(
    //--- General --
    input logic clk,
    input logic rst_n,

    //--- link status ---
    input logic link_active,

    //--- tx side ---
    input ucie_flit_t flit_in,
    input logic flit_valid,

    //--- output ---
    output logic [PAYLOAD_W-1:0] payload_out,
    output logic payload_valid,
    output logic ack,
    output logic [SEQ_W-1:0] ack_seq,
    output logic nack,
    output logic [SEQ_W-1:0] nack_seq,
    output logic credit_return
);
    
    logic [CRC_W-1:0] expected_crc;
    logic crc_valid;
    
    logic check;

    logic [SEQ_W-1:0] expected_seq;
    logic seq_valid;


    //--- crc ---
    assign expected_crc = crc_calc({flit_in.seq, flit_in.sop, flit_in.eop, flit_in.payload});
    assign crc_valid = (flit_in.crc == expected_crc);

    //--- activation ---
    assign check = flit_valid && link_active;

    //--- seq ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_seq <= 0;
        end else if (ack) begin
            expected_seq <= expected_seq + 1;
        end
    end

    assign seq_valid = (flit_in.seq == expected_seq);

    //--- ack ---
    assign ack = check && seq_valid && crc_valid;
    assign ack_seq = flit_in.seq;

    //--- nack ---
    assign nack = check && (!seq_valid || !crc_valid);
    assign nack_seq = expected_seq;

    //--- payload ---
    assign payload_out = flit_in.payload;
    assign payload_valid = ack;

    //--- credit ---
    assign credit_return = ack;

endmodule
