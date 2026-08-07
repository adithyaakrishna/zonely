import {TransitionSeries, linearTiming} from "@remotion/transitions";
import {fade} from "@remotion/transitions/fade";
import {BestTimeScene} from "./scenes/BestTimeScene";
import {OverviewScene} from "./scenes/OverviewScene";
import {PickerScene} from "./scenes/PickerScene";

export const AppPreview: React.FC = () => {
  return (
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={180} name="Overview">
        <OverviewScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({durationInFrames: 15})}
      />
      <TransitionSeries.Sequence durationInFrames={150} name="Time-zone picker">
        <PickerScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({durationInFrames: 15})}
      />
      <TransitionSeries.Sequence durationInFrames={150} name="Best time">
        <BestTimeScene />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  );
};
