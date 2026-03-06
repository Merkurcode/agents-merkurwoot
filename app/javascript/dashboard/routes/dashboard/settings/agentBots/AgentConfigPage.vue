<script setup>
import { ref, computed, reactive, watch, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabGeneral from './tabs/TabGeneral.vue';
import TabAssistant from './tabs/TabAssistant.vue';
import TabModel from './tabs/TabModel.vue';
import TabCapabilities from './tabs/TabCapabilities.vue';
import TabTools from './tabs/TabTools.vue';
import TabContent from './tabs/TabContent.vue';

const store = useStore();
const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const uiFlags = useMapGetter('agentBots/getUIFlags');
const getBot = useMapGetter('agentBots/getBot');

const botId = computed(() => Number(route.params.botId));
const bot = computed(() => getBot.value(botId.value));

const activeTabIndex = ref(0);

const tabs = computed(() => [
  { label: t('AGENT_BOTS.CONFIG.TABS.GENERAL') },
  { label: t('AGENT_BOTS.CONFIG.TABS.ASSISTANT') },
  { label: t('AGENT_BOTS.CONFIG.TABS.MODEL') },
  { label: t('AGENT_BOTS.CONFIG.TABS.CAPABILITIES') },
  { label: t('AGENT_BOTS.CONFIG.TABS.TOOLS') },
  { label: t('AGENT_BOTS.CONFIG.TABS.CONTENT') },
]);

const defaultBehaviorConfig = () => ({
  industry_sector_type: 'automotive',
  response: {
    model_name: 'gpt-4o-mini',
    temperature: 0.4,
    response_word_limit: '50-70',
    max_context_tokens: 800,
  },
  modules: {
    general_response: { enabled: true },
    transfer_chat: { enabled: true },
    appointments: {
      enabled: false,
      actions: { create: true, reschedule: true, cancel: true },
      fallback: { strategy: 'transfer_advisor', phone_number: null, custom_message: null },
    },
    send_documents: { enabled: true, allowed_types: ['pdf', 'image'] },
    out_of_scope: { enabled: true, max_attempts: 3 },
  },
  tools: {
    search_product_info: { enabled: true, score_threshold: 0.75, top_k: 10, examples: [], custom_instructions: '' },
    get_all_products: { enabled: true, listing_mode: 'all', max_results: 0, show_prices_by_default: false, examples: [], custom_instructions: '' },
    get_faqs: { enabled: true, per_page: 8, examples: [], custom_instructions: '' },
    get_marketing_campaigns: { enabled: true, examples: [], custom_instructions: '' },
    get_kb_resources: { enabled: false, examples: [], custom_instructions: '' },
    send_document: { enabled: true, sources: ['catalog'], allowed_types: ['pdf', 'image'], examples: [], custom_instructions: '' },
    transfer_chat: { enabled: true, examples: [], custom_instructions: '' },
  },
  lead_warming: { enabled: true, auto_suggest_after_turns: 5, closing_phrases: [] },
  module_fallbacks: {
    appointments: { strategy: 'transfer_advisor', phone_number: null, custom_message: null },
  },
  qualification_questions: [],
  additional_instructions: '',
});

const defaultAssistantConfig = () => ({
  preset: '',
  name: '',
  title: '',
  personality: '',
  tone: '',
  goal: '',
  speaking_style: '',
  inspiration: '',
});

const formState = reactive({
  name: '',
  description: '',
  outgoing_url: '',
  assistant_config: defaultAssistantConfig(),
  agent_behavior_config: defaultBehaviorConfig(),
});

const initForm = () => {
  const b = bot.value;
  if (!b || !b.id) return;

  formState.name = b.name || '';
  formState.description = b.description || '';
  formState.outgoing_url = b.outgoing_url || b.bot_config?.webhook_url || '';

  const ac = b.assistant_config || {};
  Object.assign(formState.assistant_config, defaultAssistantConfig(), ac);

  const abc = b.agent_behavior_config || {};
  const defaults = defaultBehaviorConfig();
  formState.agent_behavior_config.industry_sector_type = abc.industry_sector_type ?? defaults.industry_sector_type;

  if (abc.response) Object.assign(formState.agent_behavior_config.response, abc.response);
  if (abc.modules) {
    Object.keys(abc.modules).forEach(key => {
      if (formState.agent_behavior_config.modules[key]) {
        Object.assign(formState.agent_behavior_config.modules[key], abc.modules[key]);
      } else {
        formState.agent_behavior_config.modules[key] = abc.modules[key];
      }
    });
  }
  if (abc.tools) {
    Object.keys(abc.tools).forEach(key => {
      if (formState.agent_behavior_config.tools[key]) {
        Object.assign(formState.agent_behavior_config.tools[key], abc.tools[key]);
      } else {
        formState.agent_behavior_config.tools[key] = abc.tools[key];
      }
    });
  }
  if (abc.lead_warming) Object.assign(formState.agent_behavior_config.lead_warming, abc.lead_warming);
  if (abc.module_fallbacks) Object.assign(formState.agent_behavior_config.module_fallbacks, abc.module_fallbacks);
  if (abc.qualification_questions) formState.agent_behavior_config.qualification_questions = [...abc.qualification_questions];
  if (abc.additional_instructions !== undefined) formState.agent_behavior_config.additional_instructions = abc.additional_instructions;
};

watch(bot, initForm, { deep: true });

const onTabChanged = tab => {
  activeTabIndex.value = tabs.value.findIndex(t => t.label === tab.label);
};

const handleSave = async () => {
  const result = await store.dispatch('agentBots/updateConfig', {
    id: botId.value,
    data: {
      name: formState.name,
      description: formState.description,
      outgoing_url: formState.outgoing_url,
      assistant_config: formState.assistant_config,
      agent_behavior_config: formState.agent_behavior_config,
    },
  });
  if (result) useAlert(t('AGENT_BOTS.CONFIG.SUCCESS_MESSAGE'));
  else useAlert(t('AGENT_BOTS.CONFIG.ERROR_MESSAGE'));
};

const goBack = () => router.push({ name: 'ai_agents' });

onMounted(async () => {
  await store.dispatch('agentBots/show', botId.value);
  initForm();
});
</script>

<template>
  <div class="flex flex-col w-full gap-6">
    <div v-if="uiFlags.isFetchingItem" class="flex items-center justify-center py-20">
      <Spinner />
    </div>

    <template v-else>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <Button
            icon="i-lucide-arrow-left"
            slate
            faded
            xs
            @click="goBack"
          />
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ $t('AGENT_BOTS.CONFIG.TITLE', { name: formState.name }) }}
          </h1>
        </div>
        <Button
          :label="$t('AGENT_BOTS.CONFIG.SAVE')"
          :is-loading="uiFlags.isUpdating"
          @click="handleSave"
        />
      </div>

      <TabBar
        :tabs="tabs"
        :initial-active-tab="activeTabIndex"
        @tab-changed="onTabChanged"
      />

      <div class="flex flex-col gap-6 max-w-3xl">
        <TabGeneral v-if="activeTabIndex === 0" :form="formState" />
        <TabAssistant v-else-if="activeTabIndex === 1" :form="formState" />
        <TabModel v-else-if="activeTabIndex === 2" :form="formState" />
        <TabCapabilities v-else-if="activeTabIndex === 3" :form="formState" />
        <TabTools v-else-if="activeTabIndex === 4" :form="formState" />
        <TabContent v-else-if="activeTabIndex === 5" :form="formState" />
      </div>
    </template>
  </div>
</template>
