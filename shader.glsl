shader_type compute;

// Workgroup size — tune as needed
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Storage buffers (1D array version of your 3D grid)
layout(set = 0, binding = 0, std430) restrict buffer InBuf {
    uint data_in[];
};

layout(set = 0, binding = 1, std430) restrict buffer OutBuf {
    uint data_out[];
};

// Uniforms for dimensions
layout(set = 0, binding = 2, std140) uniform Params {
    int sizeX;
    int sizeY;
    int sizeZ;
};

int wrap(int v, int m) {
    int r = v % m;
    if (r < 0) r += m;
    return r;
}

void main() {
    uint gid = gl_GlobalInvocationID.x;
    int sx = sizeX;
    int sy = sizeY;
    int sz = sizeZ;
    uint total = uint(sx * sy * sz);

    if (gid >= total)
        return;

    int idx = int(gid);
    int yz_stride = sy * sz;
    int x = idx / yz_stride;
    int rem = idx - x * yz_stride;
    int y = rem / sz;
    int z = rem - y * sz;

    int neighbors = 0;

    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            for (int dz = -1; dz <= 1; dz++) {
                if (dx == 0 && dy == 0 && dz == 0) continue;
                int nx = wrap(x + dx, sx);
                int ny = wrap(y + dy, sy);
                int nz = wrap(z + dz, sz);
                uint nidx = uint(nx * yz_stride + ny * sz + nz);
                neighbors += int(data_in[nidx]);
            }
        }
    }

    uint current = data_in[gid];
    uint newv = 0u;

    // Game of Life rules: survive with 5–7, born with 6
    if (current == 1u) {
        if (neighbors >= 5 && neighbors <= 7) newv = 1u;
    } else {
        if (neighbors == 6) newv = 1u;
    }

    data_out[gid] = newv;
}