<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  form: { type: Object, required: true },
});

const { t } = useI18n();

const MODELS = ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'claude-sonnet-4-6'];

const WORD_LIMIT_OPTIONS = [
  { value: '20-40', key: 'short' },
  { value: '50-70', key: 'standard' },
  { value: '80-120', key: 'detailed' },
  { value: 'unlimited', key: 'unlimited' },
];
</script>

<template>
  <div class="flex flex-col gap-8">
    <!-- Model selector -->
    <div class="flex flex-col gap-3">
      <label class="text-sm font-medium text-n-slate-12">
        {{ $t('AGENT_BOTS.CONFIG.MODEL.MODEL_LABEL') }}
      </label>
      <div class="flex flex-col gap-2">
        <label
          v-for="model in MODELS"
          :key="model"
          class="flex items-center gap-3 px-3 py-2.5 rounded-lg border cursor-pointer transition-colors"
          :class="
            form.agent_behavior_config.response.model_name === model
              ? 'border-n-brand bg-n-blue-1'
              : 'border-n-weak hover:bg-n-alpha-1'
          "
        >
          <input
            type="radio"
            :value="model"
            :checked="form.agent_behavior_config.response.model_name === model"
            class="accent-n-brand"
            @change="form.agent_behavior_config.response.model_name = model"
          />
          <span class="text-sm text-n-slate-12">
            {{ $t(`AGENT_BOTS.CONFIG.MODEL.MODELS.${model}`) }}
          </span>
        </label>
      </div>
    </div>

    <div class="border-t border-n-weak" />

    <!-- Temperature -->
    <div class="flex flex-col gap-3">
      <div class="flex items-center justify-between">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_BOTS.CONFIG.MODEL.TEMPERATURE_LABEL') }}
        </label>
        <span class="text-sm font-semibold text-n-brand">
          {{ form.agent_behavior_config.response.temperature }}
        </span>
      </div>
      <input
        type="range"
        min="0"
        max="1"
        step="0.1"
        :value="form.agent_behavior_config.response.temperature"
        class="w-full accent-n-brand"
        @input="e => (form.agent_behavior_config.response.temperature = parseFloat(e.target.value))"
      />
      <div class="flex justify-between text-xs text-n-slate-10">
        <span>0.0 — {{ $t('AGENT_BOTS.CONFIG.MODEL.TEMPERATURE_HINT_LOW') }}</span>
        <span>1.0 — {{ $t('AGENT_BOTS.CONFIG.MODEL.TEMPERATURE_HINT_HIGH') }}</span>
      </div>
      <p class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.MODEL.TEMPERATURE_DESC') }}</p>
    </div>

    <div class="border-t border-n-weak" />

    <!-- Word limit -->
    <div class="flex flex-col gap-3">
      <label class="text-sm font-medium text-n-slate-12">
        {{ $t('AGENT_BOTS.CONFIG.MODEL.WORD_LIMIT_LABEL') }}
      </label>
      <div class="flex flex-col gap-2">
        <label
          v-for="opt in WORD_LIMIT_OPTIONS"
          :key="opt.value"
          class="flex items-center gap-3 px-3 py-2.5 rounded-lg border cursor-pointer transition-colors"
          :class="
            form.agent_behavior_config.response.response_word_limit === opt.value
              ? 'border-n-brand bg-n-blue-1'
              : 'border-n-weak hover:bg-n-alpha-1'
          "
        >
          <input
            type="radio"
            :value="opt.value"
            :checked="form.agent_behavior_config.response.response_word_limit === opt.value"
            class="accent-n-brand"
            @change="form.agent_behavior_config.response.response_word_limit = opt.value"
          />
          <span class="text-sm text-n-slate-12">
            {{ $t(`AGENT_BOTS.CONFIG.MODEL.WORD_LIMIT_OPTIONS.${opt.key}`) }}
          </span>
        </label>
      </div>
      <p class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.MODEL.WORD_LIMIT_HINT') }}</p>
    </div>

    <div class="border-t border-n-weak" />

    <!-- Max context tokens -->
    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ $t('AGENT_BOTS.CONFIG.MODEL.MAX_TOKENS_LABEL') }}
      </label>
      <input
        type="number"
        :value="form.agent_behavior_config.response.max_context_tokens"
        min="100"
        max="8000"
        step="100"
        class="w-32 px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        @input="e => (form.agent_behavior_config.response.max_context_tokens = parseInt(e.target.value))"
      />
      <p class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.MODEL.MAX_TOKENS_HINT') }}</p>
    </div>
  </div>
</template>
