import { invoke, card } from "./shared.js";
import { createAiRenameRow } from "./ai-rename-row.js";
import { createAiProviderRow } from "./ai-provider-row.js";
import { createApiKeyRow } from "./api-key-row.js";
import { createAiLastResultRow } from "./ai-last-result-row.js";
import { createAiAlert } from "./ai-alert.js";
import { createAiInstructionsBlock } from "./ai-instructions-block.js";

/** Blocks of the "AI naming" page: an alert when something is wrong, the settings, the last result. */
export async function buildAiRenamePage() {
  const state = await invoke("get_ai_rename");
  const alert = createAiAlert();
  const keyRow = createApiKeyRow(state, {
    onFailure: (failure, provider) => alert.show(failure, provider),
    onSuccess: () => alert.hide(),
  });
  const providerRow = createAiProviderRow(state, (provider, hasKey) => {
    alert.hide();
    keyRow.show(provider, hasKey);
  });
  const result = createAiLastResultRow(state, (failure, provider) => alert.show(failure, provider));
  return [alert, card(createAiRenameRow(state), providerRow, keyRow, createAiInstructionsBlock(state)), result];
}
