`ifdef G01_SVA
assert_no_early_valid:
    assert property (@(posedge clk)
        valid_out |-> $past(valid_in,3));

assert_valid_requires_input:
    assert property (@(posedge clk)
        valid_out |-> $past(valid_in));
`endif
