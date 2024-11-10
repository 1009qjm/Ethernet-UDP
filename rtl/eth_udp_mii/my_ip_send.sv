`timescale  1ns/1ns
////////////////////////////////////////////////////////////////////////
// Author        : qjm
// Create Date   : 2024/11/02
// Module Name   : ip_send
// Description   : UDP data sender
// Revision      : V1.0
// Additional Comments:
////////////////////////////////////////////////////////////////////////

module my_ip_send
#(
    parameter   BOARD_MAC   = 48'hFF_FF_FF_FF_FF_FF ,   //板卡MAC地址
    parameter   BOARD_IP    = 32'hFF_FF_FF_FF       ,   //板卡IP地址
    parameter   BOARD_PORT  = 16'd1234              ,   //板卡端口号
    parameter   PC_MAC      = 48'hFF_FF_FF_FF_FF_FF ,   //PC机MAC地址
    parameter   PC_IP       = 32'hFF_FF_FF_FF       ,   //PC机IP地址
    parameter   PC_PORT     = 16'd1234                  //PC机端口号
)
(
    input   logic            sys_clk         ,
    input   logic            sys_rst_n       ,
    input   logic            send_en         ,   //send start
    input   logic    [31:0]  send_data       ,
    input   logic    [15:0]  send_data_num   ,
    input   logic    [31:0]  crc_data        ,
    input   logic    [3:0]   crc_next        ,

    output  logic            send_end        ,   //send end flag
    output  logic            read_data_req   ,   //read FIFO req
    output  logic            eth_tx_en       ,
    output  logic    [3:0]   eth_tx_data     ,
    output  logic            crc_en          ,
    output  logic            crc_clr
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
typedef enum {
    IDLE,
    CHECK_SUM,
    PACKET_HEAD,
    ETH_HEAD,
    IP_UDP_HEAD,
    SEND_DATA,
    CRC
} state_t;

localparam ETH_TYPE = 16'h0800    ;    //协议类型 IP协议
//
logic             rise_send_en    ;
logic     [15:0]  send_data_len   ;   //send data length after padding
//
logic             send_en_dly     ;
logic     [7:0]   packet_head[7:0];   //7+1=8 Bytes
logic     [7:0]   eth_head[13:0]  ;   //eth head
logic     [31:0]  ip_udp_head[6:0];   //IP head + UDP head
logic     [31:0]  check_sum       ;   //IP head check_sum
logic     [15:0]  data_len        ;   //valid data length
logic     [15:0]  ip_len          ;   //IP length
logic     [15:0]  udp_len         ;   //UDP length
//fsm
state_t           state,nxt_state ;
logic             check_sum_end   ;
logic             packet_end      ;
logic             eth_head_end    ;
logic             ip_udp_head_end ;
logic             send_data_end   ;
logic             crc_end         ;
logic             idle_end        ;
//cnt
logic     [4:0]   cnt_byte        ;   //counter
logic     [2:0]   cnt_4bit        ;   //count in 4bit
//
logic     [15:0]  data_cnt        ;   //count in byte(s)

//****************************************************************//
//*************************** Main Code **************************//
//****************************************************************//

//send_en_dly
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_en_dly <= 1'b0;
    end
    else begin
        send_en_dly <= send_en;
    end
end
//rise_send_en
assign rise_send_en = ((send_en == 1'b1) && (send_en_dly == 1'b0)) ? 1'b1 : 1'b0;
//packet_head
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        packet_head[0]  <=  8'h00;
        packet_head[1]  <=  8'h00;
        packet_head[2]  <=  8'h00;
        packet_head[3]  <=  8'h00;
        packet_head[4]  <=  8'h00;
        packet_head[5]  <=  8'h00;
        packet_head[6]  <=  8'h00;
        packet_head[7]  <=  8'h00;
    end
    else begin
        packet_head[0]  <=  8'h55;
        packet_head[1]  <=  8'h55;
        packet_head[2]  <=  8'h55;
        packet_head[3]  <=  8'h55;
        packet_head[4]  <=  8'h55;
        packet_head[5]  <=  8'h55;
        packet_head[6]  <=  8'h55;
        packet_head[7]  <=  8'hd5;
    end
end
//eth_head:6+6+2=14byte
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        eth_head[0]     <=  8'h00;
        eth_head[1]     <=  8'h00;
        eth_head[2]     <=  8'h00;
        eth_head[3]     <=  8'h00;
        eth_head[4]     <=  8'h00;
        eth_head[5]     <=  8'h00;
        eth_head[6]     <=  8'h00;
        eth_head[7]     <=  8'h00;
        eth_head[8]     <=  8'h00;
        eth_head[9]     <=  8'h00;
        eth_head[10]    <=  8'h00;
        eth_head[11]    <=  8'h00;
        eth_head[12]    <=  8'h00;
        eth_head[13]    <=  8'h00;
    end
    else begin
        eth_head[0]     <=  PC_MAC[47:40]   ;                //dest mac
        eth_head[1]     <=  PC_MAC[39:32]   ;
        eth_head[2]     <=  PC_MAC[31:24]   ;
        eth_head[3]     <=  PC_MAC[23:16]   ;
        eth_head[4]     <=  PC_MAC[15:8]    ;
        eth_head[5]     <=  PC_MAC[7:0]     ;
        eth_head[6]     <=  BOARD_MAC[47:40];                //src mac
        eth_head[7]     <=  BOARD_MAC[39:32];
        eth_head[8]     <=  BOARD_MAC[31:24];
        eth_head[9]     <=  BOARD_MAC[23:16];
        eth_head[10]    <=  BOARD_MAC[15:8] ;
        eth_head[11]    <=  BOARD_MAC[7:0]  ;
        eth_head[12]    <=  ETH_TYPE[15:8]  ;                //type
        eth_head[13]    <=  ETH_TYPE[7:0]   ;
    end
end
//ip_udp_head
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        ip_udp_head[1][31:16] <= 16'd0;
    end
    else if((state == IDLE) && (idle_end)) begin
        ip_udp_head[0] <= {8'h45, 8'h00, ip_len};
        ip_udp_head[1][31:16] <= ip_udp_head[1][31:16] + 1'b1;
        ip_udp_head[1][15:0] <= 16'h4000;
        ip_udp_head[2] <= {8'h40,8'd17,16'h0};                                //ip_udp_head[2][15:0]: check_sum
        ip_udp_head[3] <= BOARD_IP;                                           //src  ip
        ip_udp_head[4] <= PC_IP;                                              //dest ip
        ip_udp_head[5] <= {BOARD_PORT, PC_PORT};                              //{src port, dest port}
        ip_udp_head[6] <= {udp_len, 16'h0000};                                //   
    end
    else if((state == CHECK_SUM) && (cnt_byte == 5'd3)) begin
        ip_udp_head[2][15:0] <= ~check_sum[15:0];
    end
end

//check_sum:IP head check_sum
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        check_sum <= 32'd0;
    end
    else if(state == CHECK_SUM) begin
        if(cnt_byte == 5'd0) begin
            check_sum <=  ip_udp_head[0][31:16] + ip_udp_head[0][15:0]
                        + ip_udp_head[1][31:16] + ip_udp_head[1][15:0]
                        + ip_udp_head[2][31:16] + ip_udp_head[2][15:0]
                        + ip_udp_head[3][31:16] + ip_udp_head[3][15:0]
                        + ip_udp_head[4][31:16] + ip_udp_head[4][15:0];
        end
        else if(cnt_byte == 5'd1) begin
            check_sum <= check_sum[31:16] + check_sum[15:0];
        end
        else if(cnt_byte == 5'd2) begin
            check_sum <= check_sum[31:16] + check_sum[15:0];
        end
        else begin
            check_sum <= check_sum;
        end
    end
    else begin
        check_sum <= check_sum;
    end
end
//data_len
//ip_len
//udp_len
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        data_len <= 16'd0;
        ip_len   <= 16'd0;
        udp_len  <= 16'd0;
    end
    else if((rise_send_en == 1'b1) && (state == IDLE)) begin
        data_len <= send_data_num;
        ip_len   <= send_data_num + 16'd28;
        udp_len  <= send_data_num + 16'd8;
    end
end
//send_data_len = data byte count after padding
//46Byte(min length) - 20Byte(ip head) - 8Byte(udp head) = 18Byte
assign  send_data_len = (data_len >= 16'd18) ? data_len : 16'd18;          //data_len after padding

//state change
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= nxt_state;
    end
end
//nxt_state
always_comb begin
    case(state)
        IDLE: if(idle_end) 
                  nxt_state = CHECK_SUM;
              else 
                  nxt_state = IDLE;
        CHECK_SUM: if(check_sum_end) 
                       nxt_state = PACKET_HEAD;
                   else 
                       nxt_state = CHECK_SUM;
        PACKET_HEAD: if(packet_end) begin
                         nxt_state = ETH_HEAD;
                     end
                     else begin
                        nxt_state = PACKET_HEAD;
                     end
        ETH_HEAD: if(eth_head_end) begin
                      nxt_state = IP_UDP_HEAD;
                  end
                  else begin
                      nxt_state = ETH_HEAD;
                  end
        IP_UDP_HEAD:if(ip_udp_head_end) begin
                        nxt_state = SEND_DATA;
                    end
                    else begin
                        nxt_state = IP_UDP_HEAD;
                    end
        SEND_DATA:if(send_data_end) begin
                      nxt_state = CRC;
                  end
                  else begin
                      nxt_state=SEND_DATA;
                  end
        CRC:if(crc_end) begin
                nxt_state = IDLE;
            end
            else begin
                nxt_state = CRC;
            end
        default:nxt_state = IDLE;
    endcase
end
//cnt_byte
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        cnt_byte <= 5'd0;
    end
    else begin
        case(state)
            IDLE: cnt_byte <= 5'd0;
            CHECK_SUM: cnt_byte <= (cnt_byte == 5'd3) ? '0 : cnt_byte + 1'b1;
            PACKET_HEAD: if(cnt_4bit == 3'b1) begin                              //8 Byte
                             if(cnt_byte == 5'd7) begin
                                cnt_byte <= 5'd0;
                             end
                             else begin
                                cnt_byte <= cnt_byte + 1'b1;
                             end
                         end
            ETH_HEAD: if(cnt_4bit == 3'd1) begin                                 //14 Byte
                          if(cnt_byte == 5'd13) begin
                            cnt_byte <= 5'd0;
                          end
                          else begin
                            cnt_byte <= cnt_byte + 1'b1;
                          end
                      end
            IP_UDP_HEAD: if(cnt_4bit == 3'd7) begin                             //28 Byte = 7*4
                             if(cnt_byte == 5'd6) begin
                                cnt_byte <= 5'd0;
                             end
                             else begin
                                cnt_byte <= cnt_byte + 1'b1;
                             end
                         end
            SEND_DATA: cnt_byte <= cnt_byte;
            CRC: cnt_byte <= cnt_byte;
        endcase
    end
end
//cnt_4bit
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        cnt_4bit <= 3'd0;
    end
    else begin
        case(state)
            IDLE: cnt_4bit        <= 3'd0;
            CHECK_SUM: cnt_4bit   <= 3'd0;
            PACKET_HEAD: cnt_4bit <= (cnt_4bit == 3'd1) ? 3'd0 : cnt_4bit + 1'b1;
            ETH_HEAD: cnt_4bit    <= (cnt_4bit == 3'd1) ? 3'd0 : cnt_4bit + 1'b1;
            IP_UDP_HEAD: cnt_4bit <= (cnt_4bit == 3'd7) ? 3'd0 : cnt_4bit + 1'b1;
            SEND_DATA: cnt_4bit   <= (send_data_end == 1'b1) ? 3'd0 : ((cnt_4bit == 3'd7) ? 3'd0 : cnt_4bit + 1'b1);
            CRC: cnt_4bit         <= (cnt_4bit == 3'd7) ? 3'd0 : cnt_4bit + 1'b1;
            default: cnt_4bit     <= 3'd0;
        endcase
    end
end
//***_end
//assign idle_end        = rise_send_en;
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(~sys_rst_n) begin
        idle_end <= 1'b0;
    end
    else begin
        idle_end <= rise_send_en;
    end
end
assign check_sum_end   = (state == CHECK_SUM) && (cnt_byte == 5'd3);
assign packet_end      = (state == PACKET_HEAD) && (cnt_byte == 5'd7) && (cnt_4bit == 3'd1);
assign eth_head_end    = (state == ETH_HEAD) && (cnt_byte == 5'd13) && (cnt_4bit == 3'd1);
assign ip_udp_head_end = (state == IP_UDP_HEAD) && (cnt_byte == 5'd6) && (cnt_4bit == 3'd7);             //7*8*4 = 32bit*7 = 28Byte 
assign send_data_end   = (state == SEND_DATA) && (data_cnt == send_data_len - 1'b1) && (cnt_4bit[0] == 1'b1);
assign crc_end         = (state == CRC) && (cnt_4bit == 3'd7);
//read_data_req: read fifo enable
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        read_data_req <= 1'b0;
    end
    else if((state == IP_UDP_HEAD) && (cnt_4bit == 3'd6) && (cnt_byte == 5'd6) && (data_len != 16'd0)) begin          //7 * 4Byte
        read_data_req <= 1'b1;
    end
    else if((state == SEND_DATA) && (cnt_4bit == 3'd6) && (data_cnt + 16'd1 < data_len)) begin
        read_data_req <= 1'b1;
    end
    else begin
        read_data_req <= 1'b0;
    end
end
//eth_tx_en
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        eth_tx_en <= 1'b0;
    end
    else if((state != IDLE) && (state != CHECK_SUM)) begin
        eth_tx_en <= 1'b1;
    end
    else begin
        eth_tx_en <= 1'b0;
    end
end
//eth_tx_data
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        eth_tx_data <= 4'b0;
    end
    else if(state == PACKET_HEAD) begin
        if(cnt_4bit == 3'd0) begin                  //sned low 4bit
            eth_tx_data <= packet_head[cnt_byte][3:0];
        end
        else begin
            eth_tx_data <= packet_head[cnt_byte][7:4];
        end
    end
    else if(state == ETH_HEAD) begin
        if(cnt_4bit == 3'd0) begin
            eth_tx_data <= eth_head[cnt_byte][3:0];
        end
        else begin
            eth_tx_data <= eth_head[cnt_byte][7:4];
        end
    end
    else if(state == IP_UDP_HEAD) begin
        if(cnt_4bit == 3'd0) begin
            eth_tx_data <= ip_udp_head[cnt_byte][27:24];
        end
        else if(cnt_4bit == 3'd1) begin
            eth_tx_data <= ip_udp_head[cnt_byte][31:28];
        end
        else if(cnt_4bit == 3'd2) begin
            eth_tx_data <= ip_udp_head[cnt_byte][19:16];
        end
        else if(cnt_4bit == 3'd3) begin
            eth_tx_data <= ip_udp_head[cnt_byte][23:20];
        end
        else if(cnt_4bit == 3'd4) begin
            eth_tx_data <= ip_udp_head[cnt_byte][11:8];
        end
        else if(cnt_4bit == 3'd5) begin
            eth_tx_data <= ip_udp_head[cnt_byte][15:12];
        end
        else if(cnt_4bit == 3'd6) begin
            eth_tx_data <= ip_udp_head[cnt_byte][3:0];
        end
        else if(cnt_4bit == 3'd7) begin
            eth_tx_data <= ip_udp_head[cnt_byte][7:4];
        end
        else begin
            eth_tx_data <= eth_tx_data;
        end
    end
    else if(state == SEND_DATA) begin
        if(cnt_4bit == 3'd0) begin
            eth_tx_data <= send_data[27:24];
        end
        else if(cnt_4bit == 3'd1) begin
            eth_tx_data <= send_data[31:28];
        end
        else if(cnt_4bit == 3'd2) begin
            eth_tx_data <= send_data[19:16];
        end
        else if(cnt_4bit == 3'd3) begin
            eth_tx_data <= send_data[23:20];
        end
        else if(cnt_4bit == 3'd4) begin
            eth_tx_data <= send_data[11:8];
        end
        else if(cnt_4bit == 3'd5) begin
            eth_tx_data <= send_data[15:12];
        end
        else if(cnt_4bit == 3'd6) begin
            eth_tx_data <= send_data[3:0];
        end
        else if(cnt_4bit == 3'd7) begin
            eth_tx_data <= send_data[7:4];
        end
        else begin
            eth_tx_data <= eth_tx_data;
        end
    end
    else if(state == CRC) begin
        if(cnt_4bit == 3'd0) begin
            eth_tx_data <= {~crc_next[0], ~crc_next[1], ~crc_next[2], ~crc_next[3]};
        end
        else if(cnt_4bit == 3'd1) begin
            eth_tx_data <= {~crc_data[24],~crc_data[25],~crc_data[26],~crc_data[27]};
        end
        else if(cnt_4bit == 3'd2) begin
            eth_tx_data <= {~crc_data[20],~crc_data[21],~crc_data[22],~crc_data[23]};
        end
        else if(cnt_4bit == 3'd3) begin
            eth_tx_data <= {~crc_data[16],~crc_data[17],~crc_data[18],~crc_data[19]};
        end
        else if(cnt_4bit == 3'd4) begin
            eth_tx_data <= {~crc_data[12],~crc_data[13],~crc_data[14],~crc_data[15]};
        end
        else if(cnt_4bit == 3'd5) begin
            eth_tx_data <= {~crc_data[8],~crc_data[9],~crc_data[10],~crc_data[11]};
        end
        else if(cnt_4bit == 3'd6) begin
            eth_tx_data <= {~crc_data[4],~crc_data[5],~crc_data[6],~crc_data[7]};
        end
        else if(cnt_4bit == 3'd7) begin
            eth_tx_data <= {~crc_data[0],~crc_data[1],~crc_data[2],~crc_data[3]};
        end
        else begin
            eth_tx_data <= eth_tx_data;
        end
    end
    else begin
        eth_tx_data <= eth_tx_data;
    end
end
//crc_en:CRC�?始校验使�?
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        crc_en <= 1'b0;
    end
    else if((state == ETH_HEAD) || (state == IP_UDP_HEAD) || (state == SEND_DATA)) begin
        crc_en <= 1'b1;
    end
    else begin
        crc_en <= 1'b0;
    end
end
//data_cnt: count by bytes
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        data_cnt <= 16'b0;
    end
    else if(state == SEND_DATA) begin
        if(send_data_end) begin
            data_cnt <= 16'd0;
        end
        else if(cnt_4bit[0] == 1'b1) begin
            if(data_cnt == send_data_len - 1'b1) begin
                data_cnt <= 16'd0;
            end
            else begin
                data_cnt <= data_cnt + 16'd1;
            end
        end
    end
    else begin
        data_cnt <= data_cnt;
    end
end
//send_end
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        send_end <= 1'b0;
    end
    else if((state == CRC) && (cnt_4bit == 3'd7)) begin
        send_end <= 1'b1;
    end
    else begin
        send_end <= 1'b0;
    end
end
//crc_clr
always_ff@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0) begin
        crc_clr <= 1'b0;
    end
    else begin
        crc_clr <= send_end;
    end
end

endmodule
