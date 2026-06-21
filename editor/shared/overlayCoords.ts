export interface HostRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface PaintedRect extends HostRect {}

export function computePaintedRect(
  host: HostRect,
  imageWidth: number,
  imageHeight: number,
): PaintedRect {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return { ...host };
  }

  const scale = Math.min(host.width / imageWidth, host.height / imageHeight);
  const paintedWidth = imageWidth * scale;
  const paintedHeight = imageHeight * scale;
  const offsetX = host.x + (host.width - paintedWidth) / 2;
  const offsetY = host.y + (host.height - paintedHeight) / 2;

  return {
    x: offsetX,
    y: offsetY,
    width: paintedWidth,
    height: paintedHeight,
  };
}

export function overlayX(normX: number, painted: PaintedRect, host: HostRect): number {
  if (painted.width > 0) {
    return painted.x + normX * painted.width;
  }
  return host.x + normX * host.width;
}

export function overlayY(normY: number, painted: PaintedRect, host: HostRect): number {
  if (painted.height > 0) {
    return painted.y + normY * painted.height;
  }
  return host.y + normY * host.height;
}

export function normFromOverlayX(
  pixelX: number,
  painted: PaintedRect,
  host: HostRect,
): number {
  if (painted.width > 0) {
    return clamp01((pixelX - painted.x) / painted.width);
  }
  return clamp01((pixelX - host.x) / host.width);
}

export function normFromOverlayY(
  pixelY: number,
  painted: PaintedRect,
  host: HostRect,
): number {
  if (painted.height > 0) {
    return clamp01((pixelY - painted.y) / painted.height);
  }
  return clamp01((pixelY - host.y) / host.height);
}

export function clamp01(value: number): number {
  return Math.max(0, Math.min(1, value));
}

export function anchorFactor(anchor?: string): number {
  const name = (anchor ?? "center").toLowerCase();
  if (name === "left") {
    return 0;
  }
  if (name === "right") {
    return 1;
  }
  return 0.5;
}

export function anchorYFactor(anchorY?: string): number {
  const name = (anchorY ?? "center").toLowerCase();
  if (name === "top") {
    return 0;
  }
  if (name === "bottom") {
    return 1;
  }
  return 0.5;
}

export function labelPosition(
  normX: number,
  normY: number,
  labelWidth: number,
  labelHeight: number,
  anchor: string | undefined,
  anchorY: string | undefined,
  painted: PaintedRect,
  host: HostRect,
): { x: number; y: number } {
  const rawX = overlayX(normX, painted, host) - labelWidth * anchorFactor(anchor);
  const rawY = overlayY(normY, painted, host) - labelHeight * anchorYFactor(anchorY);
  return {
    x: clamp(rawX, 6, host.x + host.width - labelWidth - 6),
    y: clamp(rawY, 6, host.y + host.height - labelHeight - 6),
  };
}

export function centerPosition(
  normX: number,
  normY: number,
  markerWidth: number,
  markerHeight: number,
  painted: PaintedRect,
  host: HostRect,
): { x: number; y: number } {
  return {
    x: overlayX(normX, painted, host) - markerWidth / 2,
    y: overlayY(normY, painted, host) - markerHeight / 2,
  };
}

function clamp(value: number, minValue: number, maxValue: number): number {
  return Math.max(minValue, Math.min(value, maxValue));
}

export function normFromCenterDrag(
  pointerX: number,
  pointerY: number,
  host: HostRect,
  painted: PaintedRect,
): { x: number; y: number } {
  return {
    x: normFromOverlayX(pointerX, painted, host),
    y: normFromOverlayY(pointerY, painted, host),
  };
}

export function normFromLabelDrag(
  clientX: number,
  clientY: number,
  hostRect: HostRect,
  painted: PaintedRect,
  labelWidth: number,
  labelHeight: number,
  anchor?: string,
  anchorY?: string,
): { x: number; y: number } {
  const overlayPixelX = clientX - hostRect.x + labelWidth * anchorFactor(anchor);
  const overlayPixelY = clientY - hostRect.y + labelHeight * anchorYFactor(anchorY);
  return {
    x: normFromOverlayX(overlayPixelX, painted, hostRect),
    y: normFromOverlayY(overlayPixelY, painted, hostRect),
  };
}
