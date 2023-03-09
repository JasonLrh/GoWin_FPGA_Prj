#!/usr/bin/env python3
import sys

if __name__=='__main__':
    if len(sys.argv) < 3:
        print("please give bin-file path to $1, targfile $2")
        exit(0)
    f_name = sys.argv[1]
    mi_name = sys.argv[2]

    addr_depth = 1024

    with open(mi_name, 'w') as mi:
        mi.write("#File_format=Hex\n#Address_depth=%d\n#Data_width=32\n"%(addr_depth))
        with open(f_name, 'rb') as f:
            k = f.read()
            while len(k) > 4:
                inst = int.from_bytes(k[0:4], 'little')
                # print("%08x\n"%(inst))
                mi.write("%08x\n"%(inst))
                k = k[4:]

                addr_depth -= 1
                if (addr_depth == 0): 
                    break
            
            while addr_depth > 0:
                mi.write("%08x\n"%(0))
                addr_depth -= 1

        # print(k)
        # print(len(k))
