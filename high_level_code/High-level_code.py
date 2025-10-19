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

# Montomery multiplikasjon med bitshift-operasjoner
def montgomery_multiplication(a, b, n):
    if n % 2 == 0:
        return (a * b) % n
    
    r_bits = n.bit_length()
    r = 1 << r_bits
    
    r_inv = mod_inverse(r, n)
    if r_inv is None:
        return (a * b) % n
        
    k = ((r * r_inv - 1) // n) % r
    
    a_bar = (a * r) % n
    b_bar = (b * r) % n
    x = a_bar * b_bar
    s = (x * k) % r
    t = x + s * n
    
    u = t >> r_bits
    
    c_bar = u if u < n else u - n
    return (c_bar * r_inv) % n

# Montgomery eksponentiering
def montgomery_mod_exp(base, exp, mod):
    result = 1
    base = base % mod
    
    while exp > 0:
        if exp & 1:
            result = montgomery_multiplication(result, base, mod)
        exp >>= 1
        if exp > 0:
            base = montgomery_multiplication(base, base, mod)
    
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

# Test melding
message = "Hello World"

encrypted = rsa_encrypt(message, public_key)
decrypted = rsa_decrypt(encrypted, private_key)

print(f"Decrypted: {decrypted}")