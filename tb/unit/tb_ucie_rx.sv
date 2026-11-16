import ucie_pkg::*;

module tb_ucie_rx;

    logic clk;
    logic rst_n;

    logic link_active; // tb
    ucie_flit_t flit_in; // tb
    logic flit_valid; // tb

    logic [PAYLOAD_W-1:0] payload_out; // dut
    logic payload_valid; // dut
    logic ack; // dut
    logic [SEQ_W-1:0] ack_seq; // dut
    logic nack; // dut
    logic [SEQ_W-1:0] nack_seq; // dut
    logic credit_return; // dut


    ucie_rx_ckeck dut (
        //--- General --
        .clk(clk),
        .rst_n(rst_n),

        //--- link status ---
        .link_active(link_active),

        //--- tx side ---
        .flit_in(flit_in),
        .flit_valid(flit_valid),

        //--- output ---
        .payload_out(payload_out),
        .payload_valid(payload_valid),
        .ack(ack),
        .ack_seq(ack_seq),
        .nack(nack),
        .nack_seq(nack_seq),
        .credit_return(credit_return)
    );


    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        //--- init ---
        link_active = 1'b0;
        flit_in = '0;
        flit_valid = 1'b0;

        //--- reset ---
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;

        //--- active state ---
        repeat(2) @(posedge clk);
        link_active = 1'b1;

        //--- flit with correct crc ---
        flit_valid = 1'b0;
        repeat(2) @(posedge clk);
        flit_in.seq = 1;
        flit_in.sop = 1'b1;
        flit_in.eop = 1'b1;
        flit_in.payload = 'h22;
        flit_in.crc = calc_crc16_f({flit_in.seq, flit_in.sop, flit_in.eop, flit_in.payload});
        flit_valid = 1'b1;
        while(!ack) @(posedge clk); // Todo: Define a wait task with a timeout
        if (payload_out != flit_in.payload) begin
            $error("payload_out is not correct.");
        end else begin
            $$display("Rx module gets the right payload value.");
        end

        //--- flit with wrong crc ---
        flit_valid = 1'b0;
        repeat(2) @(posedge clk);
        flit_in.seq = 2;
        flit_in.sop = 1'b1;
        flit_in.eop = 1'b1;
        flit_in.payload = 'h33;
        flit_in.crc = calc_crc16_f({flit_in.seq, flit_in.sop, flit_in.eop, flit_in.payload}) >> 1;
        flit_valid = 1'b1;
        while(!nack) @(posedge clk); // Todo: Define a wait task with a timeout
        if (nack) $display("Rx returns nack for wrong crc.");
        else $error("Rx does not generate nack siganal.");

        if (nack_seq == flit_in.seq) $display("nack_seq is correct.");
        else $error("nack_seq is not correct.");

    end

    initial begin
        $dumpfile("tb_ucie_rx.vcd");
        $dumvars(0, tb_ucie_tx);
    end

endmodule
