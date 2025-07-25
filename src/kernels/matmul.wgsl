struct MatmulParams {
  M: u32,
  N: u32,
  K: u32,
  alpha: f32,
  beta: f32,
}

@group(0) @binding(0) var<uniform> params: MatmulParams;
@group(0) @binding(1) var<storage, read> a: array<f32>;
@group(0) @binding(2) var<storage, read> b: array<f32>;
@group(0) @binding(3) var<storage, read_write> c: array<f32>;

const TILE_SIZE = 16u;

@compute @workgroup_size(TILE_SIZE, TILE_SIZE)
fn main(
  @builtin(global_invocation_id) global_id: vec3<u32>,
  @builtin(local_invocation_id) local_id: vec3<u32>,
  @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
  let row = global_id.x;
  let col = global_id.y;
  
  if (row >= params.M || col >= params.N) {
    return;
  }
  
  var sum = 0.0;
  
  for (var k = 0u; k < params.K; k = k + 1u) {
    let a_index = row * params.K + k;
    let b_index = k * params.N + col;
    sum = sum + a[a_index] * b[b_index];
  }
  
  let c_index = row * params.N + col;
  c[c_index] = params.alpha * sum + params.beta * c[c_index];
}

@compute @workgroup_size(TILE_SIZE, TILE_SIZE)
fn matmul_tiled(
  @builtin(global_invocation_id) global_id: vec3<u32>,
  @builtin(local_invocation_id) local_id: vec3<u32>,
  @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
  var tile_a: array<f32, 256>;
  var tile_b: array<f32, 256>;
  
  let row = workgroup_id.x * TILE_SIZE + local_id.x;
  let col = workgroup_id.y * TILE_SIZE + local_id.y;
  
  var sum = 0.0;
  
  let num_tiles = (params.K + TILE_SIZE - 1u) / TILE_SIZE;
  
  for (var t = 0u; t < num_tiles; t = t + 1u) {
    let tile_row = row;
    let tile_col = t * TILE_SIZE + local_id.y;
    
    if (tile_row < params.M && tile_col < params.K) {
      tile_a[local_id.x * TILE_SIZE + local_id.y] = a[tile_row * params.K + tile_col];
    } else {
      tile_a[local_id.x * TILE_SIZE + local_id.y] = 0.0;
    }
    
    let b_row = t * TILE_SIZE + local_id.x;
    let b_col = col;
    
    if (b_row < params.K && b_col < params.N) {
      tile_b[local_id.x * TILE_SIZE + local_id.y] = b[b_row * params.N + b_col];
    } else {
      tile_b[local_id.x * TILE_SIZE + local_id.y] = 0.0;
    }
    
    workgroupBarrier();
    
    for (var k = 0u; k < TILE_SIZE; k = k + 1u) {
      sum = sum + tile_a[local_id.x * TILE_SIZE + k] * tile_b[k * TILE_SIZE + local_id.y];
    }
    
    workgroupBarrier();
  }
  
  if (row < params.M && col < params.N) {
    let c_index = row * params.N + col;
    c[c_index] = params.alpha * sum + params.beta * c[c_index];
  }
}