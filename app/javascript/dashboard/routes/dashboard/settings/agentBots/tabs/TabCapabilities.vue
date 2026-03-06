<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  form: { type: Object, required: true },
});

const { t } = useI18n();

const modules = computed(() => props.form.agent_behavior_config.modules);
const leadWarming = computed(() => props.form.agent_behavior_config.lead_warming);

const closingPhrasesText = computed({
  get() {
    return (leadWarming.value.closing_phrases || []).join('\n');
  },
  set(val) {
    leadWarming.value.closing_phrases = val.split('\n').map(s => s.trim()).filter(Boolean);
  },
});

const FALLBACK_STRATEGIES = [
  { value: 'provide_phone', labelKey: 'AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.FALLBACK_PHONE' },
  { value: 'transfer_advisor', labelKey: 'AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.FALLBACK_TRANSFER' },
  { value: 'show_hours', labelKey: 'AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.FALLBACK_HOURS' },
  { value: 'custom_message', labelKey: 'AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.FALLBACK_CUSTOM' },
];

const appointmentFallback = computed(() =>
  props.form.agent_behavior_config.module_fallbacks?.appointments ||
  modules.value.appointments?.fallback || {}
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex flex-col gap-1">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES_TITLE') }}
      </h3>
      <p class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES_HINT') }}</p>
    </div>

    <div class="flex flex-col divide-y divide-n-weak border border-n-weak rounded-xl overflow-hidden">
      <!-- General Response -->
      <div class="p-4 flex flex-col gap-1">
        <label class="flex items-center gap-3 cursor-pointer">
          <input
            v-model="modules.general_response.enabled"
            type="checkbox"
            class="accent-n-brand w-4 h-4"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.general_response.LABEL') }}
          </span>
        </label>
        <p class="text-xs text-n-slate-11 ml-7">
          {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.general_response.DESC') }}
        </p>
      </div>

      <!-- Transfer Chat -->
      <div class="p-4 flex flex-col gap-1">
        <label class="flex items-center gap-3 cursor-pointer">
          <input
            v-model="modules.transfer_chat.enabled"
            type="checkbox"
            class="accent-n-brand w-4 h-4"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.transfer_chat.LABEL') }}
          </span>
        </label>
        <p class="text-xs text-n-slate-11 ml-7">
          {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.transfer_chat.DESC') }}
        </p>
      </div>

      <!-- Appointments -->
      <div class="p-4 flex flex-col gap-3">
        <label class="flex items-center gap-3 cursor-pointer">
          <input
            v-model="modules.appointments.enabled"
            type="checkbox"
            class="accent-n-brand w-4 h-4"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.LABEL') }}
          </span>
        </label>
        <p class="text-xs text-n-slate-11 ml-7">
          {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.DESC') }}
        </p>

        <!-- Actions (when enabled) -->
        <div v-if="modules.appointments.enabled" class="ml-7 flex items-center gap-4">
          <span class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.ACTIONS_LABEL') }}:</span>
          <label class="flex items-center gap-1.5 text-xs text-n-slate-12 cursor-pointer">
            <input v-model="modules.appointments.actions.create" type="checkbox" class="accent-n-brand" />
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.ACTION_CREATE') }}
          </label>
          <label class="flex items-center gap-1.5 text-xs text-n-slate-12 cursor-pointer">
            <input v-model="modules.appointments.actions.reschedule" type="checkbox" class="accent-n-brand" />
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.ACTION_RESCHEDULE') }}
          </label>
          <label class="flex items-center gap-1.5 text-xs text-n-slate-12 cursor-pointer">
            <input v-model="modules.appointments.actions.cancel" type="checkbox" class="accent-n-brand" />
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.ACTION_CANCEL') }}
          </label>
        </div>

        <!-- Fallback (when disabled) -->
        <div v-if="!modules.appointments.enabled" class="ml-7 p-3 bg-n-amber-1 border border-n-amber-6 rounded-lg flex flex-col gap-3">
          <p class="text-xs font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.FALLBACK_TITLE') }}
          </p>
          <div class="flex flex-col gap-2">
            <label
              v-for="strategy in FALLBACK_STRATEGIES"
              :key="strategy.value"
              class="flex items-start gap-2 cursor-pointer"
            >
              <input
                type="radio"
                :value="strategy.value"
                :checked="appointmentFallback.strategy === strategy.value"
                class="accent-n-brand mt-0.5"
                @change="appointmentFallback.strategy = strategy.value"
              />
              <span class="text-xs text-n-slate-12">{{ $t(strategy.labelKey) }}</span>
            </label>
          </div>

          <input
            v-if="appointmentFallback.strategy === 'provide_phone'"
            v-model="appointmentFallback.phone_number"
            type="text"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            :placeholder="$t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.FALLBACK_PHONE_PLACEHOLDER')"
          />

          <textarea
            v-if="appointmentFallback.strategy === 'custom_message'"
            v-model="appointmentFallback.custom_message"
            rows="2"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
            :placeholder="$t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.appointments.FALLBACK_CUSTOM_PLACEHOLDER')"
          />
        </div>
      </div>

      <!-- Send Documents -->
      <div class="p-4 flex flex-col gap-3">
        <label class="flex items-center gap-3 cursor-pointer">
          <input
            v-model="modules.send_documents.enabled"
            type="checkbox"
            class="accent-n-brand w-4 h-4"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.send_documents.LABEL') }}
          </span>
        </label>
        <p class="text-xs text-n-slate-11 ml-7">
          {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.send_documents.DESC') }}
        </p>

        <div v-if="modules.send_documents.enabled" class="ml-7 flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.send_documents.TYPES_LABEL') }}:</span>
          <label class="flex items-center gap-1.5 text-xs text-n-slate-12 cursor-pointer">
            <input
              type="checkbox"
              :checked="modules.send_documents.allowed_types?.includes('pdf')"
              class="accent-n-brand"
              @change="e => {
                const types = modules.send_documents.allowed_types || [];
                modules.send_documents.allowed_types = e.target.checked
                  ? [...new Set([...types, 'pdf'])]
                  : types.filter(t => t !== 'pdf');
              }"
            />
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.send_documents.TYPE_PDF') }}
          </label>
          <label class="flex items-center gap-1.5 text-xs text-n-slate-12 cursor-pointer">
            <input
              type="checkbox"
              :checked="modules.send_documents.allowed_types?.includes('image')"
              class="accent-n-brand"
              @change="e => {
                const types = modules.send_documents.allowed_types || [];
                modules.send_documents.allowed_types = e.target.checked
                  ? [...new Set([...types, 'image'])]
                  : types.filter(t => t !== 'image');
              }"
            />
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.send_documents.TYPE_IMAGE') }}
          </label>
          <label class="flex items-center gap-1.5 text-xs text-n-slate-12 cursor-pointer">
            <input
              type="checkbox"
              :checked="modules.send_documents.allowed_types?.includes('video')"
              class="accent-n-brand"
              @change="e => {
                const types = modules.send_documents.allowed_types || [];
                modules.send_documents.allowed_types = e.target.checked
                  ? [...new Set([...types, 'video'])]
                  : types.filter(t => t !== 'video');
              }"
            />
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.send_documents.TYPE_VIDEO') }}
          </label>
        </div>
      </div>

      <!-- Out of Scope -->
      <div class="p-4 flex flex-col gap-3">
        <label class="flex items-center gap-3 cursor-pointer">
          <input
            v-model="modules.out_of_scope.enabled"
            type="checkbox"
            class="accent-n-brand w-4 h-4"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.out_of_scope.LABEL') }}
          </span>
        </label>
        <p class="text-xs text-n-slate-11 ml-7">
          {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.out_of_scope.DESC') }}
        </p>

        <div v-if="modules.out_of_scope.enabled" class="ml-7 flex items-center gap-3">
          <span class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.MODULES.out_of_scope.ATTEMPTS_LABEL') }}:</span>
          <input
            v-model.number="modules.out_of_scope.max_attempts"
            type="number"
            min="1"
            max="10"
            class="w-16 px-2 py-1 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand text-center"
          />
        </div>
      </div>
    </div>

    <!-- Lead Warming -->
    <div class="border border-n-weak rounded-xl p-4 flex flex-col gap-4">
      <h3 class="text-sm font-semibold text-n-slate-12">
        {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.LEAD_WARMING_TITLE') }}
      </h3>

      <label class="flex items-center gap-3 cursor-pointer">
        <input
          v-model="leadWarming.enabled"
          type="checkbox"
          class="accent-n-brand w-4 h-4"
        />
        <span class="text-sm text-n-slate-12">
          {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.LEAD_WARMING_ENABLED') }}
        </span>
      </label>

      <template v-if="leadWarming.enabled">
        <div class="flex items-center gap-3">
          <span class="text-sm text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.LEAD_WARMING_TURNS_LABEL') }}:</span>
          <input
            v-model.number="leadWarming.auto_suggest_after_turns"
            type="number"
            min="1"
            max="20"
            class="w-16 px-2 py-1 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand text-center"
          />
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm text-n-slate-11">
            {{ $t('AGENT_BOTS.CONFIG.CAPABILITIES.LEAD_WARMING_PHRASES_LABEL') }}
          </label>
          <textarea
            v-model="closingPhrasesText"
            rows="4"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
          />
        </div>
      </template>
    </div>
  </div>
</template>
