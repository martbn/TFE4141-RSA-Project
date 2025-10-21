#!/usr/bin/env python3
"""
compute_R_consts.py
Compute R mod N and R^2 mod N for R = 2^k (default k=256).
Usage:
  python compute_R_consts.py <modulus-hex> [--k 256]
Outputs two 0-padded hex strings (width = k bits / 4 nibbles).
"""
import sys
import argparse

def main():
    p = argparse.ArgumentParser(description='Compute R mod N and R^2 mod N')
    p.add_argument('modulus', help='modulus as hex string (optionally with 0x)')
    p.add_argument('--k', type=int, default=256, help='R = 2^k, default 256')
    args = p.parse_args()

    s = args.modulus
    if s.startswith('0x') or s.startswith('0X'):
        s = s[2:]
    try:
        n = int(s, 16)
    except ValueError:
        print('Invalid modulus hex string')
        return 2
    if n == 0:
        print('Modulus cannot be zero')
        return 2
    k = args.k
    R = 1 << k
    rmod = R % n
    r2mod = (R * R) % n
    width_nibbles = (k + 3) // 4
    print('R_mod_n =', format(rmod, '0{}x'.format(width_nibbles)))
    print('R_squared_mod_n =', format(r2mod, '0{}x'.format(width_nibbles)))
    return 0

if __name__ == '__main__':
    sys.exit(main())
