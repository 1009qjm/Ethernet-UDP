`timescale  1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Author: fire
// Create Date: 2019/09/03
// Module Name: tb_ip_receive
// Project Name: ethernet
// Description: UDP协议数据接收模块
//
// Revision:V1.1
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////

module  tb_ip_receive();
//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
//板卡MAC地址
parameter  BOARD_MAC = 48'h12_34_56_78_9A_BC;
//板卡IP地址
parameter  BOARD_IP  = {8'd169,8'd254,8'd1,8'd23};

//reg   define
reg             eth_rx_clk          ;   //PHY芯片接收数据时钟信号
reg             eth_tx_clk          ;   //PHY芯片发�?�数据时钟信�?
reg             sys_rst_n           ;   //系统复位
reg             eth_rxdv            ;   //PHY芯片输入数据有效信号
reg     [3:0]   data_mem [171:0]    ;   //data_mem是一个存储器,相当于一个ram
reg     [7:0]   cnt_data            ;   //数据包字节计数器
reg             start_flag          ;   //数据输入�?始标志信�?

//wire define
wire            rec_end             ;   //数据接收使能信号
wire    [3:0]   rec_en              ;   //接收数据
wire            rec_data            ;   //数据包接收完成信�?
wire            rec_data_num        ;   //接收数据字节�?
wire    [3:0]   eth_rx_data         ;   //PHY芯片输入数据

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//读取sim文件夹下面的data.txt文件，并把读出的数据定义为data_mem
initial $readmemh
    ("C:/Users/DELL/Desktop/60_ethernet_udp_rmii/sim/data.txt",data_mem);

logic [47:0] src_mac;
logic [47:0] dest_mac;
logic [31:0] src_ip;
logic [31:0] dest_ip;
logic [15:0] src_port;
logic [15:0] dest_port;

initial begin
    #100
    src_mac = {data_mem[29],data_mem[28], data_mem[31],data_mem[30], data_mem[33],data_mem[32],
               data_mem[35],data_mem[34], data_mem[37],data_mem[36], data_mem[39],data_mem[38]};                //byte 14~19
    dest_mac = {data_mem[17],data_mem[16], data_mem[19],data_mem[18], data_mem[21],data_mem[20],
                data_mem[23],data_mem[22], data_mem[25],data_mem[24], data_mem[27],data_mem[26]};               //byte 8~13
    src_ip = {data_mem[69],data_mem[68], data_mem[71],data_mem[70], data_mem[73],data_mem[72], data_mem[75],data_mem[74]};              //byte34~byte37            
    dest_ip = {data_mem[77],data_mem[76], data_mem[79],data_mem[78], data_mem[81],data_mem[80], data_mem[83],data_mem[82]};             //byte38~byte41
    src_port = {data_mem[85], data_mem[84], data_mem[87], data_mem[86]};                    //byte 42~43
    dest_port = {data_mem[89], data_mem[88], data_mem[91], data_mem[90]};                   //byte 44~45
end
//clk and rst
initial
  begin
    eth_rx_clk  =   1'b1    ;
    eth_tx_clk  =   1'b1    ;
    sys_rst_n   <=  1'b0    ;
    start_flag  <=  1'b0    ;
    #200
    sys_rst_n   <=  1'b1    ;
    #100
    start_flag  <=  1'b1    ;
    #50
    start_flag  <=  1'b0    ;
  end

always  #20 eth_rx_clk = ~eth_rx_clk;
always  #20 eth_tx_clk = ~eth_tx_clk;

//eth_rxdv:PHY芯片输入数据有效信号
always@(negedge eth_rx_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        eth_rxdv    <=  1'b0;
    else    if(cnt_data == 171)
        eth_rxdv    <=  1'b0;
    else    if(start_flag == 1'b1)
        eth_rxdv    <=  1'b1;
    else
        eth_rxdv    <=  eth_rxdv;

//cnt_data:数据包字节计数器
always@(negedge eth_rx_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_data    <=  8'd0;
    else    if(eth_rxdv == 1'b1)
        cnt_data    <=  cnt_data + 1'b1;
    else
        cnt_data    <=  cnt_data;

//eth_rx_data:PHY芯片输入数据
assign  eth_rx_data = (eth_rxdv == 1'b1)
                    ? data_mem[cnt_data] : 4'b0;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- ethernet_inst -------------
my_ip_receive
#(
    .BOARD_MAC      (BOARD_MAC      ),  //板卡MAC地址
    .BOARD_IP       (BOARD_IP       )   //板卡IP地址
)
ip_receive_inst
(
    .sys_clk        (eth_rx_clk     ),  //时钟信号
    .sys_rst_n      (sys_rst_n      ),  //复位信号,低电平有�?
    .eth_rxdv       (eth_rxdv       ),  //数据有效信号
    .eth_rx_data    (eth_rx_data    ),  //输入数据

    .rec_end        (rec_end        ),  //数据接收使能信号
    .rec_data_en    (rec_en         ),  //接收数据
    .rec_data       (rec_data       ),  //数据包接收完成信�?
    .rec_data_num   (rec_data_num   )   //接收数据字节�?
);

endmodule
