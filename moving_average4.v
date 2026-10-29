
module tt_um_moving_average4 (
    input  wire [7:0] ui_in,
    output reg  [7:0] uo_out,
    input  wire [7:0] uio_in,
    output reg  [7:0] uio_out,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    reg [7:0] x0, x1, x2, x3;
    reg [2:0] count;
    reg [9:0] sum_next;

    always @(*) begin
        sum_next = {2'b00, ui_in}
                 + {2'b00, x0}
                 + {2'b00, x1}
                 + {2'b00, x2};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x0      <= 8'd0;
            x1      <= 8'd0;
            x2      <= 8'd0;
            x3      <= 8'd0;
            count   <= 3'd0;
            uo_out  <= 8'd0;
            uio_out <= 8'd0;
        end else begin
            uio_out[7:1] <= 7'b0;

            if (ena && uio_in[0]) begin
                x3 <= x2;
                x2 <= x1;
                x1 <= x0;
                x0 <= ui_in;

                if (count < 3'd4)
                    count <= count + 1'b1;

                if (count >= 3'd3) begin
                    uo_out    <= sum_next[9:2];
                    uio_out[0] <= 1'b1;
                end
            end
        end
    end

endmodule

