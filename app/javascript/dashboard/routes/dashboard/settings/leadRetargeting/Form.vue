<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import leadFollowUpSequencesAPI from 'dashboard/api/leadFollowUpSequences';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const store = useStore();
const getters = useStoreGetters();

const accountId = computed(() => getters.getCurrentAccountId.value);
const inboxes = computed(() =>
  getters['inboxes/getWhatsAppInboxes'].value
);

const loading = ref(false);
const availableTemplates = ref([]);
const sequence = ref({
  name: '',
  description: '',
  inbox_id: null,
  active: false,
  steps: [],
  settings: {
    stop_on_contact_reply: true,
    stop_on_conversation_resolved: true,
    respect_business_hours: false,
    business_hours: {
      start: '09:00',
      end: '18:00',
      timezone: 'America/Mexico_City',
    },
    max_retries_per_step: 2,
  },
});

const isEdit = computed(() => !!route.params.sequenceId);

const breadcrumbItems = computed(() => [
  {
    label: t('LEAD_RETARGETING.BREADCRUMB.BACK'),
  },
]);

const handleBreadcrumbClick = () => {
  router.push({ name: 'lead_retargeting_list' });
};

onMounted(async () => {
  await store.dispatch('inboxes/get');

  if (isEdit.value) {
    await fetchSequence();
  }
});

