import ucie_pkg::*;

module tb_ucie_tx;

    localparam int REPLAY_BUFF_W = CREDIT_INIT;
    localparam int CNT_W = 5;

    logic clk;
    logic rst_n;

    logic link_active; // tb
    logic [PAYLOAD_W-1:0] txn_payload; // tb
    logic txn_valid; // tb
    logic ack; // tb
    logic [SEQ_W-1:0] ack_seq; // tb
    logic nack; // tb
    logic [SEQ_W-1:0] nack_seq; // tb
    logic credit_return; // tb
    
    ucie_flit_t new_flit; // framer

    logic txn_ready; // ctrl
    logic [SEQ_W-1:0] seq_next; // ctrl
    logic nack_storm; // ctrl
    ucie_flit_t phy_flit;  // ctrl
    logic phy_valid;  // ctrl


    uice_tx_framer dut_tx_framer (
        //--- General ----
        .clk(clk),
        .rst_n(rst_n),

        //--- protocol layer ---
        .txn_payload(txn_payload),

        //--- ctrl ---
        .seq_next(seq_next),

        //--- flit ---
        .flit_out(new_flit)
    );

    ucie_tx_ctrl #(
        .REPLAY_BUFF_W(REPLAY_BUFF_W),
        .CNT_W(CNT_W)
    ) dut_tx_ctrl (
        //--- General ---
        .clk(clk),
        .rst_n(rst_n),

        //--- protocol layer ---
        .txn_valid(txn_valid),
        .txn_ready(txn_ready),

        //--- rx ---
        .ack(ack),
        .ack_seq(ack_seq),
        .nack(nack),
        .nack_seq(nack_seq),
        .credit_return(credit_return),

        //--- tx framer ---
        .seq_next(seq_next),
        .new_flit(new_flit),

        //--- phy ---
        .phy_flit(phy_flit),
        .phy_valid(phy_valid),

        //--- status ---
        .link_active(link_active),
        .nack_storm(nack_storm)

    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin

        //--- init ---
        link_active = 1'b0;
        txn_payload = '0;
        txn_valid = q'b0;
        ack = 1'b0;
        ack_seq = '0;
        nack = 1'b0;
        nack_seq = '0;
        credit_return = 1'b0;

        //--- reset ---
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;

        //--- active state ---
        repeat(2) @(posedge clk);
        link_active = 1'b1;

        //--- send 1 payload and get ack ---
        repeat(1) @(posedge clk);
        txn_payload = 'h01;
        txn_valid = 1'b1;
        while(!txn_ready) @(posedge clk);
        txn_valid = 1'b0;
        while(!phy_valid) @(posedge clk);
        repeat(4) @(posedge clk);
        ack = 1'b1;
        nack = 1'b0;
        ack_seq = phy_flit.seq;
        repeat(1) @(posedge clk);
        ack = 1'b0;

        //--- send 1 payload and get nack ---
        repeat(1) @(posedge clk);
        txn_payload = 'h02;
        txn_valid = 1'b1;
        while(!txn_ready) @(posedge clk);
        txn_valid = 1'b0;
        while(!phy_valid) @(posedge clk);
        repeat(4) @(posedge clk);
        ack = 1'b0;
        nack = 1'b1;
        nack_seq = phy_flit.seq;
        repeat(1) @(posedge clk);
        nack = 1'b0;

        //--- send many payloads ---
        repeat(5) begin
            repeat(1) @(posedge clk);
            txn_payload = txn_payload + 1;
            txn_valid = 1'b1;
            while(!txn_ready) @(posedge clk);
            txn_valid = 1'b0;
            while(!phy_valid) @(posedge clk);
            repeat(4) @(posedge clk);
            ack = 1'b1;
            nack = 1'b0;
            ack_seq = phy_flit.seq;
            repeat(1) @(posedge clk);
            ack = 1'b0;
        end

    end

    initial begin
        $dumpfile("tb_ucie_tx.vcd");
        $dumpvars(0, tb_ucie_tx);
    end

endmodule
