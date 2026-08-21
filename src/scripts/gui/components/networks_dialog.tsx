import { createElement } from 'fcore/react';
import type { SignalID } from 'factorio:runtime';
import {
  SlotButton,
  SlotButtonTable,
  VFlow,
  Label,
  ShallowSection,
  ScrollPane,
} from 'fcore/react-components';
import { getAllGlobalActiveNetworks } from '../networks';
import { CAPTIONS } from '../../constants';

const C = CAPTIONS;

export interface NetworksDialogProps {
  onSelectNetwork?: (this: void, signal: SignalID | undefined, count: number) => void;
}

export function NetworksDialog(props: NetworksDialogProps) {
  const onSelectNetwork = props.onSelectNetwork;
  const networksData = getAllGlobalActiveNetworks();

  const netButtons: any[] = [];
  let i = 0;
  for (const dataNet of networksData) {
    netButtons.push(
      <SlotButton
        key={`net-${i++}`}
        signal={dataNet.signal}
        count={dataNet.count}
        locked={true}
        onClick={() => {
          if (onSelectNetwork) onSelectNetwork(dataNet.signal, dataNet.count);
        }}
      />,
    );
  }

  return (
    <ShallowSection styles={{ top_margin: 6 }}>
      <VFlow>
        <Label style="caption_label" caption={C.ACTIVE_GLOBAL_NETWORKS} />
        {netButtons.length > 0 ? (
          <ScrollPane
            style="scroll_pane"
            vertical_scroll_policy="auto"
            horizontal_scroll_policy="never"
            styles={{ minimal_height: 44, maximal_height: 180, horizontally_stretchable: true }}
          >
            <VFlow styles={{ horizontal_align: 'center', horizontally_stretchable: true }}>
              <SlotButtonTable column_count={8}>{netButtons}</SlotButtonTable>
            </VFlow>
          </ScrollPane>
        ) : (
          <Label style="caption_label" caption={C.NO_ACTIVE_NETWORKS} />
        )}
      </VFlow>
    </ShallowSection>
  );
}
