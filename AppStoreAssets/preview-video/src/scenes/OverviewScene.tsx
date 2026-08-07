import {
  AbsoluteFill,
  CanvasImage,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

export const OverviewScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  return (
    <AbsoluteFill style={{backgroundColor: "#f8f9fc", overflow: "hidden"}}>
      <Interactive.Div
        name="Every time zone screenshot"
        style={{
          position: "absolute",
          inset: -24,
          scale: interpolate(frame, [0, durationInFrames - 1], [1.035, 1], {
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            output: "perceptual-scale",
          }),
          translate: interpolate(
            frame,
            [0, durationInFrames - 1],
            ["-12px 0px", "0px 0px"],
            {
              easing: Easing.bezier(0.16, 1, 0.3, 1),
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            },
          ),
        }}
      >
        <CanvasImage
          src={staticFile("01-every-time-zone.png")}
          style={{width: "100%", height: "100%", objectFit: "cover"}}
        />
      </Interactive.Div>
    </AbsoluteFill>
  );
};
