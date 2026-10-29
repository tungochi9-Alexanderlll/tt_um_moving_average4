module g01_tb;
    logic clk, rst_n, valid_in;
    logic [7:0] sample_in;
    logic valid_out;
    logic [7:0] avg_out;

    g01_moving_average4 dut(
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .sample_in(sample_in), .valid_out(valid_out), .avg_out(avg_out)
    );

    always #5 clk = ~clk;

    task automatic send(input logic [7:0] x,
                        input logic exp_valid,
                        input logic [7:0] exp_y);
        begin
            sample_in = x;
            valid_in = 1'b1;
            @(posedge clk); #1;
            assert(valid_out == exp_valid)
                else $fatal(1,"valid mismatch");
            if (exp_valid)
                assert(avg_out == exp_y)
                    else $fatal(1,"average mismatch: got %0d expected %0d",
                                avg_out,exp_y);
            valid_in = 1'b0;
        end
    endtask

    initial begin
        clk=0; rst_n=0; valid_in=0; sample_in=0;
        repeat(2) @(posedge clk);
        rst_n=1;

        send(10,0,0);
        send(10,0,0);
        send(10,0,0);
        send(10,1,10);
        send(10,1,10);

        // cua so TRUOT tiep - moi mau deu hop le
        send(4, 1, 8);    // (10,10,10,4)  = 34  -> 8
        send(8, 1, 8);    // (10,10,4,8)   = 32  -> 8
        send(12,1, 8);    // (10,4,8,12)   = 34  -> 8
        send(16,1,10);    // (4,8,12,16)   = 40  -> 10   (chuoi tang dan, CC-3)

        send(0,  1, 9);   // (8,12,16,0)   = 36  -> 9
        send(0,  1, 7);   // (12,16,0,0)   = 28  -> 7
        send(0,  1, 4);   // (16,0,0,0)    = 16  -> 4
        send(255,1,63);   // (0,0,0,255)   = 255 -> 63   (xung don, CC-2)
        send(0,  1,63);   // (0,0,255,0)   = 255 -> 63
        send(0,  1,63);   // (0,255,0,0)   = 255 -> 63
        send(0,  1,63);   // (255,0,0,0)   = 255 -> 63   <- SUA: cua so van con 255
        send(0,  1, 0);   // (0,0,0,0)     = 0   -> 0    <- THEM mau de xung roi han

        valid_in=0;
        @(posedge clk); #1;
        assert(!valid_out) else $fatal(1,"valid gap generated output");

        $display("G01 TB completed");
        $finish;
    end
endmodule
