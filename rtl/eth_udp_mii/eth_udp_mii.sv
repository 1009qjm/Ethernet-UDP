`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : qjm
// Create Date   : 2024/11/02
// Module Name   : eth_udp_mii
// Project Name  : eth_udp_rmii
// Description   : UDP
// 
// Revision      : V1.0
// Additional Comments:
////////////////////////////////////////////////////////////////////////

module  eth_udp_mii
#(
    parameter   BOARD_MAC   = 48'hFF_FF_FF_FF_FF_FF ,   //板卡MAC地址
    parameter   BOARD_IP    = 32'hFF_FF_FF_FF       ,   //板卡IP地址
    parameter   BOARD_PORT  = 16'd1234              ,   //板卡端口号
    parameter   PC_MAC      = 48'hFF_FF_FF_FF_FF_FF ,   //PC机MAC地址
    parameter   PC_IP       = 32'hFF_FF_FF_FF       ,   //PC机IP地址
    parameter   PC_PORT     = 16'd1234                  //PC机端口号
)
(
    input   wire            eth_rx_clk      ,
    input   wire            sys_rst_n       ,
    input   wire            eth_rxdv        ,
    input   wire    [3:0]   eth_rx_data     ,
    input   wire            eth_tx_clk      ,
    input   wire            send_en         ,
    input   wire    [31:0]  send_data       ,
    input   wire    [15:0]  send_data_num   ,

    output  wire            send_end        ,
    output  wire            read_data_req   ,
    output  wire            rec_end         ,
    output  wire            rec_en          ,
    output  wire    [31:0]  rec_data        ,
    output  wire    [15:0]  rec_data_num    ,
    output  wire            eth_tx_en       ,
    output  wire    [3:0]   eth_tx_data     ,
    output  wire            eth_rst_n
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//wire define
wire            crc_en  ;   //CRC校验开始标志信号
wire            crc_clr ;   //CRC数据复位信号
wire    [31:0]  crc_data;   //CRC校验数据
wire    [31:0]  crc_next;   //CRC下次校验完成数据

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//eth_rst_n
assign  eth_rst_n = 1'b1;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------ ip_receive_inst -------------
ip_receive
#(
    .BOARD_MAC      (BOARD_MAC      ),  //板卡MAC地址
    .BOARD_IP       (BOARD_IP       )   //板卡IP地址
)
ip_receive_inst
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

//------------ ip_send_inst -------------
ip_send
#(
    .BOARD_MAC      (BOARD_MAC      ),  //板卡MAC地址
    .BOARD_IP       (BOARD_IP       ),  //板卡IP地址
    .BOARD_PORT     (BOARD_PORT     ),  //板卡端口号
    .PC_MAC         (PC_MAC         ),  //PC机MAC地址
    .PC_IP          (PC_IP          ),  //PC机IP地址
    .PC_PORT        (PC_PORT        )   //PC机端口号
)
ip_send_inst
(
    .sys_clk        (eth_tx_clk     ),
    .sys_rst_n      (sys_rst_n      ),
    .send_en        (send_en        ),
    .send_data      (send_data      ),
    .send_data_num  (send_data_num  ),
    .crc_data       (crc_data       ),  //CRC校验数据
    .crc_next       (crc_next[31:28]),  //CRC下次校验完成数据

    .send_end       (send_end       ),
    .read_data_req  (read_data_req  ),
    .eth_tx_en      (eth_tx_en      ),
    .eth_tx_data    (eth_tx_data    ),
    .crc_en         (crc_en         ),  //CRC开始校验使能
    .crc_clr        (crc_clr        )   //crc复位信号
);

//------------ crc32_d4_inst -------------
crc32_d4 crc32_d4_inst
(
    .sys_clk        (eth_tx_clk     ),
    .sys_rst_n      (sys_rst_n      ),
    .data           (eth_tx_data    ),  //待校验数据
    .crc_en         (crc_en         ),  //crc使能,校验开始标志
    .crc_clr        (crc_clr        ),  //crc数据复位信号

    .crc_data       (crc_data       ),  //CRC校验数据
    .crc_next       (crc_next       )   //CRC下次校验完成数据
);

endmodule
