import ucie_pkg::*;

module tb_ucie_adaptor_v1;

    localparam int REPLAY_BUFF_W = CREDIT_INIT;
    localparam int CNT_W = 5;

    logic clk;
    logic rst_n;

    //--- protocol layer ---
    logic [PAYLOAD_W-1:0] txn_payload;
    logic txn_valid;
    logic txn_ready;

    //--- phy ---
    ucie_flit_t phy_flit;
    logic phy_valid;

    //--- status ---
    logic link_active;
    logic nack_storm;

    //--- ctrl ---
    logic corrupt_en;

    //--- outputs ---
    logic [PAYLOAD_W-1:0] payload_out;
    logic payload_valid;


    ucie_adapt0r_top_v1 #(
        .REPLAY_BUFF_W(REPLAY_BUFF_W),
        .CNT_W(CNT_W),
        .TX_CH_DELAY(TX_CH_DELAY),
        .RX_CH_DELAY(RX_CH_DELAY)
    ) dut (
        //--- General ---
        .clk(clk),
        .rst_n(rst_n),

        //--- protocol layer ---
        .txn_payload(txn_payload),
        .txn_valid(txn_valid),
        .txn_ready(txn_ready),

        //--- phy ---
        .phy_flit(phy_flit),
        .phy_valid(phy_valid),

        //--- status ---
        .mb_locked(mb_locked),
        .nack_storm(nack_storm),

        //--- channel --- 
        .corrupted_en(corrupt_en),

        //--- outputs ---
        .payload_out(payload_out),
        .payload_valid(payload_valid)
    );

    
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        
        rst_n = 1'b0;
        mb_locked = 1'b0;
        corrupt_en = 1'b0;
        txn_payload = '0;
        txn_valid = 1'b0;

        //--- reset ---
        repeat(5) @(negedge clk);
        rst_n = 1'b0;

        //--- no tcn_ready when active_link is zero ---
        repeat(2) @(posedge clk);
        txn_payload = 'h55;
        txn_valid = 1'b1;
        corrupt_en = 1'b0;

        repeat (50) begin
            if (!txn_ready) @(posedge clk)
        end
        if (!txn_ready) $display("[SUCCESS] txn_ready is not one when link_active is zero.");
        else $error("[ERROR] link_active is not high but we have txn_ready!!");
        txn_valid = 1'b0;

        //--- MB Training ---
        mb_locked = 1'b0;
        while(dut.fsm.state != S_MBINIT) @(posedge clk);
        repeat(4) @(posedge clk);
        mb_locked = 1'b1;
        @(posedge clk)
        mb_locked = 1'b0;

        //--- send 1 flit without corruption ---
        repeat(2) @(posedge clk);
        txn_payload = 'h55;
        txn_valid = 1'b1;
        corrupt_en = 1'b0;

        while(!txn_ready) @(posedge clk);
        txn_valid = 1'b0;

        //--- send 1 flit with corruption ---
        repeat(2) @(posedge clk);
        txn_payload = 'h66;
        txn_valid = 1'b1;
        corrupt_en = 1'b1;

        while(!txn_ready) @(posedge clk);
        txn_valid = 1'b0;
        corrupt_en = 1'b0;

        //--- nack storm ---
        repeat(2) @(posedge clk);
        txn_payload = 'h77;
        txn_valid = 1'b1;
        corrupt_en = 1'b1;
        mb_locked = 1'b0;

        while(!txn_ready) @(posedge clk);
        txn_valid = 1'b0;

        while!(nack_storm) @(posedge clk);
        corrupt_en = 1'b0;

        repeat(2)@(posedge clk)
        mb_locked = 1'b1;
        repeat(1)@(posedge clk)
        mb_locked = 1'b0;

        //--- back pressure ----
        corrupt_en = 1'b0;
        txn_payload = 'h12;
        txn_valid = 1'b1;
        repeat(CREDIT_INIT) begin 
            txn_payload = txn_payload + 1;
            while(!txn_ready) @(posedge clk);
        end
        txn_valid = 1'b0;

    end
    
    initial begin
        $dumpfile("tb_ucie_adaptor_v1.vcd");
        $dumvars(0, tb_ucie_adaptor_v1);
    end    

endmodule
