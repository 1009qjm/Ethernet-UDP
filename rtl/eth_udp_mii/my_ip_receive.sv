`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : qjm
// Create Date   : 2024/11/03
// Module Name   : ip_receive
// Project Name  : eth_udp_rmii
// Description   : UDP协议数据接收模块
// Revision      : V1.0
// Additional Comments:
////////////////////////////////////////////////////////////////////////

module my_ip_receive
#(
    parameter   ENABLE_CHECKSUM = 1,
    parameter   BOARD_MAC   = 48'h12_34_56_78_9a_bc ,   //板卡MAC地址
    parameter   BOARD_IP    = 32'hA9_FE_01_17           //板卡IP地址
)
(
    input   logic             sys_clk     ,
    input   logic             sys_rst_n   ,
    input   logic             eth_rxdv    ,
    input   logic     [3:0]   eth_rx_data ,

    output  logic             rec_data_en ,
    output  logic     [31:0]  rec_data    ,
    output  logic             rec_end     ,
    output  logic     [15:0]  rec_data_num,
    output  logic             err_flag
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
typedef enum 
{
    IDLE, 
    PACKET_HEAD, 
    ETH_HEAD, 
    IP_HEAD,
    UDP_HEAD, 
    REC_DATA, 
    REC_END
 } state_t;
//
logic     [15:0]  data_len        ;   //有效数据字节长度
logic             ip_flag         ;   //IP地址正确标志
logic             mac_flag        ;   //MAC地址正确标志
//
logic             eth_rxdv_reg    ;
logic     [3:0]   eth_rx_data_reg ;
logic             data_sw_en      ;
logic             data_en         ;
logic             data_en_dly     ;
logic     [7:0]   data            ;
//
state_t           state, nxt_state;   //
logic             err_en          ;   //错误信号
logic     [15:0]  cnt_byte        ;   //
logic     [47:0]  des_mac         ;   //
logic     [31:0]  des_ip          ;   //
logic     [5:0]   ip_head_len     ;   //20
logic     [5:0]   udp_head_len    ;   //8
logic     [15:0]  data_len        ;
logic     [15:0]  total_data_len  ;   //include padding bytes
//
logic     [47:0]  src_mac         ;
logic     [31:0]  src_ip          ;
logic     [15:0]  src_port        ;
logic     [15:0]  dst_port        ;
logic     [31:0]  check_sum       ;
//
assign ip_head_len  = 6'd20;
assign udp_head_len = 6'd8;
assign total_data_len = (data_len < 16'd18) ? 16'd18: data_len;
assign err_flag = err_en;
//state
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= nxt_state;
    end
end
//eth_rx_data_reg
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        eth_rx_data_reg <= 0;
    end
    else if(eth_rxdv) begin
        eth_rx_data_reg <= eth_rx_data;
    end
end
//
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        eth_rxdv_reg <= 1'b0;
    end
    else begin
        eth_rxdv_reg <= eth_rxdv;
    end
end
//data_sw_en
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        data_sw_en <= 1'b0;
    end
    else if(eth_rxdv) begin
        data_sw_en <= ~data_sw_en;
    end
end
//data_en
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        data_en <= 1'b0;
    end
    else if(eth_rxdv && data_sw_en) begin
        data_en <= 1'b1;
    end
    else begin
        data_en <= 1'b0;
    end
end
//data(byte)
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin 
        data <= '0;
    end
    else if(eth_rxdv && data_sw_en) begin
        data <= {eth_rx_data, eth_rx_data_reg};
    end
end
//data_en_dly
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        data_en_dly <= 1'b0;
    end
    else begin
        data_en_dly <= data_en;
    end
end
//nxt_state
always_comb begin
    case(state)
        IDLE: if(data_en && ~data_en_dly) begin
                 nxt_state = PACKET_HEAD;
              end
              else begin
                 nxt_state = IDLE;
              end
        PACKET_HEAD:if(data_en && (cnt_byte == 5'd6)) begin            //7+1=8Byte
                        nxt_state = ETH_HEAD;
                    end
                    else begin
                        nxt_state = PACKET_HEAD;
                    end
        ETH_HEAD:if(data_en && (cnt_byte == 5'd13)) begin       //6+6+2=14Byte
                     nxt_state = IP_HEAD;
                 end
                 else begin
                    nxt_state = ETH_HEAD;
                 end 
        IP_HEAD: if(data_en && (cnt_byte == ip_head_len - 1'b1)) begin        //20Byte
                     nxt_state = UDP_HEAD;
                 end
                 else begin
                    nxt_state = IP_HEAD;
                 end
        UDP_HEAD:if(data_en && (cnt_byte == udp_head_len - 1'b1)) begin        //8Byte
                    nxt_state = REC_DATA;
                 end
                 else begin
                    nxt_state = UDP_HEAD;
                 end
        REC_DATA: if(data_en && (cnt_byte == total_data_len - 1'b1)) begin           //
                      nxt_state = REC_END;
                  end
                  else begin
                      nxt_state = REC_DATA;
                  end 
        REC_END: if(data_en && (cnt_byte == 16'd3)) begin                       //4Byte
                    nxt_state = IDLE;
                 end
                 else begin
                    nxt_state = REC_END;
                 end 
        default: nxt_state = IDLE;
    endcase
end
//cnt_byte
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        cnt_byte <= 16'd0;
    end
    else if(data_en) begin
        case(state)
            IDLE: cnt_byte <= 16'd0;
            PACKET_HEAD: if(cnt_byte == 16'd6) begin
                             cnt_byte <= 16'd0;
                         end
                         else begin
                             cnt_byte <= cnt_byte + 1'b1;
                         end
            ETH_HEAD:cnt_byte <= (cnt_byte == 16'd13) ? 16'd0: cnt_byte + 1'b1;
            IP_HEAD: cnt_byte <= (cnt_byte == ip_head_len - 1) ? 16'd0 : cnt_byte + 1'b1;
            UDP_HEAD:cnt_byte <= (cnt_byte == udp_head_len - 1) ? 16'd0 : cnt_byte + 1'b1;
            REC_DATA:cnt_byte <= (cnt_byte == total_data_len - 1) ? 16'd0 : cnt_byte + 1'b1;
            REC_END: cnt_byte <= (cnt_byte == 16'd3) ? '0 : cnt_byte + 1'b1;
            default: cnt_byte <= 16'd0;
        endcase
    end
end
//check_sum
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        check_sum <= 31'd0;
    end
    else if(state == IP_HEAD && data_en) begin
        case(cnt_byte[0])
            1'b0: check_sum <= check_sum + {data, 8'h00};
            1'b1: check_sum <= check_sum + {8'h00, data};
        endcase
    end
    else if(state == UDP_HEAD && data_en) begin
        if(cnt_byte < 16'd2) begin
            check_sum <= check_sum[31:16] + check_sum[15:0];
        end
    end
end
//des_mac
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        des_mac <= 32'd0;
    end
    else if(state == ETH_HEAD && data_en) begin
        case(cnt_byte)
            16'd0 : des_mac[47:40] <= data;
            16'd1 : des_mac[39:32] <= data;
            16'd2 : des_mac[31:24] <= data;
            16'd3 : des_mac[23:16] <= data;
            16'd4 : des_mac[15:8]  <= data;
            16'd5 : des_mac[7:0]   <= data;
        endcase
    end
end
//des_ip
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        des_ip <= 32'd0;
    end
    else if((state == IP_HEAD) && data_en) begin
        case(cnt_byte)                                   //16~19byte
            16'd16: des_ip[31:24] <= data;
            16'd17: des_ip[23:16] <= data;
            16'd18: des_ip[15:8]  <= data;
            16'd19: des_ip[7:0]   <= data;
        endcase
    end
end
//ip_flag
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        ip_flag <= 1'b0;
    end
    else if((state == IP_HEAD) && data_en && (cnt_byte == ip_head_len - 1'b1)) begin
        if({des_ip[31:8], data} == BOARD_IP) begin       //dest ip match
            ip_flag <= 1'b1;
        end
        else begin
            ip_flag <= 1'b0;
        end
    end
    else begin
        ip_flag <= 1'b0;
    end
end
//mac_flag
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        mac_flag <= 1'b0;
    end
    else if((cnt_byte == 16'd13) && data_en && (state == ETH_HEAD)) begin
        if(des_mac == BOARD_MAC) begin
            mac_flag <= 1'b1;
        end
        else begin
            mac_flag <= 1'b0;
        end
    end
    else begin
        mac_flag <= 1'b0;
    end
end
//err_en
generate 
    if(ENABLE_CHECKSUM == 1) begin: gen_check_sum
        always_ff@(posedge sys_clk or negedge sys_rst_n) begin
            if(~sys_rst_n) begin
                err_en <= 1'b0;
            end
            else if((state == PACKET_HEAD) && data_en) begin
                if(cnt_byte == 16'd6) begin
                    err_en <= (data != 8'hd5);
                end
                else begin
                    err_en <= (data != 8'h55);
                end
            end
            else if((nxt_state == PACKET_HEAD) && (state == IDLE) && (data != 8'h55)) begin
                err_en <= 1'b1;
            end
            else if((state == UDP_HEAD) && (cnt_byte == 16'd2)) begin
                err_en <= (check_sum[15:0] != 16'hffff) ? 1'b1: 1'b0;
            end
        end
    end
    else begin: gen_no_check_sum
        always_ff@(posedge sys_clk or negedge sys_rst_n) begin
            if(~sys_rst_n) begin
                err_en <= 1'b0;
            end
            else if((state == PACKET_HEAD) && data_en) begin
                if(cnt_byte == 16'd6) begin
                    err_en <= (data != 8'hd5);
                end
                else begin
                    err_en <= (data != 8'h55);
                end
            end
            else if((nxt_state == PACKET_HEAD) && (state == IDLE) && (data != 8'h55)) begin
                err_en <= 1'b1;
            end
        end
    end
endgenerate
//rec_data
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        rec_data <= 32'd0;
    end
    else if(state == REC_DATA && data_en) begin
        case(cnt_byte[1:0]) 
            2'd0 : rec_data[31:24] <= data;
            2'd1 : rec_data[23:16] <= data;
            2'd2 : rec_data[15:8]  <= data;
            2'd3 : rec_data[7:0]   <= data;
        endcase
    end
end
//rec_en
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        rec_data_en <= 1'b0;
    end
    else if(data_en && (state == REC_DATA) && (cnt_byte[1:0] == 2'd3) && (cnt_byte + 1'b1 < data_len)) begin
        rec_data_en <= 1'b1;
    end
    else if(data_en && (state == REC_DATA) && (cnt_byte + 1'b1 == data_len)) begin           //if data_len % 4 != 0
        rec_data_en <= 1'b1;
    end
    else begin
        rec_data_en <= 1'b0;
    end
end
//rec_end
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        rec_end <= 1'b0;
    end
    else if((state == REC_DATA) && data_en && (cnt_byte + 1'b1 == data_len)) begin
        rec_end <= 1'b1;
    end
    else if((state == REC_DATA) && data_en && (|cnt_byte == 1'b0) && (|data_len == 1'b0)) begin
        rec_end <= 1'b1;
    end
    else begin
        rec_end <= 1'b0;
    end
end
//rec_data_num
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        rec_data_num <= '0;
    end
    else if((state == REC_DATA) && data_en && (cnt_byte + 1'b1 == data_len)) begin
        rec_data_num <= data_len;
    end
    else if((state == REC_DATA) && data_en && (|cnt_byte == 1'b0) && (|data_len == 1'b0)) begin
        rec_data_num <= data_len;
    end
end
//data_len
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        data_len <= 16'd0;
    end
    else if((state == IP_HEAD) && data_en) begin
        if(cnt_byte == 16'd2) begin
            data_len[15:8] <= data;
        end
        else if(cnt_byte == 16'd3) begin
            data_len[7:0] <= data;
        end
    end
    else if((state == UDP_HEAD) && data_en && (cnt_byte == udp_head_len - 1'b1)) begin
        data_len <= data_len - ip_head_len - udp_head_len;                         //exclude ip and udp length
    end
end
//src_mac
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        src_mac <= 48'd0;
    end
    else if(state == ETH_HEAD && (cnt_byte >= 16'd6) && (cnt_byte < 16'd12) && data_en) begin
        src_mac <= {src_mac[39:0], data};
    end
end
//src_ip
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        src_ip <= 32'd0;
    end
    else if(state == IP_HEAD && data_en && (cnt_byte >= 16'd12) && (cnt_byte < 16'd16)) begin
        src_ip <= {src_ip[23:0], data};
    end
end
//src_port
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        src_port <= 16'd0;
    end
    else if(state == UDP_HEAD && data_en && (cnt_byte < 16'd2)) begin
        src_port <= {src_port[7:0], data};
    end
end
//dst_port
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        dst_port <= 16'd0;
    end
    else if(state == UDP_HEAD && data_en && (cnt_byte >= 16'd2) && (cnt_byte < 16'd4)) begin
        dst_port <= {dst_port[7:0], data};
    end
end

endmodule
