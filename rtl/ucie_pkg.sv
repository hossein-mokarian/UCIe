
package ucie_pkg;
    
    parameter int PAYLOAD_W         = 64;
    parameter int SEQ_W             = 8;
    parameter int CRC_w             = 16;
    parameter int CREDIT_INIT       = 10;
    parameter int NACK_STORM_THRESH = 5;

    typedef struct packed {
        logic [SEQ_W - 1 : 0] seq;
        logic sop;
        logic eop;
        logic [PAYLOAD_W - 1 : 0] payload;
        logic [CRC_w - 1 : 0] crc;
    } ucie_flit_t;

    function automatic logic [CRC_w - 1 : 0] crc_calc(logic [SEQ_W + 2 + PAYLOAD_W - 1 : 0] d);
        logic [15:0] c = 16'hFFFF;

        for (int i = $bits(d) - 1; i >= 0; i--) begin
            logic fb = c15 ^ d[i];
            c = {c[14:0], 1'b0} ^ (fb ? 16'h1021 : 16'h0000);
        end

        return c;
    endfunction

    typedef enum logic [2 : 0] { 
        S_RESET,
        S_SBINIT,
        S_MBINIT,
        S_LINKINIT,
        S_ACTIVE,
        S_RETRAIN
    } ucie_link_state_t;

endpackage
