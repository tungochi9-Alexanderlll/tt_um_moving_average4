module g01_moving_average4 #(
    parameter int W = 8
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         valid_in,
    input  logic [W-1:0] sample_in,
    output logic         valid_out,
    output logic [W-1:0] avg_out
);

    localparam int SUM_W = W + 2;

    logic [W-1:0] sample_mem [0:3];
    logic [1:0] wr_ptr;
    logic [2:0] count_q;
    logic [SUM_W-1:0] sum_q;

    logic [SUM_W-1:0] sample_ext;
    logic [SUM_W-1:0] oldest_ext;
    logic [SUM_W-1:0] sum_next;

    assign sample_ext = {{(SUM_W-W){1'b0}}, sample_in};
    assign oldest_ext = {{(SUM_W-W){1'b0}}, sample_mem[wr_ptr]};

    always_comb begin
        if (count_q < 3'd4)
            sum_next = sum_q + sample_ext;
        else
            sum_next = sum_q + sample_ext - oldest_ext;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sample_mem[0] <= '0;
            sample_mem[1] <= '0;
            sample_mem[2] <= '0;
            sample_mem[3] <= '0;
            wr_ptr <= 2'd0;
            count_q <= 3'd0;
            sum_q <= '0;
            valid_out <= 1'b0;
            avg_out <= '0;
        end else begin
            valid_out <= 1'b0;

            if (valid_in) begin
                sample_mem[wr_ptr] <= sample_in;
                sum_q <= sum_next;

                if (count_q < 3'd4)
                    count_q <= count_q + 3'd1;

                wr_ptr <= wr_ptr + 2'd1;

                if (count_q >= 3'd3) begin
                    valid_out <= 1'b1;
                    avg_out <= sum_next >> 2;
                end
            end
        end
    end

endmodule
