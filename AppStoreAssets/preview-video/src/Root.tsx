import "./index.css";
import {Composition, Folder} from "remotion";
import {AppPreview} from "./AppPreview";
import {BestTimeScene} from "./scenes/BestTimeScene";
import {OverviewScene} from "./scenes/OverviewScene";
import {PickerScene} from "./scenes/PickerScene";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Folder name="Scenes">
        <Composition
          id="OverviewScene"
          component={OverviewScene}
          durationInFrames={180}
          fps={30}
          width={1920}
          height={1080}
        />
        <Composition
          id="PickerScene"
          component={PickerScene}
          durationInFrames={150}
          fps={30}
          width={1920}
          height={1080}
        />
        <Composition
          id="BestTimeScene"
          component={BestTimeScene}
          durationInFrames={150}
          fps={30}
          width={1920}
          height={1080}
        />
      </Folder>
      <Composition
        id="ZonelyAppPreview"
        component={AppPreview}
        durationInFrames={450}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
