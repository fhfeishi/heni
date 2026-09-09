import { InterfaceIcon } from "../../components/InterfaceIcon";

interface ListeningViewSwitchProps {
  stage: boolean;
  onBrowse(): void;
  onStage(): void;
}

export const ListeningViewSwitch = ({ stage, onBrowse, onStage }: ListeningViewSwitchProps) => (
  <div className="workspace-switch" role="group" aria-label="聆听视图" data-stage={stage}
    onKeyDown={(event) => {
      const target = event.key === "ArrowLeft" || event.key === "Home" ? 0
        : event.key === "ArrowRight" || event.key === "End" ? 1 : null;
      if (target === null || event.altKey || event.ctrlKey || event.metaKey) return;
      event.preventDefault();
      event.currentTarget.querySelectorAll<HTMLButtonElement>("button")[target]?.focus();
      if (target === 0) onBrowse(); else onStage();
    }}>
    <button type="button" aria-pressed={!stage} onClick={onBrowse} title="返回歌曲浏览">
      <InterfaceIcon name="songs" /><span>歌曲</span>
    </button>
    <button type="button" aria-pressed={stage} onClick={onStage} aria-label="播放舞台" title="播放舞台">
      <InterfaceIcon name="stage" /><span>舞台</span>
    </button>
  </div>
);
