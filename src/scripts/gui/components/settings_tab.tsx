import { createElement, useState } from 'fcore/react';
import {
  Checkbox,
  Input,
  Button,
  RadioButton,
  SlotButton,
  VFlow,
  HFlow,
  Label,
  ShallowSection,
  WellFold,
  ScrollPane,
} from 'fcore/react-components';
import { strace } from 'fcore/utils/strace';
import { Combinator, type NetworkMask } from '../../models/combinator';
import { PlayerSettings } from '../../models/player_settings';
import { CAPTIONS, INPUT_MODE, ENTITY_NAME, SETTINGS, modPrefix } from '../../constants';
import { EncoderDialog } from './encoder_dialog';
import type { SignalID, PlayerIndex } from 'factorio:runtime';

const C = CAPTIONS;

export interface SettingsTabProps {
  playerIndex: PlayerIndex;
  combinator: Combinator;
}

export function SettingsTab(props: SettingsTabProps) {
  const playerIndex = props.playerIndex;
  const player = typeof game !== 'undefined' && game ? game.get_player(playerIndex) : undefined;
  const isAdmin = player?.admin ?? false;

  const [draft, setDraft] = useState<Partial<PlayerSettingsData>>(() => ({
    ...PlayerSettings.get(playerIndex),
  }));

  const [encoderOpen, setEncoderOpen] = useState(false);

  // Admin Batch Replacement States
  const [oldPriority, setOldPriority] = useState<number>(
    () => draft.priority ?? SETTINGS.DEFAULT_PRIORITY,
  );
  const [newPriority, setNewPriority] = useState<number>(
    () => draft.priority ?? SETTINGS.DEFAULT_PRIORITY,
  );

  const [oldNetSignal, setOldNetSignal] = useState<SignalID | undefined>(
    () => draft.defaultNetworkSignal ?? SETTINGS.DEFAULT_NETWORK_SIGNAL,
  );
  const [oldNetFlag, setOldNetFlag] = useState<number>(
    () => draft.networkFlag ?? SETTINGS.DEFAULT_NETWORK_FLAG,
  );

  const [newNetSignal, setNewNetSignal] = useState<SignalID | undefined>(
    () => draft.defaultNetworkSignal ?? SETTINGS.DEFAULT_NETWORK_SIGNAL,
  );
  const [newNetFlag, setNewNetFlag] = useState<number>(
    () => draft.networkFlag ?? SETTINGS.DEFAULT_NETWORK_FLAG,
  );

  const [oldEncoderOpen, setOldEncoderOpen] = useState(false);
  const [newEncoderOpen, setNewEncoderOpen] = useState(false);

  const updateDraft = (patch: Partial<PlayerSettingsData>) => {
    setDraft((prev: any) => ({ ...prev, ...patch }));
  };

  const handleSave = () => {
    strace.info(
      modPrefix,
      'settings',
      'save_player_settings',
      'player',
      playerIndex,
      'draft',
      draft,
    );
    PlayerSettings.set(playerIndex, draft);

    setNewPriority(draft.priority ?? SETTINGS.DEFAULT_PRIORITY);
    setNewNetSignal(draft.defaultNetworkSignal ?? SETTINGS.DEFAULT_NETWORK_SIGNAL);
    setNewNetFlag(draft.networkFlag ?? SETTINGS.DEFAULT_NETWORK_FLAG);

    if (player && player.valid) {
      player.create_local_flying_text({
        text: 'Settings saved!',
        create_at_cursor: true,
      });
    }
  };

  const handleCancel = () => {
    const saved = PlayerSettings.get(playerIndex);
    setDraft({ ...saved });
    if (player && player.valid) {
      player.create_local_flying_text({
        text: 'Settings reset',
        create_at_cursor: true,
      });
    }
  };

  const handleApplyPriority = () => {
    if (!isAdmin) return;
    const count = Combinator.applyPriorityToAll(oldPriority, newPriority);
    if (player && player.valid) {
      player.print(
        `[${ENTITY_NAME}] Replaced priority (${oldPriority} -> ${newPriority}) on ${count} combinator(s).`,
      );
    }
  };

  const handleApplyNetwork = () => {
    if (!isAdmin) return;
    const count = Combinator.applyNetworkToAll(oldNetSignal, oldNetFlag, newNetSignal, newNetFlag);
    if (player && player.valid) {
      player.print(
        `[${ENTITY_NAME}] Replaced network mask (${oldNetSignal?.name || 'none'}:${oldNetFlag} -> ${newNetSignal?.name || 'none'}:${newNetFlag}) on ${count} combinator(s).`,
      );
    }
  };

  return (
    <ScrollPane
      style="naked_scroll_pane"
      vertical_scroll_policy="auto"
      horizontal_scroll_policy="never"
      styles={{
        horizontally_stretchable: true,
        extra_right_padding_when_activated: 4,
      }}
    >
      <VFlow styles={{ horizontally_stretchable: true }}>
        {/* 1. Player Settings */}
        <ShallowSection>
          <VFlow>
            <Label style="caption_label" caption={C.PLAYER_SETTINGS} />

            <Checkbox
              caption={C.NEGATIVE_SIGNALS}
              state={draft.negativeSignals ?? true}
              onChange={(val) => {
                updateDraft({ negativeSignals: val });
              }}
            />

            <Checkbox
              caption={C.AUTO_QUERY_PRIORITIES}
              state={draft.autoQueryPriorities ?? true}
              onChange={(val) => {
                updateDraft({ autoQueryPriorities: val });
              }}
            />

            <Label caption={C.DEFAULT_PRIORITY} styles={{ top_margin: 6 }} />
            <Input
              text={tostring(draft.priority ?? 10)}
              numeric={true}
              allow_negative={true}
              styles={{ width: 100 }}
              onChange={(val) => {
                updateDraft({ priority: tonumber(val) || 0 });
              }}
            />

            <Label caption={C.DEFAULT_NETWORK_SIGNAL} styles={{ top_margin: 6 }} />
            <SlotButton
              signal={draft.defaultNetworkSignal}
              onChange={(sig: SignalID | undefined) => {
                if (sig && sig.name) {
                  updateDraft({ defaultNetworkSignal: sig });
                }
              }}
            />

            <Label caption={C.DEFAULT_NETWORK_MASK} styles={{ top_margin: 6 }} />
            <HFlow styles={{ vertical_align: 'center' }}>
              <Input
                text={tostring(draft.networkFlag ?? 1)}
                numeric={true}
                allow_negative={true}
                styles={{ width: 100 }}
                onChange={(val) => {
                  updateDraft({ networkFlag: tonumber(val) || 0 });
                }}
              />
              <Button
                caption={encoderOpen ? C.CLOSE_ENCODER : C.OPEN_ENCODER}
                style="button"
                onClick={() => setEncoderOpen(!encoderOpen)}
              />
            </HFlow>

            {encoderOpen && (
              <EncoderDialog
                mask={draft.networkFlag}
                onChangeMask={(newMask: NetworkMask) => {
                  updateDraft({ networkFlag: newMask });
                }}
              />
            )}

            <Label caption={C.DEFAULT_STACKS} styles={{ top_margin: 6 }} />
            <Input
              text={tostring(draft.stacks ?? 0)}
              numeric={true}
              allow_negative={true}
              styles={{ width: 100 }}
              onChange={(val) => {
                updateDraft({ stacks: tonumber(val) || 0 });
              }}
            />

            <Label caption={C.DEFAULT_COUNT} styles={{ top_margin: 6 }} />
            <Input
              text={tostring(draft.count ?? 0)}
              numeric={true}
              allow_negative={true}
              styles={{ width: 100 }}
              onChange={(val) => {
                updateDraft({ count: tonumber(val) || 0 });
              }}
            />

            <Label
              style="caption_label"
              caption={C.DEFAULT_INPUT_MODE}
              styles={{ top_margin: 6 }}
            />

            <VFlow>
              <RadioButton
                caption={C.INPUT_MODE_COUNTS}
                state={draft.defaultInputMode === INPUT_MODE.COUNT}
                onCheckedStateChanged={() => {
                  updateDraft({ defaultInputMode: INPUT_MODE.COUNT });
                }}
              />
              <RadioButton
                caption={C.INPUT_MODE_STACKS}
                state={draft.defaultInputMode === INPUT_MODE.STACKS}
                onCheckedStateChanged={() => {
                  updateDraft({ defaultInputMode: INPUT_MODE.STACKS });
                }}
              />
            </VFlow>

            <HFlow styles={{ top_margin: 12 }}>
              <Button
                caption={C.SAVE_SETTINGS}
                style="confirm_button"
                styles={{ width: 150, height: 30 }}
                onClick={handleSave}
              />
              <Button
                caption={C.CANCEL}
                style="button"
                styles={{ width: 150, height: 30 }}
                onClick={handleCancel}
              />
            </HFlow>
          </VFlow>
        </ShallowSection>

        {/* 2. Admin Batch Replace */}
        {isAdmin && (
          <WellFold
            caption={C.ADMIN_BATCH_REPLACE}
            defaultCollapsed={true}
            styles={{ top_margin: 8 }}
          >
            <VFlow>
              <Label
                style="caption_label"
                caption={C.REPLACE_PRIORITY_TITLE}
                styles={{ top_margin: 6 }}
              />
              <HFlow styles={{ vertical_align: 'center' }}>
                <Label caption={C.OLD_PRIORITY} />
                <Input
                  text={tostring(oldPriority)}
                  numeric={true}
                  allow_negative={true}
                  styles={{ width: 70 }}
                  onChange={(val) => setOldPriority(tonumber(val) ?? 0)}
                />
                <Label
                  caption="➔"
                  styles={{ font: 'default-bold', left_margin: 4, right_margin: 4 }}
                />
                <Label caption={C.NEW_PRIORITY} />
                <Input
                  text={tostring(newPriority)}
                  numeric={true}
                  allow_negative={true}
                  styles={{ width: 70 }}
                  onChange={(val) => setNewPriority(tonumber(val) ?? 0)}
                />
              </HFlow>
              <Button
                caption={C.APPLY_PRIORITY_BTN}
                style="confirm_button"
                styles={{ top_margin: 4, width: 180, height: 28 }}
                onClick={handleApplyPriority}
              />

              <Label
                style="caption_label"
                caption={C.REPLACE_NETWORK_TITLE}
                styles={{ top_margin: 10 }}
              />
              <VFlow>
                {/* Old Network */}
                <HFlow styles={{ vertical_align: 'center' }}>
                  <Label caption={C.OLD_NETWORK} styles={{ width: 70 }} />
                  <SlotButton signal={oldNetSignal} onChange={(sig) => setOldNetSignal(sig)} />
                  <Input
                    text={tostring(oldNetFlag)}
                    numeric={true}
                    allow_negative={true}
                    styles={{ width: 70 }}
                    onChange={(val) => setOldNetFlag(tonumber(val) ?? 0)}
                  />
                  <Button
                    caption={oldEncoderOpen ? C.CLOSE_ENCODER : C.OPEN_ENCODER}
                    style="button"
                    onClick={() => {
                      setOldEncoderOpen(!oldEncoderOpen);
                      setNewEncoderOpen(false);
                    }}
                  />
                </HFlow>

                {oldEncoderOpen && (
                  <EncoderDialog mask={oldNetFlag} onChangeMask={(mask) => setOldNetFlag(mask)} />
                )}

                {/* New Network */}
                <HFlow styles={{ vertical_align: 'center', top_margin: 4 }}>
                  <Label caption={C.NEW_NETWORK} styles={{ width: 70 }} />
                  <SlotButton signal={newNetSignal} onChange={(sig) => setNewNetSignal(sig)} />
                  <Input
                    text={tostring(newNetFlag)}
                    numeric={true}
                    allow_negative={true}
                    styles={{ width: 70 }}
                    onChange={(val) => setNewNetFlag(tonumber(val) ?? 0)}
                  />
                  <Button
                    caption={newEncoderOpen ? C.CLOSE_ENCODER : C.OPEN_ENCODER}
                    style="button"
                    onClick={() => {
                      setNewEncoderOpen(!newEncoderOpen);
                      setOldEncoderOpen(false);
                    }}
                  />
                </HFlow>

                {newEncoderOpen && (
                  <EncoderDialog mask={newNetFlag} onChangeMask={(mask) => setNewNetFlag(mask)} />
                )}

                <Button
                  caption={C.APPLY_NETWORK_BTN}
                  style="confirm_button"
                  styles={{ top_margin: 6, width: 180, height: 28 }}
                  onClick={handleApplyNetwork}
                />
              </VFlow>
            </VFlow>
          </WellFold>
        )}
      </VFlow>
    </ScrollPane>
  );
}
