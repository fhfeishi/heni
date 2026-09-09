import { InterfaceIcon } from "../../components/InterfaceIcon";

interface DraftActionsProps {
  dirty: boolean;
  saveLabel: string;
  cancelLabel: string;
  onSave(): void;
  onCancel(): void;
  reset?: { label: string; disabled?: boolean; onClick(): void };
}

/** Icons stay decorative; each action retains its precise accessible name. */
export const DraftActions = ({ dirty, saveLabel, cancelLabel, onSave, onCancel, reset }: DraftActionsProps) => (
  <div className="scenery-control__actions draft-actions">
    <button type="button" disabled={!dirty} onClick={onSave} aria-label={saveLabel} title={saveLabel}>
      <InterfaceIcon name="check" />
    </button>
    <button type="button" disabled={!dirty} onClick={onCancel} aria-label={cancelLabel} title={cancelLabel}>
      <InterfaceIcon name="close" />
    </button>
    {reset !== undefined && (
      <button type="button" disabled={reset.disabled} onClick={reset.onClick} aria-label={reset.label} title={reset.label}>
        <InterfaceIcon name="reset" />
      </button>
    )}
  </div>
);
