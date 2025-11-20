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
    """
    Standard Montgomery multiplication returning (a * b * R^{-1}) mod n.
    Requires n odd (so R and n are coprime). Uses R = 2^r_bits where r_bits = n.bit_length().
    """
    if n % 2 == 0:
        # Fallback for even modulus
        return (a * b) % n

    r_bits = n.bit_length()
    R = 1 << r_bits

    # Compute n' = -n^{-1} mod R (R is power of two)
    try:
        n_inv = pow(n, -1, R)
    except ValueError:
        # modular inverse doesn't exist (shouldn't happen for odd n)
        return (a * b) % n
    n_prime = (-n_inv) % R

    t = a * b
    m = (t * n_prime) & (R - 1)
    u = (t + m * n) >> r_bits
    if u >= n:
        u -= n
    return u

# Montgomery eksponentiering
def montgomery_mod_exp(base, exp, mod):
    """
    Montgomery modular exponentiation following the VHDL flow:
    - Convert operands into Montgomery domain using R^2 mod n
    - Perform binary exponentiation entirely in Montgomery domain using
      the montgomery_multiplication() primitive
    - Convert back by Montgomery-multiplying with 1

    This function does not modify the montgomery_multiplication() itself.
    """
    base = base % mod

    # For even modulus fall back to Python's pow (montgomery requires odd modulus)
    if mod % 2 == 0:
        return pow(base, exp, mod)

    # Compute R = 2^r where r = bit_length(mod); R > mod
    r_bits = mod.bit_length()
    R = 1 << r_bits
    R_mod = R % mod
    R2_mod = (R_mod * R_mod) % mod

    # Convert base and 1 into Montgomery domain using MontMul(x, R^2)
    base_bar = montgomery_multiplication(base, R2_mod, mod)
    one_bar = montgomery_multiplication(1 % mod, R2_mod, mod)

    # Exponentiate in Montgomery domain
    result_bar = one_bar
    while exp > 0:
        if exp & 1:
            result_bar = montgomery_multiplication(result_bar, base_bar, mod)
        exp >>= 1
        if exp > 0:
            base_bar = montgomery_multiplication(base_bar, base_bar, mod)

    # Convert back to regular domain: MontMul(result_bar, 1) = result
    result = montgomery_multiplication(result_bar, 1 % mod, mod)
    return result

# RSA kryptering og dekryptering med Montgomery multiplikasjon
def rsa_encrypt(message, public_key):
    message_int = int.from_bytes(message.encode(), 'big')
    pub_key = RSA.import_key(public_key)
    n, e = pub_key.n, pub_key.e
    # Use Montgomery-domain exponentiation to match the VHDL implementation
    return montgomery_mod_exp(message_int, e, n)

def rsa_decrypt(ciphertext, private_key):
    priv_key = RSA.import_key(private_key)
    n, d = priv_key.n, priv_key.d
    # Decrypt using Montgomery exponentiation (result is integer in normal domain)
    message_int = montgomery_mod_exp(ciphertext, d, n)
    # Convert integer to bytes and decode; handle zero-case
    if message_int == 0:
        return ''
    message_bytes = message_int.to_bytes((message_int.bit_length() + 7) // 8, 'big')
    try:
        return message_bytes.decode()
    except Exception:
        # If decoding fails (not valid UTF-8), return raw bytes repr
        return message_bytes

# Test melding
message = "Hello World"
message_int = int.from_bytes(message.encode(), 'big')

# Encrypt (returns integer ciphertext)
encrypted = rsa_encrypt(message, public_key)
# Diagnostic: compare to Python's built-in pow() for encryption
pub = RSA.import_key(public_key)
expected_cipher = pow(message_int, pub.e, pub.n)
print("Expected ciphertext (pow):", expected_cipher)
print("montgomery ciphertext:    ", encrypted)
if expected_cipher != encrypted:
    print("Warning: montgomery-based encryption differs from pow() result")

# Decrypt (returns plaintext as bytes or raw bytes if decoding fails)
decrypted = rsa_decrypt(encrypted, private_key)

# For debugging: also compute integer decrypted value via montgomery_mod_exp directly
decrypted_int = montgomery_mod_exp(encrypted, RSA.import_key(private_key).d, RSA.import_key(private_key).n)

print("Original message int:", message_int)
print("Ciphertext int:", encrypted)
print("Decrypted int:", decrypted_int)

if decrypted_int == message_int:
    # Good: convert back to text
    try:
        recovered = decrypted_int.to_bytes((decrypted_int.bit_length() + 7) // 8, 'big').decode()
        print("Recovered text:", recovered)
    except Exception:
        print("Recovered bytes (binary):", decrypted_int.to_bytes((decrypted_int.bit_length() + 7) // 8, 'big'))
else:
    print("Mismatch: decrypted integer does not equal original message integer.")
    # Still show the best-effort decoded result from rsa_decrypt
    print(f"rsa_decrypt returned: {decrypted}")
    # Diagnostic: compare to Python's built-in pow() for decryption
    priv = RSA.import_key(private_key)
    expected_plain_int = pow(encrypted, priv.d, priv.n)
    print("Expected decrypted int (pow):", expected_plain_int)
    print("montgomery decrypted int:    ", decrypted_int)
    if expected_plain_int != decrypted_int:
        print("ERROR: montgomery_mod_exp produced a different integer than pow() on decryption.")
    else:
        print("pow() and montgomery_mod_exp agree on decryption integer — decoding step likely failing.")