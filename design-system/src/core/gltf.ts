// Writes a model as .gltf, the file Roblox Studio imports with File > Import. Every part becomes its
// own mesh, so Studio keeps them apart and the game can paint them. Moving groups are written in
// their rest pose, because the game moves those parts itself. A group's hinge is stored in `extras`.

import type { ModelData } from "./model";

function base64(bytes: Uint8Array): string {
  let text = "";
  const step = 0x8000;
  for (let i = 0; i < bytes.length; i += step) {
    text += String.fromCharCode.apply(null, bytes.subarray(i, i + step) as unknown as number[]);
  }
  return btoa(text);
}

const toLinear = (v: number): number => {
  const c = v / 255;
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
};

/** The model as the text of a .gltf file. */
export function toGltf(model: ModelData): string {
  const parts = model.exported;
  const total = parts.reduce((sum, p) => sum + p.positions.length * 2, 0);
  const data = new Float32Array(total);
  const gltf: any = {
    asset: {
      version: "2.0",
      generator: "3D Roblox tools modeling",
      extras: {
        groups: model.groups.map((g) => ({ name: g.name, parent: g.parent?.name ?? null, hinge: g.hinge, axis: g.axis })),
      },
    },
    scene: 0,
    scenes: [{ name: model.name, nodes: parts.map((_, i) => i) }],
    nodes: [],
    meshes: [],
    materials: [],
    accessors: [],
    bufferViews: [],
    buffers: [],
  };
  let offset = 0;
  parts.forEach((part, i) => {
    const count = part.positions.length / 3;
    const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
    for (let v = 0; v < part.positions.length; v++) {
      min[v % 3] = Math.min(min[v % 3], part.positions[v]);
      max[v % 3] = Math.max(max[v % 3], part.positions[v]);
    }
    data.set(part.positions, offset);
    data.set(part.normals, offset + part.positions.length);
    const bytes = part.positions.length * 4;
    gltf.bufferViews.push({ buffer: 0, byteOffset: offset * 4, byteLength: bytes, target: 34962 });
    gltf.bufferViews.push({ buffer: 0, byteOffset: offset * 4 + bytes, byteLength: bytes, target: 34962 });
    gltf.accessors.push({ bufferView: i * 2, componentType: 5126, count, type: "VEC3", min, max });
    gltf.accessors.push({ bufferView: i * 2 + 1, componentType: 5126, count, type: "VEC3" });
    gltf.materials.push({
      name: `${part.name}Paint`,
      pbrMetallicRoughness: {
        baseColorFactor: [toLinear(part.color[0]), toLinear(part.color[1]), toLinear(part.color[2]), part.alpha],
        metallicFactor: 0,
        roughnessFactor: 1,
      },
      alphaMode: part.alpha < 1 ? "BLEND" : "OPAQUE",
    });
    gltf.meshes.push({ name: part.name, primitives: [{ attributes: { POSITION: i * 2, NORMAL: i * 2 + 1 }, material: i, mode: 4 }] });
    const node: any = { name: part.name, mesh: i };
    if (part.group) node.extras = { group: part.group.name };
    gltf.nodes.push(node);
    offset += part.positions.length * 2;
  });
  const bytes = new Uint8Array(data.buffer);
  gltf.buffers.push({ byteLength: bytes.length, uri: `data:application/octet-stream;base64,${base64(bytes)}` });
  return JSON.stringify(gltf);
}
