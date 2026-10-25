import { FR_COMMON } from "./fr-common.js";
import { FR_POPOVER } from "./fr-popover.js";
import { FR_SETTINGS } from "./fr-settings.js";
import { FR_AI } from "./fr-ai.js";

/** French, keyed by the English text (see `t` in `i18n.js`). */
export const FR = { ...FR_COMMON, ...FR_POPOVER, ...FR_SETTINGS, ...FR_AI };
