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

export const PickerScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  return (
    <AbsoluteFill style={{backgroundColor: "#f8f9fc", overflow: "hidden"}}>
      <Interactive.Div
        name="Time-zone picker screenshot"
        style={{
          position: "absolute",
          inset: -24,
          scale: interpolate(frame, [0, durationInFrames - 1], [1.025, 1], {
            easing: Easing.bezier(0.16, 1, 0.3, 1),
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            output: "perceptual-scale",
          }),
          translate: interpolate(
            frame,
            [0, durationInFrames - 1],
            ["10px 0px", "-8px 0px"],
            {
              easing: Easing.bezier(0.16, 1, 0.3, 1),
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            },
          ),
        }}
      >
        <CanvasImage
          src={staticFile("02-add-six-time-zones.png")}
          style={{width: "100%", height: "100%", objectFit: "cover"}}
        />
      </Interactive.Div>
    </AbsoluteFill>
  );
};
