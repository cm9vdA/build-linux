import sys

def hex_list_to_dec(text: str):
    hex_strs = text.strip().split()
    dec_list = []
    for h in hex_strs:
        dec = int(h, 16)
        print(f"{h} -> {dec}")
        dec_list.append(dec)
    return dec_list

def main():
    if len(sys.argv) < 2:
        print("用法：")
        print(f"  python {sys.argv[0]} \"0xd48 0xdde 0xe2f 0x102e\"")
        print("或者管道输入：echo \"0xd48 0xdde\" | python", sys.argv[0])
        return

    # 把命令行所有参数拼接成一整个字符串
    input_str = " ".join(sys.argv[1:])
    dec_array = hex_list_to_dec(input_str)
    print("\n十进制数组:", dec_array)


if __name__ == "__main__":
    main()
