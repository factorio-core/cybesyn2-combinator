import {
  createElement,
  useState,
  useMemo,
  useEntityLifecycle,
  registerComponent,
} from 'fcore/react';
import type { LuaEntity, PlayerIndex } from 'factorio:runtime';
import { WindowFrame, TabbedPane, Tab } from 'fcore/react-components';
import { Combinator } from '../../models/combinator';
import { CAPTIONS, GUI } from '../../constants';
import { CombinatorTab } from './combinator_tab';
import { SettingsTab } from './settings_tab';

const C = CAPTIONS;

export interface MainProps {
  playerIndex: PlayerIndex;
  entity: LuaEntity;
}

export function Main(props: MainProps): any {
  const playerIndex = props.playerIndex;

  const [entity, setEntity] = useState<LuaEntity | undefined>(() => props.entity);

  useEntityLifecycle(entity, {
    onDestroyed: () => {
      setEntity(undefined);
    },
    onRevived: (newEntity) => {
      setEntity(newEntity);
    },
  });

  const comb = useMemo(
    () => (entity && entity.valid ? new Combinator(entity) : undefined),
    [entity],
  );

  if (!entity || !entity.valid || !comb) return undefined;

  return (
    <WindowFrame
      name={GUI.MAIN_ELEMENT_NAME}
      caption={C.TITLE}
      playerIndex={playerIndex}
      pinnable={true}
      styles={{ maximal_width: 470, minimal_width: 455, maximal_height: 900, minimal_height: 600 }}
    >
      <TabbedPane>
        <Tab caption={C.TAB_COMBINATOR}>
          <CombinatorTab playerIndex={playerIndex} combinator={comb} />
        </Tab>
        <Tab caption={C.TAB_SETTINGS}>
          <SettingsTab playerIndex={playerIndex} combinator={comb} />
        </Tab>
      </TabbedPane>
    </WindowFrame>
  );
}

registerComponent(GUI.MAIN_ELEMENT_NAME, Main);
