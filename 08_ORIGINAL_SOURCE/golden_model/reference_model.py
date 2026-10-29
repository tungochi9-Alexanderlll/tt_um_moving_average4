def moving_average4(samples):
    out = []
    window = []
    for x in samples:
        if not 0 <= x <= 255:
            raise ValueError("reference model expects 8-bit unsigned samples")
        window.append(x)
        if len(window) < 4:
            out.append((False, None))
        else:
            if len(window) > 4:
                window.pop(0)
            out.append((True, sum(window) // 4))
    return out

def rolling_check(samples):
    buf = [0, 0, 0, 0]
    ptr = 0
    count = 0
    total = 0
    out = []
    for x in samples:
        oldest = buf[ptr]
        if count < 4:
            total += x
            count += 1
        else:
            total += x - oldest
        buf[ptr] = x
        ptr = (ptr + 1) % 4
        out.append((count >= 4, total // 4 if count >= 4 else None))
    return out

def test_constant():
    assert moving_average4([10,10,10,10,10]) == [
        (False,None),(False,None),(False,None),(True,10),(True,10)]

def test_ramp():
    assert moving_average4([0,4,8,12,16]) == [
        (False,None),(False,None),(False,None),(True,6),(True,10)]

def test_impulse():
    assert moving_average4([0,0,0,255,0,0]) == [
        (False,None),(False,None),(False,None),(True,63),(True,63),(True,63)]

def test_bounds():
    assert moving_average4([255,255,255,255])[-1] == (True,255)
    assert moving_average4([0,0,0,0])[-1] == (True,0)

def test_equivalence():
    samples=[3,17,2,200,31,44,255,1,9,128]
    assert moving_average4(samples) == rolling_check(samples)

if __name__ == "__main__":
    test_constant()
    test_ramp()
    test_impulse()
    test_bounds()
    test_equivalence()
    print("G01 golden reference PASS")
