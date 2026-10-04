import { useEffect, useRef, useState } from 'react';
import { useReducedMotion } from 'framer-motion';
import { ShaderRenderer } from '../../shaders/ShaderRenderer';
import { useTheme } from '../../theme/useTheme';
import './ShaderBackground.css';

const PALETTE_VARS = ['--shader-1', '--shader-2', '--shader-3'];

const readPalette = (element) => {
  const styles = getComputedStyle(element);
  return PALETTE_VARS.map((name) => styles.getPropertyValue(name));
};

/**
 * Decorative, theme-aware WebGL background.
 * Colors come from CSS custom properties (`--shader-1..3`), so palettes are
 * defined per theme / per accent in CSS and the shader simply follows them.
 * Falls back to a static CSS gradient when WebGL is unavailable.
 */
const ShaderBackground = ({ seed = [0, 0], className = '' }) => {
  const canvasRef = useRef(null);
  const rendererRef = useRef(null);
  const [fallback, setFallback] = useState(false);
  const reduceMotion = useReducedMotion();
  const { theme } = useTheme();
  const [seedX, seedY] = seed;

  // Lifecycle: create / destroy the renderer.
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return undefined;
    try {
      const renderer = new ShaderRenderer(canvas, { seed: [seedX, seedY], animate: !reduceMotion });
      renderer.setColors(readPalette(canvas), { immediate: true });
      renderer.start();
      rendererRef.current = renderer;
      return () => {
        renderer.destroy();
        rendererRef.current = null;
      };
    } catch {
      setFallback(true);
      return undefined;
    }
  }, [seedX, seedY, reduceMotion]);

  // Theme changes: ease the palette towards the new CSS colors.
  useEffect(() => {
    const canvas = canvasRef.current;
    if (canvas && rendererRef.current) rendererRef.current.setColors(readPalette(canvas));
  }, [theme]);

  return (
    <div className={`shader-bg ${fallback ? 'shader-bg--fallback' : ''} ${className}`.trim()} aria-hidden="true">
      {!fallback && <canvas ref={canvasRef} className="shader-bg__canvas" />}
    </div>
  );
};

export default ShaderBackground;
