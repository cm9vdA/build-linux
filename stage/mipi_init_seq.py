# -*- coding: utf-8 -*-


def pad8(s):
    return s.rjust(8, "0")


def parse_mipi_seq(s: str):
    idx = 0
    total_len = len(s)
    while idx < total_len:
        if idx + 2 > total_len:
            remain = s[idx:]
            print(f"[剩余未处理] {remain.upper()}")
            break
        cmd = s[idx : idx + 2].upper()
        idx += 2

        if cmd == "15":
            take = 4
        elif cmd == "05":
            take = 3
        else:
            print(cmd)
            continue

        parts = [cmd]
        for _ in range(take):
            if idx + 2 > total_len:
                break
            byte_val = s[idx : idx + 2].upper()
            parts.append(byte_val)
            idx += 2
        print(" ".join(parts))


def parse_mipi_seq_c(s: str):
    idx = 0
    total_len = len(s)
    while idx < total_len:
        if idx + 2 > total_len:
            break
        cmd = s[idx : idx + 2].upper()
        idx += 2
        if cmd == "15":
            take = 4
        elif cmd == "05":
            take = 3
        else:
            print(f"0x{cmd}, ", end="")
            continue
        buf = [f"0x{cmd}"]
        for _ in range(take):
            if idx + 2 > total_len:
                break
            b = s[idx : idx + 2].upper()
            buf.append(f"0x{b}")
            idx += 2
        print(", ".join(buf) + ",")


raw_seq = "0x150002e0 0x150002 0xe1931500 0x2e26515 0x2e3f8"

new_seq = ""

for val in raw_seq.split(" "):
    h = pad8(val.removeprefix("0x"))
    new_seq += h


parse_mipi_seq(new_seq)
