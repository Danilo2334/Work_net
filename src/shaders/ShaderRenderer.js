import { VERTEX_SHADER, AURORA_FRAGMENT_SHADER } from './shaderSources';

const COLOR_UNIFORMS = ['u_color1', 'u_color2', 'u_color3'];
const COLOR_LERP_MS = 450; // matches the global theme transition

/** Parses `#rgb` / `#rrggbb` into normalized [r, g, b]. */
export const parseHexColor = (value, fallback = [0.5, 0.5, 0.5]) => {
  const hex = String(value ?? '').trim().replace('#', '');
  const full = hex.length === 3 ? hex.split('').map((c) => c + c).join('') : hex;
  if (!/^[0-9a-f]{6}$/i.test(full)) return fallback;
  return [0, 2, 4].map((i) => parseInt(full.slice(i, i + 2), 16) / 255);
};

/**
 * Self-contained WebGL renderer for a single full-quad fragment shader.
 *
 * Performance safeguards:
 * - renders at reduced resolution (the field is soft, upscaling is invisible),
 * - throttled frame rate,
 * - pauses when off-screen or when the tab is hidden,
 * - static single frame when the user prefers reduced motion,
 * - releases the GL context on destroy (avoids hitting browser context limits).
 */
export class ShaderRenderer {
  #canvas;
  #gl;
  #program;
  #buffer;
  #uniforms = {};
  #options;
  #frameId = null;
  #lastFrame = 0;
  #startTime = performance.now();
  #visible = true;
  #running = false;
  #colors = { from: null, to: null, current: null, startedAt: 0 };
  #resizeObserver;
  #intersectionObserver;

  /** @returns {boolean} whether WebGL is available in this browser. */
  static isSupported() {
    try {
      const canvas = document.createElement('canvas');
      return Boolean(canvas.getContext('webgl'));
    } catch {
      return false;
    }
  }

