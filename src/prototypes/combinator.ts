import { ENTITY_NAME } from '../scripts/constants';
import * as dataUtil from 'fcore/utils/data';

import * as util from 'util';

declare function make_4way_animation_from_spritesheet(arg: any): any;

const name = ENTITY_NAME;
const combi = dataUtil.copyPrototype(data.raw['constant-combinator']['constant-combinator']!, name);
combi.icon = '__cybersyn2-combinator__/graphics/cybersyn-combinator-icon.png';
combi.icon_size = 64;
combi.next_upgrade = undefined;
combi.fast_replaceable_group = 'constant-combinator';
combi.sprites = make_4way_animation_from_spritesheet({
  layers: [
    {
      filename: '__cybersyn2-combinator__/graphics/cybersyn-combinator-entity.png',
      scale: 0.5,
      width: 114,
      height: 102,
      shift: util.by_pixel(0, 5),
    },
    {
      filename: '__base__/graphics/entity/combinator/constant-combinator-shadow.png',
      scale: 0.5,
      width: 98,
      height: 66,
      shift: util.by_pixel(8.5, 5.5),
      draw_as_shadow: true,
    },
  ],
});

const combiItem = dataUtil.copyPrototype(data.raw.item['constant-combinator']!, name);
combiItem.icon = '__cybersyn2-combinator__/graphics/cybersyn-combinator-icon.png';
combiItem.icon_size = 64;
combiItem.subgroup = data.raw.item['train-stop']?.subgroup;
combiItem.place_result = name;

const combiRecipe = dataUtil.copyPrototype(data.raw.recipe['constant-combinator']!, name);
combiRecipe.ingredients = [
  { type: 'item', name: 'constant-combinator', amount: 1 },
  { type: 'item', name: 'electronic-circuit', amount: 1 },
];
combiRecipe.enabled = false;
combiRecipe.subgroup = data.raw.recipe['train-stop']?.subgroup;

const cybersynItem = data.raw.item['cybersyn2-combinator'];
const cybersynRecipe = data.raw.recipe['cybersyn2-combinator'];
if (cybersynItem && cybersynItem.order) {
  combiItem.order = cybersynItem.order + '-b';
} else {
  combiItem.order = (data.raw.item['constant-combinator']?.order || '') + '-b';
}

if (cybersynRecipe && cybersynRecipe.order) {
  combiRecipe.order = cybersynRecipe.order + '-b';
}

data.extend([combi, combiItem, combiRecipe]);

dataUtil.unlockRecipeWithTechnology(ENTITY_NAME, 'cybersyn2-train-network');
