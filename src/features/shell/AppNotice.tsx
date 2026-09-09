import { useId } from "react";

import type {
  AppErrorPresentation,
  AppRecoveryAction,
} from "./appErrorPresentation";

export interface AppNoticeProps {
  presentation: AppErrorPresentation;
  onAction(action: AppRecoveryAction): void;
  onClose(): void;
}

export const AppNotice = ({
  presentation,
  onAction,
  onClose,
}: AppNoticeProps) => {
  const titleId = useId();
  const messageId = useId();
  const action = presentation.action;

  return (
    <div
      className="app-notice"
      role="alert"
      aria-labelledby={titleId}
      aria-describedby={messageId}
    >
      <span className="app-notice__mark" aria-hidden="true">
        !
      </span>
      <div className="app-notice__copy">
        <strong id={titleId}>{presentation.title}</strong>
        <span id={messageId}>{presentation.message}</span>
      </div>
      <div className="app-notice__actions">
        {action !== undefined && (
          <button
            type="button"
            className="app-notice__primary-action"
            onClick={() => onAction(action.kind)}
          >
            {action.label}
          </button>
        )}
        <button type="button" aria-label="关闭错误提示" onClick={onClose}>
          关闭
        </button>
      </div>
    </div>
  );
};