  constructor(canvas, { fragment = AURORA_FRAGMENT_SHADER, fps = 30, scale = 0.5, seed = [0, 0], animate = true } = {}) {
    this.#canvas = canvas;
    this.#options = { fps, scale, seed, animate, fragment };

    const gl = canvas.getContext('webgl', { premultipliedAlpha: true, antialias: false, alpha: true });
    if (!gl) throw new Error('WebGL not supported');
    this.#gl = gl;

    this.#program = this.#createProgram(VERTEX_SHADER, fragment);
    this.#buffer = this.#createQuad();
    this.#cacheUniforms(['u_resolution', 'u_time', 'u_seed', ...COLOR_UNIFORMS]);

    this.#resizeObserver = new ResizeObserver(() => this.#resize());
    this.#resizeObserver.observe(canvas);
    this.#intersectionObserver = new IntersectionObserver(([entry]) => {
      this.#visible = entry.isIntersecting;
      this.#syncLoop();
    });
    this.#intersectionObserver.observe(canvas);
    document.addEventListener('visibilitychange', this.#syncLoop);

    this.#resize();
  }

  /** Sets the three palette colors, easing from the previous palette. */
  setColors(colors, { immediate = false } = {}) {
    const now = performance.now();
    const target = colors.map((c) => (Array.isArray(c) ? c : parseHexColor(c)));
    const from = this.#colors.current;
    this.#colors = {
      from: immediate || !from ? target : from,
      to: target,
      current: immediate || !from ? target : from,
      startedAt: now,
    };
    this.#requestRender();
  }

  start() {
    this.#running = true;
    this.#syncLoop();
  }

  stop() {
    this.#running = false;
    this.#syncLoop();
  }

  destroy() {
    this.stop();
    this.#resizeObserver.disconnect();
    this.#intersectionObserver.disconnect();
    document.removeEventListener('visibilitychange', this.#syncLoop);
    const gl = this.#gl;
    gl.deleteBuffer(this.#buffer);
    gl.deleteProgram(this.#program);
    gl.getExtension('WEBGL_lose_context')?.loseContext();
  }

  // ---------------------------------------------------------------- private

  #syncLoop = () => {
    const shouldRun = this.#running && this.#visible && !document.hidden;
    if (shouldRun && this.#frameId === null) {
      this.#frameId = requestAnimationFrame(this.#tick);
    } else if (!shouldRun && this.#frameId !== null) {
      cancelAnimationFrame(this.#frameId);
      this.#frameId = null;
    }
  };

  #tick = (now) => {
    this.#frameId = null;
    const interval = 1000 / this.#options.fps;
    const colorsSettling = this.#colors.to && now - this.#colors.startedAt < COLOR_LERP_MS;

    if (now - this.#lastFrame >= interval) {
      this.#lastFrame = now;
      this.#render(now);
    }
    if (this.#options.animate || colorsSettling) this.#syncLoop();
  };

  /** Renders once outside the loop (e.g. static mode or paused state). */
  #requestRender() {
    if (this.#frameId === null) {
      requestAnimationFrame((now) => this.#render(now));
      if (this.#running) this.#syncLoop();
    }
  }

  #render(now) {
    const gl = this.#gl;
    if (!this.#colors.to) return;
    this.#updateColors(now);

    const elapsed = this.#options.animate ? (now - this.#startTime) / 1000 : 12;
    gl.useProgram(this.#program);
    gl.uniform2f(this.#uniforms.u_resolution, gl.drawingBufferWidth, gl.drawingBufferHeight);
    gl.uniform1f(this.#uniforms.u_time, elapsed);
    gl.uniform2f(this.#uniforms.u_seed, ...this.#options.seed);
    COLOR_UNIFORMS.forEach((name, i) => gl.uniform3f(this.#uniforms[name], ...this.#colors.current[i]));

    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  #updateColors(now) {
    const { from, to, startedAt } = this.#colors;
    const progress = Math.min(1, (now - startedAt) / COLOR_LERP_MS);
    const eased = 1 - Math.pow(1 - progress, 3);
    this.#colors.current = to.map((color, i) => color.map((v, c) => from[i][c] + (v - from[i][c]) * eased));
  }

  #resize() {
    const { clientWidth, clientHeight } = this.#canvas;
    const scale = this.#options.scale * Math.min(window.devicePixelRatio || 1, 2);
    const width = Math.max(1, Math.round(clientWidth * scale));
    const height = Math.max(1, Math.round(clientHeight * scale));
    if (this.#canvas.width !== width || this.#canvas.height !== height) {
      this.#canvas.width = width;
      this.#canvas.height = height;
      this.#gl.viewport(0, 0, width, height);
      this.#requestRender();
    }
  }

  #createShader(type, source) {
    const gl = this.#gl;
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      const log = gl.getShaderInfoLog(shader);
      gl.deleteShader(shader);
      throw new Error(`Shader compile error: ${log}`);
    }
    return shader;
  }

  #createProgram(vertexSource, fragmentSource) {
    const gl = this.#gl;
    const vertex = this.#createShader(gl.VERTEX_SHADER, vertexSource);
    const fragment = this.#createShader(gl.FRAGMENT_SHADER, fragmentSource);
    const program = gl.createProgram();
    gl.attachShader(program, vertex);
    gl.attachShader(program, fragment);
    gl.linkProgram(program);
    gl.deleteShader(vertex);
    gl.deleteShader(fragment);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      throw new Error(`Program link error: ${gl.getProgramInfoLog(program)}`);
    }
    return program;
  }

  #createQuad() {
    const gl = this.#gl;
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const location = gl.getAttribLocation(this.#program, 'a_position');
    gl.enableVertexAttribArray(location);
    gl.vertexAttribPointer(location, 2, gl.FLOAT, false, 0, 0);
    return buffer;
  }

  #cacheUniforms(names) {
    names.forEach((name) => {
      this.#uniforms[name] = this.#gl.getUniformLocation(this.#program, name);
    });
  }
}