const fetchSequence = async () => {
  try {
    loading.value = true;
    const response = await leadFollowUpSequencesAPI.show(
      route.params.sequenceId
    );
    sequence.value = response.data;
    if (sequence.value.inbox_id) {
      await loadTemplates();
    }
  } catch (error) {
    useAlert(t('LEAD_RETARGETING.FORM.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const loadTemplates = async () => {
  if (!sequence.value.inbox_id) return;

  try {
    const response = await leadFollowUpSequencesAPI.getAvailableTemplates(
      sequence.value.inbox_id
    );
    availableTemplates.value = response.data.templates;
  } catch (error) {
    console.error('Failed to load templates:', error);
  }
};

watch(() => sequence.value.inbox_id, loadTemplates);

const addStep = type => {
  const stepId = `step_${Date.now()}`;

  const stepDefaults = {
    wait: {
      id: stepId,
      type: 'wait',
      name: t('LEAD_RETARGETING.STEPS.WAIT.DEFAULT_NAME'),
      enabled: true,
      config: {
        delay_type: 'hours',
        delay_value: 24,
      },
    },
    send_template: {
      id: stepId,
      type: 'send_template',
      name: t('LEAD_RETARGETING.STEPS.SEND_TEMPLATE.DEFAULT_NAME'),
      enabled: true,
      config: {
        template_name: '',
        language: 'es',
        template_params: {
          body: {},
        },
      },
    },
    add_label: {
      id: stepId,
      type: 'add_label',
      name: t('LEAD_RETARGETING.STEPS.ADD_LABEL.DEFAULT_NAME'),
      enabled: true,
      config: {
        labels: [],
      },
    },
  };

  sequence.value.steps.push(stepDefaults[type]);
};

const removeStep = index => {
  sequence.value.steps.splice(index, 1);
};

const moveStepUp = index => {
  if (index === 0) return;
  const steps = [...sequence.value.steps];
  [steps[index - 1], steps[index]] = [steps[index], steps[index - 1]];
  sequence.value.steps = steps;
};

const moveStepDown = index => {
  if (index === sequence.value.steps.length - 1) return;
  const steps = [...sequence.value.steps];
  [steps[index], steps[index + 1]] = [steps[index + 1], steps[index]];
  sequence.value.steps = steps;
};

const getTemplateParams = templateName => {
  const template = availableTemplates.value.find(t => t.name === templateName);
  if (!template) return [];

  const bodyComponent = template.components?.find(c => c.type === 'BODY');
  if (!bodyComponent || !bodyComponent.text) return [];

  const matches = bodyComponent.text.match(/\{\{(\d+)\}\}/g);
  return matches || [];
};

const onTemplateChange = step => {
  if (!step.config.template_params) {
    step.config.template_params = { body: {} };
  }

  // Find the selected template and set its language
  const selectedTemplate = availableTemplates.value.find(t => t.name === step.config.template_name);
  if (selectedTemplate) {
    step.config.language = selectedTemplate.language;
  }

  const params = getTemplateParams(step.config.template_name);
  const bodyParams = {};

  params.forEach((_, idx) => {
    bodyParams[idx + 1] = step.config.template_params.body?.[idx + 1] || '';
  });

  step.config.template_params.body = bodyParams;
};

const copyToClipboard = text => {
  navigator.clipboard.writeText(text);
  useAlert('Variable copiada al portapapeles');
};

const saveSequence = async () => {
  if (!sequence.value.name) {
    useAlert(t('LEAD_RETARGETING.FORM.NAME_REQUIRED'));
    return;
  }

  if (!sequence.value.inbox_id) {
    useAlert(t('LEAD_RETARGETING.FORM.INBOX_REQUIRED'));
    return;
  }

  try {
    loading.value = true;

    if (isEdit.value) {
      await leadFollowUpSequencesAPI.update(route.params.sequenceId, {
        lead_follow_up_sequence: sequence.value,
      });
      useAlert(t('LEAD_RETARGETING.FORM.UPDATE_SUCCESS'));
    } else {
      await leadFollowUpSequencesAPI.create({
        lead_follow_up_sequence: sequence.value,
      });
      useAlert(t('LEAD_RETARGETING.FORM.CREATE_SUCCESS'));
    }

    router.push({ name: 'lead_retargeting_list' });
  } catch (error) {
    useAlert(
      isEdit.value
        ? t('LEAD_RETARGETING.FORM.UPDATE_ERROR')
        : t('LEAD_RETARGETING.FORM.CREATE_ERROR')
    );
  } finally {
    loading.value = false;
  }
};

const cancel = () => {
  router.push({ name: 'lead_retargeting_list' });
};
</script>

<template>
  <SettingsLayout :is-loading="loading">
    <template #header>
      <div class="flex flex-col gap-4 w-full">
        <Breadcrumb :items="breadcrumbItems" @click="handleBreadcrumbClick" />
        <div class="flex items-center justify-between">
          <h2 class="text-2xl font-semibold text-slate-800 dark:text-slate-100">
            {{ isEdit ? t('LEAD_RETARGETING.FORM.EDIT_TITLE') : t('LEAD_RETARGETING.FORM.NEW_TITLE') }}
          </h2>
          <div class="flex gap-2">
            <Button
              slate
              :label="t('LEAD_RETARGETING.FORM.CANCEL')"
              @click="cancel"
            />
            <Button
              :is-loading="loading"
              :label="t('LEAD_RETARGETING.FORM.SAVE')"
              @click="saveSequence"
            />
          </div>
        </div>
      </div>
    </template>

    <template #body>
      <div class="max-w-4xl space-y-6">
        <!-- Basic Info -->
        <div class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-medium text-slate-800 dark:text-slate-100 mb-4">{{ t('LEAD_RETARGETING.FORM.BASIC_INFO') }}</h3>

          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                {{ t('LEAD_RETARGETING.FORM.NAME') }} *
              </label>
              <input
                v-model="sequence.name"
                type="text"
                class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
                :placeholder="t('LEAD_RETARGETING.FORM.NAME_PLACEHOLDER')"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                {{ t('LEAD_RETARGETING.FORM.DESCRIPTION') }}
              </label>
              <textarea
                v-model="sequence.description"
                rows="3"
                class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
                :placeholder="t('LEAD_RETARGETING.FORM.DESCRIPTION_PLACEHOLDER')"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                {{ t('LEAD_RETARGETING.FORM.INBOX') }} *
              </label>
              <select
                v-model="sequence.inbox_id"
                class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
              >
                <option :value="null">{{ t('LEAD_RETARGETING.FORM.SELECT_INBOX') }}</option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </div>
          </div>
        </div>

        <!-- Settings -->
        <div class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-medium text-slate-800 dark:text-slate-100 mb-4">{{ t('LEAD_RETARGETING.FORM.SETTINGS') }}</h3>

          <div class="space-y-3">
            <label class="flex items-center gap-2">
              <input
                v-model="sequence.settings.stop_on_contact_reply"
                type="checkbox"
                class="rounded"
              />
              <span class="text-sm text-slate-700 dark:text-slate-300">{{ t('LEAD_RETARGETING.FORM.STOP_ON_REPLY') }}</span>
            </label>

            <label class="flex items-center gap-2">
              <input
                v-model="sequence.settings.stop_on_conversation_resolved"
                type="checkbox"
                class="rounded"
              />
              <span class="text-sm text-slate-700 dark:text-slate-300">{{ t('LEAD_RETARGETING.FORM.STOP_ON_RESOLVED') }}</span>
            </label>

            <label class="flex items-center gap-2">
              <input
                v-model="sequence.active"
                type="checkbox"
                class="rounded"
              />
              <span class="text-sm font-medium text-slate-700 dark:text-slate-300">{{ t('LEAD_RETARGETING.FORM.ACTIVATE') }}</span>
            </label>
          </div>
        </div>

        <!-- Steps -->
        <div class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-slate-800 dark:text-slate-100">{{ t('LEAD_RETARGETING.FORM.STEPS') }}</h3>
            <div class="flex gap-2">
              <Button
                xs
                slate
                :label="'+ ' + t('LEAD_RETARGETING.STEPS.WAIT.ADD')"
                @click="addStep('wait')"
              />
              <Button
                xs
                slate
                :label="'+ ' + t('LEAD_RETARGETING.STEPS.SEND_TEMPLATE.ADD')"
                :disabled="!sequence.inbox_id"
                @click="addStep('send_template')"
              />
              <Button
                xs
                slate
                :label="'+ ' + t('LEAD_RETARGETING.STEPS.ADD_LABEL.ADD')"
                @click="addStep('add_label')"
              />
            </div>
          </div>

          <div v-if="sequence.steps.length === 0" class="text-center py-8 text-slate-500 dark:text-slate-400">
            {{ t('LEAD_RETARGETING.FORM.NO_STEPS') }}
          </div>

          <div v-else class="space-y-3">
            <div
              v-for="(step, index) in sequence.steps"
              :key="step.id"
              class="border border-slate-200 dark:border-slate-700 rounded-lg p-4"
            >
              <div class="flex items-start gap-4">
                <div class="flex flex-col gap-1">
                  <button
                    type="button"
                    :disabled="index === 0"
                    class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 disabled:opacity-30"
                    @click="moveStepUp(index)"
                  >
                    <i class="icon ion-chevron-up" />
                  </button>
                  <span class="text-sm font-medium text-slate-600 dark:text-slate-400">{{ index + 1 }}</span>
                  <button
                    type="button"
                    :disabled="index === sequence.steps.length - 1"
                    class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 disabled:opacity-30"
                    @click="moveStepDown(index)"
                  >
                    <i class="icon ion-chevron-down" />
                  </button>
                </div>

                <div class="flex-1">
                  <input
                    v-model="step.name"
                    type="text"
                    class="w-full px-3 py-2 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 mb-3"
                    :placeholder="t('LEAD_RETARGETING.FORM.STEP_NAME')"
                  />

                  <!-- Wait Step -->
                  <div v-if="step.type === 'wait'" class="flex gap-2 items-center">
                    <span class="text-sm text-slate-700 dark:text-slate-300">{{ t('LEAD_RETARGETING.STEPS.WAIT.LABEL') }}</span>
                    <input
                      v-model.number="step.config.delay_value"
                      type="number"
                      min="1"
                      class="w-20 px-2 py-1 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
                    />
                    <select
                      v-model="step.config.delay_type"
                      class="px-2 py-1 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
                    >
                      <option value="minutes">{{ t('LEAD_RETARGETING.STEPS.WAIT.MINUTES') }}</option>
                      <option value="hours">{{ t('LEAD_RETARGETING.STEPS.WAIT.HOURS') }}</option>
                      <option value="days">{{ t('LEAD_RETARGETING.STEPS.WAIT.DAYS') }}</option>
                    </select>
                  </div>

                  <!-- Send Template Step -->
                  <div v-else-if="step.type === 'send_template'" class="space-y-3">
                    <div>
                      <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">Template</label>
                      <select
                        v-model="step.config.template_name"
                        class="w-full px-2 py-1 border border-slate-300 dark:border-slate-600 rounded text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
                        @change="onTemplateChange(step)"
                      >
                        <option value="">{{ t('LEAD_RETARGETING.STEPS.SEND_TEMPLATE.SELECT') }}</option>
                        <option
                          v-for="template in availableTemplates"
                          :key="`${template.name}-${template.language}`"
                          :value="template.name"
                        >
                          {{ template.name }} ({{ template.language }})
                        </option>
                      </select>
                    </div>

                    <!-- Template Parameters -->
                    <div v-if="step.config.template_name && getTemplateParams(step.config.template_name).length > 0" class="space-y-2 p-3 bg-slate-50 dark:bg-slate-900 rounded">
                      <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-2">Parámetros del Template</label>
                      <div
                        v-for="(param, idx) in getTemplateParams(step.config.template_name)"
                        :key="idx"
                        class="flex items-center gap-2"
                      >
                        <span class="text-xs text-slate-600 dark:text-slate-400 w-16">{{ '{' + '{' + (idx + 1) + '}' + '}' }}:</span>
                        <input
                          v-model="step.config.template_params.body[idx + 1]"
                          type="text"
                          class="flex-1 px-2 py-1 border border-slate-300 dark:border-slate-600 rounded text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
                          :placeholder="`Valor para parámetro ${idx + 1}`"
                        />
                      </div>
                      <div class="mt-2 p-2 bg-blue-50 dark:bg-blue-900/20 rounded text-xs">
                        <p class="font-medium text-slate-700 dark:text-slate-300 mb-1">Variables disponibles:</p>
                        <div class="flex flex-wrap gap-2">
                          <code
                            v-for="variable in ['contact.name', 'contact.email', 'contact.phone_number']"
                            :key="variable"
                            class="px-2 py-0.5 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded cursor-pointer hover:bg-blue-100 dark:hover:bg-blue-900/40 text-slate-700 dark:text-slate-300"
                            @click="copyToClipboard(`{{${variable}}}`)"
                          >
                            {{ '{' + '{' + variable + '}' + '}' }}
                          </code>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Add Label Step -->
                  <div v-else-if="step.type === 'add_label'" class="space-y-2">
                    <input
                      v-model="step.config.labels[0]"
                      type="text"
                      class="w-full px-2 py-1 border border-slate-300 dark:border-slate-600 rounded bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100"
                      :placeholder="t('LEAD_RETARGETING.STEPS.ADD_LABEL.PLACEHOLDER')"
                    />
                  </div>
                </div>

                <button
                  type="button"
                  class="text-red-600 dark:text-red-400 hover:text-red-800 dark:hover:text-red-300"
                  @click="removeStep(index)"
                >
                  <i class="icon ion-close-circled text-xl" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
