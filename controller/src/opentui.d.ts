// controller/src/opentui.d.ts
// JSX type declarations for OpenTUI
// This augments React's JSX namespace to include OpenTUI elements

import "react";

// OpenTUI style options
interface OpenTUIStyle {
  // Layout
  flexGrow?: number;
  flexShrink?: number;
  flexDirection?: "row" | "column" | "row-reverse" | "column-reverse";
  flexWrap?: "wrap" | "nowrap" | "wrap-reverse";
  alignItems?: "flex-start" | "flex-end" | "center" | "baseline" | "stretch";
  justifyContent?: "flex-start" | "flex-end" | "center" | "space-between" | "space-around" | "space-evenly";
  alignSelf?: "auto" | "flex-start" | "flex-end" | "center" | "baseline" | "stretch";
  flexBasis?: number | "auto";
  position?: "relative" | "absolute";
  overflow?: "visible" | "hidden" | "scroll";
  gap?: number;
  
  // Sizing
  width?: number | string;
  height?: number | string;
  minWidth?: number | string;
  maxWidth?: number | string;
  minHeight?: number | string;
  maxHeight?: number | string;
  
  // Spacing
  padding?: number;
  paddingTop?: number;
  paddingRight?: number;
  paddingBottom?: number;
  paddingLeft?: number;
  margin?: number;
  marginTop?: number;
  marginRight?: number;
  marginBottom?: number;
  marginLeft?: number;
  
  // Border
  border?: boolean;
  borderStyle?: "single" | "double" | "rounded" | "bold" | "ascii";
  borderColor?: string;
  
  // Colors
  fg?: string;
  backgroundColor?: string;
  
  // Other
  zIndex?: number;
  visible?: boolean;
  opacity?: number;
}

interface OpenTUIBoxProps {
  title?: string;
  style?: OpenTUIStyle & Record<string, unknown>;
  children?: React.ReactNode;
  // Direct props (can also be in style)
  fg?: string;
  bg?: string;
  backgroundColor?: string;
  border?: boolean;
  borderStyle?: "single" | "double" | "rounded" | "bold" | "ascii";
  borderColor?: string;
  padding?: number;
  paddingTop?: number;
  paddingRight?: number;
  paddingBottom?: number;
  paddingLeft?: number;
  margin?: number;
  marginTop?: number;
  marginRight?: number;
  marginBottom?: number;
  marginLeft?: number;
  flexDirection?: "row" | "column" | "row-reverse" | "column-reverse";
  flexGrow?: number;
  width?: number | string;
  height?: number | string;
  justifyContent?: "flex-start" | "flex-end" | "center" | "space-between" | "space-around" | "space-evenly";
  alignItems?: "flex-start" | "flex-end" | "center" | "baseline" | "stretch";
  gap?: number;
  // Position props
  position?: "relative" | "absolute";
  top?: number | string;
  left?: number | string;
  right?: number | string;
  bottom?: number | string;
}

interface OpenTUITextProps {
  style?: OpenTUIStyle & Record<string, unknown>;
  children?: React.ReactNode;
  fg?: string;
  bg?: string;
  backgroundColor?: string;
  content?: string;
  bold?: boolean;
}

interface OpenTUIInputProps {
  style?: OpenTUIStyle;
  placeholder?: string;
  value?: string;
  focused?: boolean;
  onInput?: (value: string) => void;
  onChange?: (value: string) => void;
  onSubmit?: (value: string) => void;
}

declare module "react" {
  namespace JSX {
    interface IntrinsicElements {
      box: OpenTUIBoxProps;
      text: OpenTUITextProps;
      code: Record<string, unknown> & { children?: React.ReactNode };
      diff: Record<string, unknown> & { children?: React.ReactNode };
      input: OpenTUIInputProps;
      select: Record<string, unknown>;
      textarea: Record<string, unknown>;
      scrollbox: Record<string, unknown> & { children?: React.ReactNode };
      "ascii-font": Record<string, unknown>;
      "tab-select": Record<string, unknown>;
      "line-number": Record<string, unknown> & { children?: React.ReactNode };
      span: Record<string, unknown> & { children?: React.ReactNode };
      br: Record<string, unknown>;
      b: Record<string, unknown> & { children?: React.ReactNode };
      strong: Record<string, unknown> & { children?: React.ReactNode };
      i: Record<string, unknown> & { children?: React.ReactNode };
      em: Record<string, unknown> & { children?: React.ReactNode };
      u: Record<string, unknown> & { children?: React.ReactNode };
      a: Record<string, unknown> & { children?: React.ReactNode };
    }
  }
}
