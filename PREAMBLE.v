`timescale 1ns/1ps
`define CLOG2(x) ( \
    (x) <= 2 ? 1 : \
    (x) <= 4 ? 2 : \
    (x) <= 8 ? 3 : \
    (x) <= 16 ? 4 : \
    (x) <= 32 ? 5 : \
    (x) <= 64 ? 6 : \
    (x) <= 128 ? 7 : \
    (x) <= 256 ? 8 : \
    (x) <= 512 ? 9 : 10 )

module PREAMBLE #(
    parameter integer C_DATA_WIDTH = 16,
    parameter integer C_FRAME_LEN  = 10
)(
    input  wire                      clk_i,
    input  wire                      rst_i,

    // AXI-Stream in
    input  wire [C_DATA_WIDTH-1:0]   s_axis_tdata,
    input  wire                      s_axis_tvalid,
    output wire                      s_axis_tready,
    input  wire                      s_axis_tlast,

    // AXI-Stream out
    output wire [C_DATA_WIDTH-1:0]   m_axis_tdata,
    output wire                      m_axis_tvalid,
    input  wire                      m_axis_tready,
    output wire                      m_axis_tlast
);

    localparam integer              C_PREAMBLE_LEN = 16;
    localparam [C_PREAMBLE_LEN-1:0] C_PREAMBLE_PATTERN = 16'hABCD;

    localparam [1:0]
        C_IDLE          = 2'b00,    
        C_SEND_PREAMBLE = 2'b01,
        C_SEND_DATA     = 2'b11;

    reg [C_DATA_WIDTH-1:0] s_tdata_ff,  s_tdata_ff_next;
    reg                    s_tlast_ff,  s_tlast_ff_next;
    reg                    s_tvalid_ff, s_tvalid_ff_next;
    //reg                    s_tready_ff, s_tready_ff_next;
    
    reg  [1:0] state, state_next;

    reg [C_DATA_WIDTH-1:0] m_tdata_ff,  m_tdata_ff_next;
    reg                    m_tlast_ff,  m_tlast_ff_next;
    reg                    m_tvalid_ff, m_tvalid_ff_next;
    reg                    m_tready_ff, m_tready_ff_next;
    
    reg [`CLOG2(C_FRAME_LEN)-1 : 0] frame_cnt , frame_cnt_next;
    
    wire output_handshake ;
    wire input_handshake  ;

    assign input_handshake  = (s_axis_tvalid && s_axis_tready);
    assign output_handshake = (m_axis_tvalid && m_axis_tready);

    always @(*) begin
        // hold
        state_next    = state;

        s_tdata_ff_next  = s_tdata_ff;
        s_tlast_ff_next  = s_tlast_ff;
        s_tvalid_ff_next = s_tvalid_ff;
        //s_tready_ff_next = s_tready_ff;
        
        m_tdata_ff_next  = m_tdata_ff;
        m_tlast_ff_next  = m_tlast_ff;
        m_tvalid_ff_next = m_tvalid_ff;
        m_tready_ff_next = m_tready_ff;
        
        case (state)
            C_IDLE: begin
                if(input_handshake) begin
                    m_tdata_ff_next  = C_PREAMBLE_PATTERN;
                    s_tdata_ff_next  = s_axis_tdata;
                    s_tlast_ff_next  = s_axis_tlast;
                    state_next       = C_SEND_PREAMBLE;
                    m_tlast_ff_next = 1'b0;
                    m_tvalid_ff_next = 1'b1;
                end
            end
            C_SEND_PREAMBLE: begin
                if(output_handshake) begin
                    state_next = C_SEND_DATA;
                    m_tdata_ff_next = s_tdata_ff_next;
                    m_tlast_ff_next = s_tlast_ff;
                    m_tvalid_ff_next = 1'b0;
                end
            end
            C_SEND_DATA: begin
                if (m_tlast_ff) begin
                    state_next  = C_IDLE;
                    m_tvalid_ff_next = 1'b0;
                end
                else begin
                    m_tdata_ff_next  = s_axis_tdata;
                    m_tlast_ff_next  = s_axis_tlast;
                    m_tvalid_ff_next = s_axis_tvalid;
                end
            end
        endcase
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            state       <= C_IDLE;
            s_tlast_ff  <= 1'b0;
            s_tvalid_ff <= 1'b0;
            m_tlast_ff  <= 1'b0;
            m_tvalid_ff <= 1'b0;
            frame_cnt   <= 0;
        end 
        else begin
            state       <= state_next;

            s_tdata_ff  <= s_tdata_ff_next;
            s_tlast_ff  <= s_tlast_ff_next;
            s_tvalid_ff <= s_tvalid_ff_next;
            //s_tready_ff <= s_tready_ff_next;
            
            m_tdata_ff  <= m_tdata_ff_next;
            m_tlast_ff  <= m_tlast_ff_next;
            m_tvalid_ff <= m_tvalid_ff_next; 
            m_tready_ff <= m_tready_ff_next;
            
            //frame_cnt <= frame_cnt_next;
        end
    end

    assign s_axis_tready = output_handshake || (~m_tvalid_ff);
    assign m_axis_tdata  = m_tdata_ff;
    assign m_axis_tvalid = m_tvalid_ff;
    assign m_axis_tlast  = m_tlast_ff;
endmodule
