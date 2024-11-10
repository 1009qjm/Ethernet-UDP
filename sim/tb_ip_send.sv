`timescale  1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Author: qjm
// Create Date: 2024/11/07
// Module Name: tb_ip_send
// Project Name: ethernet
// Description: UDP协议数据接收模块
//
// Revision:V1.1
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////

module  tb_ip_send();
//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
//板卡MAC地址
parameter  BOARD_MAC = 48'h12_34_56_78_9A_BC;
//板卡IP地址
parameter  BOARD_IP  = {8'd169,8'd254,8'd1,8'd23};
//PC机MAC地址
parameter  DES_MAC   = 48'hff_ff_ff_ff_ff_ff;
//PC机IP地址
parameter  DES_IP    = {8'd169,8'd254,8'd191,8'd31};
//
logic             eth_tx_clk      ;
logic             clk_50m         ;
logic             sys_rst_n       ;
logic             send_en         ;   //send start flag
logic     [31:0]  send_data       ;   //send data
logic     [31:0]  data_mem [2:0]  ;
logic     [15:0]  cnt_data        ;
//
logic            send_end        ;   //send finished flag 
logic            read_data_req   ;   //read FIFO request
logic            eth_tx_en       ;
logic    [3:0]   eth_tx_data     ;
logic            crc_en          ;
logic            crc_clr         ;
logic    [31:0]  crc_data        ;
logic    [31:0]  crc_next        ;

logic            en              ;
logic    [1:0]   data            ;
//total receive length
localparam TOTAL_LEN = 8 + 14 + 20 + 8 + 18 + 4;              //8+14(=6+6+2)+20(ip head)+8(udp head)+18(data length after padding)+4(crc)
logic [8*TOTAL_LEN-1:0] recv_buff;
logic [31:0]            data_mem_recv [2:0];
logic                   send_end_dly;
//recv_buff
always_ff@(posedge eth_tx_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        recv_buff <= '0;
    end
    else if(eth_tx_en) begin
        recv_buff <= {eth_tx_data, recv_buff[TOTAL_LEN*8-1:4]};
    end
end
//send_end_dly
always_ff@(posedge eth_tx_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        send_end_dly <= 1'b0;
    end
    else begin
        send_end_dly <= send_end;
    end
end
//
assign data_mem_recv[0] = {<<byte {recv_buff[50*8+:32]}};                //8+14+20+8=50       byte50~byte53
assign data_mem_recv[1] = {<<byte {recv_buff[54*8+:32]}};
assign data_mem_recv[2] = {<<byte {recv_buff[58*8+:32]}};
//check
always_ff@(posedge eth_tx_clk) begin
    if(send_end_dly) begin
        for(int i = 0; i < 3; i++) begin
            if(data_mem_recv[i] != data_mem[i]) begin
                $display("test failed");
                $finish;
            end
        end
        $display("test pass");
    end
end
//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
initial begin
    eth_tx_clk  =   1'b1;
    clk_50m     =   1'b1;
    sys_rst_n   <=  1'b0;
    send_en     <=  1'b0;
    #200
    sys_rst_n   <=  1'b1;
    #100
    send_en     <=  1'b1;
    #50
    send_en     <=  1'b0;
end

always  #20 eth_tx_clk = ~eth_tx_clk;
always  #10 clk_50m = ~clk_50m;

always_ff@(posedge eth_tx_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        data_mem[0] <=  32'h00_00_00_00;
        data_mem[1] <=  32'h00_00_00_00;
        data_mem[2] <=  32'h00_00_00_00;
    end
    else begin
        data_mem[0] <=  32'h68_74_74_70;
        data_mem[1] <=  32'h3a_2f_2f_77;
        data_mem[2] <=  32'h77_77_00_00;
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
//------------ ip_send_inst -------------
my_ip_send
#(
    .BOARD_MAC      (BOARD_MAC      ),  //板卡MAC地址
    .BOARD_IP       (BOARD_IP       ),  //板卡IP地址
    .DES_MAC        (DES_MAC        ),  //PC机MAC地址
    .DES_IP         (DES_IP         )   //PC机IP地址
)
ip_send_inst
(
    .sys_clk        (eth_tx_clk     ),
    .sys_rst_n      (sys_rst_n      ),
    .send_en        (send_en        ),  //send start flag
    .send_data      (send_data      ),  //send data
    .send_data_num  (16'd10         ),  //send data num(byte)
    .crc_data       (crc_data       ),
    .crc_next       (crc_next[31:28]),

    .send_end       (send_end       ),
    .read_data_req  (read_data_req  ),
    .eth_tx_en      (eth_tx_en      ),
    .eth_tx_data    (eth_tx_data    ),
    .crc_en         (crc_en         ),
    .crc_clr        (crc_clr        )
);
//------------ crc32_d4_inst -------------
crc32_d4    crc32_d4_inst
(
    .sys_clk        (eth_tx_clk     ),
    .sys_rst_n      (sys_rst_n      ),
    .data           (eth_tx_data    ),
    .crc_en         (crc_en         ),
    .crc_clr        (crc_clr        ),

    .crc_data       (crc_data       ),
    .crc_next       (crc_next       )
);

endmodule
