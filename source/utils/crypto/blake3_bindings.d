module utils.crypto.blake3_bindings;

/// Low-level C bindings for BLAKE3
/// Based on the official BLAKE3 C API: https://github.com/BLAKE3-team/BLAKE3

extern(C):

// BLAKE3 constants
enum BLAKE3_VERSION_STRING = "1.5.0";
enum BLAKE3_KEY_LEN = 32;
enum BLAKE3_OUT_LEN = 32;
enum BLAKE3_BLOCK_LEN = 64;
enum BLAKE3_CHUNK_LEN = 1024;
enum BLAKE3_MAX_DEPTH = 54;

// BLAKE3 hasher struct (opaque from D's perspective)
struct blake3_hasher
{
    align(1):
    uint[8] cv;
    ulong chunk_counter;
    ubyte[BLAKE3_BLOCK_LEN] buf;
    ubyte buf_len;
    ubyte blocks_compressed;
    ubyte flags;
}

// Core API functions
void blake3_hasher_init(blake3_hasher* self);
void blake3_hasher_init_keyed(blake3_hasher* self, const ubyte[BLAKE3_KEY_LEN] key);
void blake3_hasher_init_derive_key(blake3_hasher* self, const char* context);
void blake3_hasher_init_derive_key_raw(blake3_hasher* self, const void* context, size_t context_len);

void blake3_hasher_update(blake3_hasher* self, const void* input, size_t input_len);
void blake3_hasher_finalize(const blake3_hasher* self, ubyte* out_, size_t out_len);
void blake3_hasher_finalize_seek(const blake3_hasher* self, ulong seek, ubyte* out_, size_t out_len);
void blake3_hasher_reset(blake3_hasher* self);

// Version function
const(char)* blake3_version();

