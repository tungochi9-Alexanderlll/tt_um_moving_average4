module g01_direct_sum_reference #(
    parameter int W = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [W-1:0] sample_in,
    output logic valid_out,
    output logic [W-1:0] avg_out
);
    logic [W-1:0] mem [0:3];
    logic [1:0] ptr;
    logic [2:0] count;
    logic [W+1:0] total_next;

    always_comb begin
        total_next = {2'b0,mem[0]} + {2'b0,mem[1]}
                   + {2'b0,mem[2]} + {2'b0,mem[3]};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mem[0] <= '0;
            mem[1] <= '0;
            mem[2] <= '0;
            mem[3] <= '0;
            ptr <= '0;
            count <= '0;
            valid_out <= 1'b0;
            avg_out <= '0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in) begin
                mem[ptr] <= sample_in;
                ptr <= ptr + 2'd1;
                if (count < 3'd4)
                    count <= count + 3'd1;
                if (count >= 3'd3) begin
                    valid_out <= 1'b1;
                    avg_out <= (total_next + {{(W+1){1'b0}},sample_in}
                                - {{(W+1){1'b0}},mem[ptr]}) >> 2;
                end
            end
        end
    end
endmodule
