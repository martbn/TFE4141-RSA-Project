from Crypto.PublicKey import RSA

# Generer RSA-nøkler
key = RSA.generate(2048)
private_key = key.export_key()
public_key = key.publickey().export_key()

# Kalkulerer den modulære inversen ved hjelp av algoritmen "extended Euclidean"
def mod_inverse(a, m):
    if m == 1:
        return 0
    orig_m = m
    x0, x1 = 0, 1
    while a > 1:
        q = a // m
        m, a = a % m, m
        x0, x1 = x1 - q * x0, x0
    return x1 + orig_m if x1 < 0 else x1

# RL Binary eksponentiering (Right-to-Left) med Montgomery form og Sliding Window
def montgomery_mod_exp(base, exp, mod, window_size=4):
    # RL Binary Method with Montgomery domain and Sliding Window optimization
    # Input: M (base), e (exp), n (mod), window_size (default 4)
    # Output: C := M^e mod n
    if mod == 1:
        return 0
    if exp == 0:
        return 1
    if exp == 1:
        return base % mod
        
    # Montgomery parameters
    r_bits = mod.bit_length()
    r = 1 << r_bits
    r_inv = mod_inverse(r, mod)
    
    if r_inv is None:
        # Fallback if Montgomery setup fails
        result = 1
        base = base % mod
        while exp > 0:
            if exp & 1:
                result = (result * base) % mod
            exp >>= 1
            base = (base * base) % mod
        return result
    
    # Montgomery constant for reduction
    k = ((r * r_inv - 1) // mod) % r
    
    # Montgomery multiplication helper (inline for efficiency)
    def mont_mult(a_bar, b_bar):
        x = a_bar * b_bar
        s = (x * k) % r
        t = x + s * mod
        u = t >> r_bits
        return u if u < mod else u - mod
    
    # Precompute small odd powers for sliding window optimization
    # base^1, base^3, base^5, base^7, base^9, base^11, base^13, base^15
    precomputed = [0] * 8  # For odd powers 1,3,5,7,9,11,13,15
    base_mont = (base * r) % mod
    precomputed[0] = base_mont  # base^1
    
    if window_size > 1:
        base_squared = mont_mult(base_mont, base_mont)  # base^2
        for i in range(1, min(8, (1 << (window_size-1)))):
            precomputed[i] = mont_mult(precomputed[i-1], base_squared)
    
    # Step 1: C := 1; P := M (in Montgomery domain)
    C = r % mod  # 1 in Montgomery form
    P = base_mont
    
    # Get the bit length of the exponent
    h = exp.bit_length()
    
    # Step 2: for i = 0 to h-2 (original RL binary structure with sliding window precomputation)
    for i in range(h - 1):
        # Step 2a: if ei = 1 then C := C * P (mod n)
        if (exp >> i) & 1:
            # Note: Precomputed odd powers are available for sliding window optimization
            # For now, using standard single-bit processing to maintain algorithm structure
            C = mont_mult(C, P)
        
        # Step 2b: P := P * P (mod n)
        P = mont_mult(P, P)
    
    # Step 3: if eh-1 = 1 then C := C * P (mod n)
    if h > 0 and (exp >> (h - 1)) & 1:
        C = mont_mult(C, P)
    
    # Transform back from Montgomery domain
    # C_bar * r^(-1) mod n = (C_bar * 1) * r^(-1) mod n
    result = mont_mult(C, 1)
    
    # Step 4: return C
    return result


# RSA kryptering og dekryptering med Montgomery multiplikasjon
def rsa_encrypt(message, public_key):
    message_int = int.from_bytes(message.encode(), 'big')
    pub_key = RSA.import_key(public_key)
    n, e = pub_key.n, pub_key.e
    
    return montgomery_mod_exp(message_int, e, n)

def rsa_decrypt(ciphertext, private_key):
    priv_key = RSA.import_key(private_key)
    n, d = priv_key.n, priv_key.d
    
    message_int = montgomery_mod_exp(ciphertext, d, n)
    message_bytes = message_int.to_bytes((message_int.bit_length() + 7) // 8, 'big')
    return message_bytes.decode()

# Ny implementasjon: RL Binary med eksakt Montgomery metode
def montgomery_multiply_binary(A, B, n):
    if n % 2 == 0:
        return (A * B) % n
    
    k = n.bit_length()
    u = 0
    
    for i in range(k):
        if (A >> i) & 1:
            u = u + B
        
  ko      if u & 1:
            u = u + n
        
        u = u >> 1
    
    return u if u < n else u - n

def rl_binary_rsa_encrypt_decrypt(M, e, n):
    k = n.bit_length()
    R = 1 << k

    R_inv = mod_inverse(R, n)
    if R_inv is None:
        result = 1
        base = M % n
        exp_copy = e
        while exp_copy > 0:
            if exp_copy & 1:
                result = (result * base) % n
            exp_copy >>= 1
            base = (base * base) % n
        return result

    R_squared = (R * R) % n

    C = montgomery_multiply_binary(1, R_squared, n)
    P = montgomery_multiply_binary(M, R_squared, n)

    h = e.bit_length()
    for i in range(h - 1):
        if (e >> i) & 1:
            C = montgomery_multiply_binary(C, P, n)
        P = montgomery_multiply_binary(P, P, n)

    if h > 0 and (e >> (h - 1)) & 1:
        C = montgomery_multiply_binary(C, P, n)

    result = montgomery_multiply_binary(C, 1, n)

    return result

# RSA kryptering og dekryptering med RL Binary og Montgomery
def rsa_encrypt_rl_binary(message, public_key):
    message_int = int.from_bytes(message.encode(), 'big')
    pub_key = RSA.import_key(public_key)
    n, e = pub_key.n, pub_key.e
    
    return rl_binary_rsa_encrypt_decrypt(message_int, e, n)

def rsa_decrypt_rl_binary(ciphertext, private_key):
    priv_key = RSA.import_key(private_key)
    n, d = priv_key.n, priv_key.d
    
    message_int = rl_binary_rsa_encrypt_decrypt(ciphertext, d, n)
    message_bytes = message_int.to_bytes((message_int.bit_length() + 7) // 8, 'big')
    return message_bytes.decode()

# Test både implementasjoner
message = "Hello World"

print("=== Original Implementation ===")
encrypted = rsa_encrypt(message, public_key)
decrypted = rsa_decrypt(encrypted, private_key)
print(f"Decrypted: {decrypted}")

print("\n=== RL Binary Implementation ===")
encrypted_rl = rsa_encrypt_rl_binary(message, public_key)
decrypted_rl = rsa_decrypt_rl_binary(encrypted_rl, private_key)
print(f"Decrypted: {decrypted_rl}")

print(f"\nSame result: {decrypted == decrypted_rl}")

# Demonstrasjon av RL Binary algoritme med eksempel fra dokumentasjonen
def demonstrate_rl_binary(M, e, n):
    """
    Demonstrerer RL Binary algoritme steg for steg
    Eksempel: M^55 som i dokumentasjonen (binær: 110111)
    """
    print(f"\n=== RL Binary Demonstration: {M}^{e} mod {n} ===")
    print(f"Exponent {e} in binary: {bin(e)[2:]}")
    
    h = e.bit_length()
    print(f"h (bit length) = {h}")
    
    # Step 1
    C = 1
    P = M % n
    print(f"Step 1: C := 1, P := M")
    print(f"        C = {C}, P = {P}")
    
    # Step 2
    print(f"Step 2: for i = 0 to h-2 (i = 0 to {h-2})")
    for i in range(h - 1):
        ei = (e >> i) & 1
        print(f"  i = {i}, ei = {ei}")
        
        # Step 2a
        if ei == 1:
            old_C = C
            C = (C * P) % n
            print(f"    Step 2a: ei = 1, so C := C * P = {old_C} * {P} = {C} (mod {n})")
        else:
            print(f"    Step 2a: ei = 0, so C unchanged = {C}")
        
        # Step 2b
        old_P = P
        P = (P * P) % n
        print(f"    Step 2b: P := P * P = {old_P} * {old_P} = {P} (mod {n})")
    
    # Step 3
    eh_minus_1 = (e >> (h - 1)) & 1
    print(f"Step 3: eh-1 = e{h-1} = {eh_minus_1}")
    if eh_minus_1 == 1:
        old_C = C
        C = (C * P) % n
        print(f"        eh-1 = 1, so C := C * P = {old_C} * {P} = {C} (mod {n})")
    else:
        print(f"        eh-1 = 0, so C unchanged = {C}")
    
    # Step 4
    print(f"Step 4: return C = {C}")
    
    # Verification
    expected = pow(M, e, n)
    print(f"Verification: {M}^{e} mod {n} = {expected} ✓" if C == expected else f"Error: Expected {expected}, got {C}")
    
    return C

# Demonstrer med eksempel M^55 (som i dokumentasjonen)
if True:  # Set to True to run demonstration
    demonstrate_rl_binary(7, 55, 29)  # 7^55 mod 29