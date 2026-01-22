// controller/src/components/ProgressBar.tsx
// Progress bar component for execution display

interface ProgressBarProps {
  current: number;
  total: number;
  width?: number;
}

export function ProgressBar({ current, total, width = 30 }: ProgressBarProps) {
  const progress = total > 0 ? current / total : 0;
  const filled = Math.round(progress * width);
  const empty = width - filled;

  // Use Unicode block characters for the progress bar
  const filledChar = "\u2588"; // Full block
  const emptyChar = "\u2591"; // Light shade

  return (
    <text>
      [{filledChar.repeat(filled)}
      {emptyChar.repeat(empty)}] {current}/{total}
    </text>
  );
}
