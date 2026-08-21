import * as event from 'fcore/utils/event';
import { bootstrapReact } from 'fcore/react';
import { strace } from 'fcore/utils/strace';
import { GuiManager } from './scripts/gui/init';
import { isCombinatorEntity } from './scripts/gui/utils';
import { Combinator } from './scripts/models/combinator';
import { GUI, modPrefix } from './scripts/constants';

import type {
  OnBuiltEntityEvent,
  OnRobotBuiltEntityEvent,
  OnSpacePlatformBuiltEntityEvent,
  ScriptRaisedBuiltEvent,
  ScriptRaisedReviveEvent,
  OnEntitySettingsPastedEvent,
  PlayerIndex,
} from 'factorio:runtime';

bootstrapReact();
GuiManager.init();

event.onEntityCreated(undefined, ({ entity, tags, playerIndex }) => {
  if (!isCombinatorEntity(entity)) return;

  strace.info(
    modPrefix,
    'entity',
    'built_or_revived',
    'unit_number',
    entity.unit_number,
    'name',
    entity.name,
  );
  const comb = new Combinator(entity);
  const isFromBlueprint = tags !== undefined && (tags as any).from_blueprint === true;
  comb.initializeDefaults(isFromBlueprint, playerIndex);
});

// destroyed entity checks moved to useEntityLifecycle

event.bind(defines.events.on_entity_settings_pasted, (ev: OnEntitySettingsPastedEvent) => {
  const src = ev.source;
  const dest = ev.destination;
  if (src && src.valid && dest && dest.valid && isCombinatorEntity(dest)) {
    strace.info(
      modPrefix,
      'entity',
      'settings_pasted',
      'src',
      src.unit_number,
      'dest',
      dest.unit_number,
    );
    const destComb = new Combinator(dest);
    if (isCombinatorEntity(src)) {
      const srcComb = new Combinator(src);
      destComb.copyFrom(srcComb);
    } else {
      destComb.fixPastedVanillaSections(ev.player_index);
    }
    const player = game.get_player(ev.player_index);
    const opened = player?.opened as any;
    if (opened && opened.valid && opened.name === GUI.MAIN_ELEMENT_NAME) {
      GuiManager.open(ev.player_index, dest);
    }
  }
});
