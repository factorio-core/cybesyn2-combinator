import * as event from 'fcore/utils/event';
import { createRoot, registerComponent, createElement, destroyGuiElement } from 'fcore/react';
import { strace } from 'fcore/utils/strace';
import { GUI, modPrefix } from '../constants';
import { isCombinatorEntity } from './utils';
import { Main } from './components/main';

import type { OnGuiOpenedEvent, LuaEntity, PlayerIndex } from 'factorio:runtime';

export const GuiManager = {
  init(): void {
    registerComponent(GUI.MAIN_ELEMENT_NAME, Main);
    event.bind(defines.events.on_gui_opened, (ev: OnGuiOpenedEvent) => {
      const entity = ev.entity;
      if (entity?.valid && isCombinatorEntity(entity)) {
        const player = game.get_player(ev.player_index);
        if (player) {
          GuiManager.open(ev.player_index, entity);
        }
      }
    });
  },

  open(playerIndex: PlayerIndex, entity: LuaEntity): void {
    const player = game.get_player(playerIndex);
    if (!player || !entity?.valid) return;

    strace.debug(
      modPrefix,
      'gui',
      'open_window',
      'player',
      playerIndex,
      'unit_number',
      entity.unit_number,
    );
    createRoot(player.gui.screen, <Main entity={entity} playerIndex={playerIndex} />);
  },

  close(playerIndex: PlayerIndex): void {
    const player = game.get_player(playerIndex);
    if (!player) return;

    strace.debug(modPrefix, 'gui', 'close_window', 'player', playerIndex);
    const existing = player.gui.screen[GUI.MAIN_ELEMENT_NAME];
    destroyGuiElement(existing);
  },
};

export const gui = GuiManager;
