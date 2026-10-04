/**
 * GLSL sources for the dashboard card background.
 * A slow, domain-warped fbm field blended between three theme colors.
 * Alpha fades towards the bottom-left so text (top-left / bottom) stays crisp.
 */

export const VERTEX_SHADER = /* glsl */ `
attribute vec2 a_position;
varying vec2 v_uv;

void main() {
  v_uv = a_position * 0.5 + 0.5;
  gl_Position = vec4(a_position, 0.0, 1.0);
}
`;

export const AURORA_FRAGMENT_SHADER = /* glsl */ `
precision mediump float;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec2 u_seed;
uniform vec3 u_color1;
uniform vec3 u_color2;
uniform vec3 u_color3;

varying vec2 v_uv;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 4; i++) {
    value += amplitude * noise(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

void main() {
  float aspect = u_resolution.x / max(u_resolution.y, 1.0);
  vec2 p = vec2(v_uv.x * aspect, v_uv.y) * 1.25 + u_seed;
  float t = u_time * 0.045;

  // Domain warping gives a soft, liquid motion.
  vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3) - t));
  float n = fbm(p + 1.6 * q + vec2(1.7, 9.2) + t * 0.6);

  vec3 color = mix(u_color1, u_color2, smoothstep(0.25, 0.8, n));
  color = mix(color, u_color3, smoothstep(0.4, 0.9, q.x) * 0.65);

  // Strongest in the top-right corner, gently fading elsewhere.
  float glow = smoothstep(1.35, 0.0, distance(v_uv, vec2(1.0, 1.0)));
  float alpha = mix(0.25, 1.0, glow);

  gl_FragColor = vec4(color * alpha, alpha); // premultiplied alpha
}
`;
