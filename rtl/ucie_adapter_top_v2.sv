import ucie_pkg::*;

module ucie_adaptor_top_v2 #(
    parameter int REPLAY_BUFF_W = CREDIT_INIT,
    parameter int CNT_W = 5,
    parameter int TX_CH_DELAY = 2,
    parameter int RX_CH_DELAY = 2
)(
    //--- General ---
    input logic clk,
    input logic rst_n,

    //--- protocol layer ---
    input logic [MAX_FLITS*PAYLOAD_W-1:0] txn_payload,
    input logic [$clog2(MAX_FLITS)-1:0] txn_len,
    input logic txn_valid,
    output logic txn_ready,

    //--- phy ---
    output ucie_flit_t phy_flit,
    output logic phy_valid,

    //--- status ---
    input logic mb_locked, // Todo: It is judt for test. Later we need to generate it by RX module.
    output logic nack_storm,

    //--- channel --- 
    input logic corrupted_en,

    //--- outputs ---
    output logic [(MAX_FLITS*PAYLOAD_W)-1:0] pkt_data,
    output logic [$clog2(MAX_FLITS)-1:0] pkt_len,
    output logic pkt_valid,
    output logic pkt_error
);

    logic sop;
    logic eop;
    logic [PAYLOAD_W-1:0] chunk_data;
    logic chunk_valid;
    logic ctrl_ready;

    logic [SEQ_W-1:0] seq_next;
    ucie_flit_t new_flit;

    ucie_flit_t phy_flit_chann_out;
    logic phy_valid_chann_out;

    logic rx_sop;
    logic rx_eop;
    logic [PAYLOAD_W-1:0] payload_out;
    logic payload_valid;

    logic rx_ack;
    logic [SEQ_W-1:0] rx_ack_seq;
    logic rx_nack,
    logic [SEQ_W-1:0] rx_nack_seq;
    logic rx_credit_return;

    logic rx_ack_chann;
    logic [SEQ_W-1:0] rx_ack_seq_chann;
    logic rx_nack_chann,
    logic [SEQ_W-1:0] rx_nack_seq_chann;
    logic rx_credit_return_chann;

    logic link_init;
    logic link_active;
    // logic mb_locked;


    ucie_link_fsm fsm (
        //--- General ---
        .clk(clk),
        .rst_n(rst_n),

        //--- rx ---
        .mb_locked(mb_locked),

        //--- tx ctrl ---
        input logic nack_storm,

        //--- status ---
        .link_init(link_init),
        .link_active(link_active)
    );


    ucie_tx_packetizer tx_packetizer (
        //--- Genral ---
        .clk(clk),
        .rst_n(rst_n),

        //--- status ---
        .link_active(link_active),

        //--- protocol layer ---
        .txn_payload(txn_payload),
        .txn_len(txn_len),
        .txn_valid(txn_valid),
        .txn_reday(txn_ready),

        //--- chunk data ---
        .sop(sop),
        .eop(eop),
        .chunk_data(chunk_data),
        .chunk_valid(chunk_valid),

        //--- ctrl ---
        .ctrl_ready(ctrl_ready)
    );


    uice_tx_framer tx_framer (
        //--- General ----
        .clk(clk),
        .rst_n(rst_n),

        //--- slicer ---
        .sop(sop),
        .eop(eop),
        .txn_payload(chunk_data),

        //--- ctrl ---
        .seq_next(seq_next),

        //--- flit ---
        .flit_out(new_flit)
    );


    ucie_tx_ctrl #(
        .REPLAY_BUFF_W(REPLAY_BUFF_W)
        .CNT_W(CNT_W)
    ) tx_ctrl (
        //--- General ---
        .clk(clk),
        .rst_n(rst_n),

        //--- protocol layer ---
        .txn_valid(chunk_valid),
        .txn_ready(ctrl_ready),

        //--- rx ---
        .ack(rx_ack_chann),
        .ack_seq(rx_ack_seq_chann),
        .nack(rx_nack_chann),
        .nack_seq(rx_nack_seq_chann),
        .credit_return(rx_credit_return_chann),

        //--- tx framer ---
        .seq_next(seq_next),
        .new_flit(new_flit),

        //--- phy ---
        .phy_flit(phy_flit),
        .phy_valid(phy_valid),

        //--- status ---
        // .link_init(link_init), // Todo: 
        .link_active(link_active),
        .nack_stor(nack_storm)
    );


    ucie_rx_ckeck rx_check (
        //--- General --
        .clk(clk),
        .rst_n(rst_n),

        //--- link status ---
        // .link_init(link_init), // Todo: 
        .link_active(link_active),

        //--- tx side ---
        .flit_in(phy_flit_chann_out),
        .flit_valid(phy_valid_chann_out),

        //--- status ---
        // .mb_locked(mb_locked), // Todo: 

        //--- output ---
        .sop(rx_sop),
        .eop(rx_eop),
        .payload_out(payload_out),
        .payload_valid(payload_valid),
        .ack(rx_ack),
        .ack_seq(rx_ack_seq),
        .nack(rx_nack),
        .nack_seq(rx_nack_seq),
        .credit_return(rx_credit_return)
    );


    ucie_rx_deframer rx_deframer (
        //--- Genral ---
        .clk(clk),
        .rst_n(rst_n),

        //--- rx ---
        .sop(rx_sop),
        .eop(rx_eop),
        .payload_out(payload_out),
        .payload_valid(payload_valid),

        //--- output ---
        .txn_data(pkt_data),
        .txn_len(pkt_len),
        .txn_valid(pkt_valid),

        //--- status ---
        .pkt_error(pkt_error)
    );


    ucie_chann #(
        .TX_CH_DELAY(TX_CH_DELAY),
        .RX_CH_DELAY(RX_CH_DELAY)
    ) phy_chann (
        //--- General ---
        .clk(clk),
        .rst_n(rst_n),

        //--- transmiter phy ---
        .phy_flit_in(phy_flit),
        .phy_valid_in(phy_valid),
        
        .phy_flit_out(phy_flit_chann_out),
        .phy_valid_out(phy_valid_chann_out),

        //--- receiver phy ---
        .ack_in(rx_ack),
        .ack_seq_in(rx_ack_seq),
        .nack_in(rx_nack),
        .nack_seq_in(rx_nack_seq),
        .credit_return_in(rx_credit_return),

        .ack_out(rx_ack_chann),
        .ack_seq_out(rx_ack_seq_chann),
        .nack_out(rx_nack_chann),
        .nack_seq_out(rx_nack_seq_chann),
        .credit_return_out(rx_credit_return_chann),

        //--- crtl ---
        .corrupt_en(corrupt_en)
    );

endmodule
