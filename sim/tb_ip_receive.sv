`timescale  1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// Author: qjm
// Create Date: 2024/11/07
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
//
logic             eth_rx_clk          ;
logic             eth_tx_clk          ;
logic             sys_rst_n           ;
logic             eth_rxdv            ;
logic     [3:0]   data_mem [171:0]    ;
logic     [7:0]   cnt_data            ;
logic             start_flag          ;
//
logic             rec_end             ;
logic             rec_en              ;
logic     [31:0]  rec_data            ;
logic             rec_data_num        ;
logic     [3:0]   eth_rx_data         ;
logic             err_flag            ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//
initial begin
    $readmemh("C:/Users/DELL/Desktop/60_ethernet_udp_rmii/sim/data.txt",data_mem);
end
//
logic [47:0] src_mac;
logic [47:0] dest_mac;
logic [31:0] src_ip;
logic [31:0] dest_ip;
logic [15:0] src_port;
logic [15:0] dest_port;
logic [15:0] data_len;
logic [15:0] data_cnt;
//
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
    data_len = {data_mem[49],data_mem[48], data_mem[51], data_mem[50]} - 16'd28;            //byte24~byte25
    //byte50 ~ byte{50+data_len-1}
end
//8+14+20+8=50
always_ff@(posedge eth_rx_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        data_cnt <= 16'd0;
    end
    else if(rec_en) begin
        data_cnt <= data_cnt + 16'd4;
    end
end
//
logic [31:0] ref_rec_data;
assign ref_rec_data[7:0] = {data_mem[(53+data_cnt)*2+1], data_mem[(53+data_cnt)*2]};
assign ref_rec_data[15:8] = {data_mem[(52+data_cnt)*2+1], data_mem[(52+data_cnt)*2]};
assign ref_rec_data[23:16] = {data_mem[(51+data_cnt)*2+1], data_mem[(51+data_cnt)*2]};
assign ref_rec_data[31:24] = {data_mem[(50+data_cnt)*2+1], data_mem[(50+data_cnt)*2]};
//
always_ff@(negedge eth_rx_clk) begin
    if(rec_en) begin
        if(rec_data == ref_rec_data) begin
            $display("receive right data: %h\n", rec_data);
            if(rec_end) begin
                if(err_flag) begin
                    $display("test failed\n");
                end
                else begin
                    $display("test pass\n");
                end
            end
        end
        else begin
            $display("receive wrong data: %h, expect to be %h\n", rec_data, ref_rec_data);
            $finish;
        end
    end
end
//clk and rst
initial begin
    eth_rx_clk = 1'b1;
    eth_tx_clk = 1'b1;
    sys_rst_n  <= 1'b0;
    start_flag <= 1'b0;
    #200
    sys_rst_n  <= 1'b1;
    #100
    start_flag <= 1'b1;
    #50
    start_flag <= 1'b0;
end

always  #20 eth_rx_clk = ~eth_rx_clk;
always  #20 eth_tx_clk = ~eth_tx_clk;

//eth_rxdv
always@(negedge eth_rx_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        eth_rxdv <= 1'b0;
    end
    else if(cnt_data == 171) begin
        eth_rxdv <= 1'b0;
    end
    else if(start_flag == 1'b1) begin
        eth_rxdv <= 1'b1;
    end
    else begin
        eth_rxdv <= eth_rxdv;
    end
end

//cnt_data
always@(negedge eth_rx_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        cnt_data <= 8'd0;
    end
    else if(eth_rxdv == 1'b1) begin
        cnt_data <= cnt_data + 1'b1;
    end
    else begin
        cnt_data <= cnt_data;
    end
end
//eth_rx_data
assign  eth_rx_data = (eth_rxdv == 1'b1) ? data_mem[cnt_data] : 4'b0;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- ethernet_inst -------------
my_ip_receive
#(
    .ENABLE_CHECKSUM(0              ),
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
    .rec_data_num   (rec_data_num   ),
    .err_flag       (err_flag       )
);

endmodule
