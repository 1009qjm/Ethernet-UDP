`timescale  1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Author: qjm
// Create Date: 2024/11/07
// Module Name: tb_send_receive
// Project Name: ethernet udp
//
// Revision:V1.1
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////

module  tb_send_receive();
//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
parameter  BOARD_MAC = 48'h12_34_56_78_9A_BC;
parameter  BOARD_IP  = {8'd169,8'd254,8'd1,8'd23};
parameter  DES_MAC   = 48'h1C_2B_3A_49_58_67;
parameter  DES_IP    = {8'd169,8'd254,8'd191,8'd31};
//
logic            eth_tx_clk      ;
logic            eth_rx_clk      ;
logic            clk_50m         ;
logic            sys_rst_n       ;
logic            send_en         ;   //send start flag
logic    [31:0]  send_data       ;
logic    [31:0]  data_mem [2:0]  ;
logic    [15:0]  cnt_data        ;
//
logic            send_end        ;   //send finished flag 
logic            read_data_req   ;   //read FIFO enable
logic            eth_tx_en       ;
logic    [3:0]   eth_tx_data     ;
logic            eth_rxdv        ;
logic    [3:0]   eth_rx_data     ;
logic            crc_en          ;   //CRC enable
logic            crc_clr         ;   //CRC reset
logic    [31:0]  crc_data        ;
logic    [31:0]  crc_next        ;
//
logic            rec_en          ;
logic    [31:0]  rec_data        ;
logic            rec_end         ;
logic    [15:0]  rec_data_num    ;
//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//
assign eth_rx_data = eth_tx_data;
assign eth_rxdv = eth_tx_en;
//
initial begin
    eth_tx_clk = 1'b1;
    eth_rx_clk = 1'b1;
    clk_50m    = 1'b1;
    sys_rst_n <= 1'b0;
    send_en   <= 1'b0;
    #200
    sys_rst_n <= 1'b1;
    #100
    send_en   <= 1'b1;
    #50
    send_en   <= 1'b0;
end

always  #20 eth_rx_clk = ~eth_rx_clk;
always  #20 eth_tx_clk = ~eth_tx_clk;
always  #10 clk_50m = ~clk_50m;
//
always_ff@(posedge eth_tx_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        data_mem[0] <= 32'h00_00_00_00;
        data_mem[1] <= 32'h00_00_00_00;
        data_mem[2] <= 32'h00_00_00_00;
    end
    else begin
        data_mem[0] <= 32'h68_74_74_70;
        data_mem[1] <= 32'h3a_2f_2f_77;
        data_mem[2] <= 32'h77_77_00_00;
    end
end
//cnt_data
always_ff@(posedge eth_tx_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        cnt_data <= 8'd0;
    end
    else if(read_data_req == 1'b1) begin
        cnt_data <= cnt_data + 1'b1;
    end
    else begin
        cnt_data <= cnt_data;
    end
end
//send_data
always_ff@(posedge eth_tx_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_data <= 32'h0;
    end
    else if(read_data_req == 1'b1) begin
        send_data <= data_mem[cnt_data];
    end
end
//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- inst -------------
my_ip_send #(
    .BOARD_MAC      (BOARD_MAC      ),
    .BOARD_IP       (BOARD_IP       ),
    .DES_MAC        (DES_MAC        ),
    .DES_IP         (DES_IP         )
) ip_send_inst
(
    .sys_clk        (eth_tx_clk     ),
    .sys_rst_n      (sys_rst_n      ),
    .send_en        (send_en        ),  //send start flag
    .send_data      (send_data      ),  //send data
    .send_data_num  (16'd10         ),  //send data num(byte)
    .crc_data       (crc_data       ),
    .crc_next       (crc_next[31:28]),

    .send_end       (send_end       ),  //send finish flag
    .read_data_req  (read_data_req  ),  //read FIFO enable
    .eth_tx_en      (eth_tx_en      ),
    .eth_tx_data    (eth_tx_data    ),
    .crc_en         (crc_en         ),
    .crc_clr        (crc_clr        )   //crc reset
);
//------------ crc32_d4_inst -------------
crc32_d4 crc32_d4_inst
(
    .sys_clk        (eth_tx_clk     ),
    .sys_rst_n      (sys_rst_n      ),
    .data           (eth_tx_data    ),
    .crc_en         (crc_en         ),  //crc使能
    .crc_clr        (crc_clr        ),  //crc reset

    .crc_data       (crc_data       ),
    .crc_next       (crc_next       )
);
//
my_ip_receive #(
    .BOARD_MAC      (DES_MAC      ),
    .BOARD_IP       (DES_IP       )
) ip_receive_inst
(
    .sys_clk        (eth_rx_clk     ),
    .sys_rst_n      (sys_rst_n      ),
    .eth_rxdv       (eth_rxdv       ),
    .eth_rx_data    (eth_rx_data    ),

    .rec_end        (rec_end        ),
    .rec_data_en    (rec_en         ),
    .rec_data       (rec_data       ),
    .rec_data_num   (rec_data_num   )
);

endmodule
