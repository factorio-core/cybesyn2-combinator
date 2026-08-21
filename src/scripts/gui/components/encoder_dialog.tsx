import { createElement } from 'fcore/react';
import {
  Button,
  VFlow,
  HFlow,
  Label,
  ShallowSection,
  SlotButtonTable,
} from 'fcore/react-components';
import { toInt32 } from '../utils';
import { CAPTIONS } from '../../constants';

const C = CAPTIONS;

export interface EncoderDialogProps {
  mask?: NetworkMask;
  onChangeMask?: (this: void, mask: NetworkMask) => void;
}

interface BitButtonProps {
  key?: string;
  bit: number;
  isSet: boolean;
  onClick: (this: void) => void;
}

function BitButton(props: BitButtonProps) {
  return (
    <Button
      caption={tostring(props.bit)}
      style={
        props.isSet
          ? 'react_selected_standalone_slot_button_grey'
          : 'react_standalone_slot_button_grey'
      }
      styles={{ width: 36, height: 36 }}
      onClick={props.onClick}
    />
  );
}

export function EncoderDialog(props: EncoderDialogProps) {
  const mask = toInt32(props.mask || 0);
  const onChangeMask = props.onChangeMask;

  const bitButtons: any[] = [];
  for (let bit = 0; bit < 32; bit++) {
    const currentBit = bit;
    const isSet = (mask & (1 << currentBit)) !== 0;
    bitButtons.push(
      <BitButton
        key={`bit-${currentBit}`}
        bit={currentBit}
        isSet={isSet}
        onClick={() => {
          const newMask = mask ^ (1 << currentBit);
          if (onChangeMask) onChangeMask(newMask);
        }}
      />,
    );
  }

  return (
    <ShallowSection styles={{ top_margin: 6 }}>
      <VFlow>
        <SlotButtonTable column_count={8}>{bitButtons}</SlotButtonTable>
        <HFlow styles={{ vertical_align: 'center', top_margin: 4 }}>
          <Button
            caption={C.ENCODER_ALL}
            onClick={() => {
              if (onChangeMask) onChangeMask(0xffffffff);
            }}
          />
          <Button
            caption={C.ENCODER_NONE}
            onClick={() => {
              if (onChangeMask) onChangeMask(0);
            }}
          />
        </HFlow>
      </VFlow>
    </ShallowSection>
  );
}
