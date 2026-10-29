for w in range(1,65):
    max_sum = 4*((1 << w)-1)
    assert max_sum < (1 << (w+2))
print("G01 accumulator-width proof PASS for W=1..64")
