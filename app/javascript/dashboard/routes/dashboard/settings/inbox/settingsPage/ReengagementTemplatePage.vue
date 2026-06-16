<script setup>
import { reactive, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import SectionLayout from 'dashboard/routes/dashboard/settings/account/components/SectionLayout.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { computed } from 'vue';

const WHATSAPP_TEMPLATE_LANGUAGES = [
  { label: 'Spanish (Mexico) — es_MX', value: 'es_MX' },
  { label: 'Spanish (Spain) — es_ES', value: 'es_ES' },
  { label: 'English (US) — en_US', value: 'en_US' },
  { label: 'English (UK) — en_GB', value: 'en_GB' },
  { label: 'Portuguese (Brazil) — pt_BR', value: 'pt_BR' },
  { label: 'Portuguese (Portugal) — pt_PT', value: 'pt_PT' },
  { label: 'French — fr', value: 'fr' },
  { label: 'German — de', value: 'de' },
  { label: 'Italian — it', value: 'it' },
  { label: 'Dutch — nl', value: 'nl' },
  { label: 'Russian — ru', value: 'ru' },
  { label: 'Arabic — ar', value: 'ar' },
  { label: 'Chinese (Simplified) — zh_CN', value: 'zh_CN' },
  { label: 'Japanese — ja', value: 'ja' },
  { label: 'Korean — ko', value: 'ko' },
];

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();

const isUpdating = ref(false);
const templateStatus = ref(null);
const templateLoading = ref(false);

const DEFAULT_MESSAGE =
  'Hola {{1}}, ha pasado un tiempo desde nuestra última conversación. ' +
  'Si tienes alguna duda o necesitas ayuda, estamos aquí para ti. ' +
  '¿En qué podemos asistirte hoy?';

const state = reactive({
  message: DEFAULT_MESSAGE,
  language: 'es_MX',
});

const originalValues = ref({ message: DEFAULT_MESSAGE, language: 'es_MX' });

const languageOptions = computed(() => WHATSAPP_TEMPLATE_LANGUAGES);

const shouldShowTemplateStatus = computed(
  () => templateStatus.value && !templateLoading.value
);

const templateApprovalStatus = computed(() => {
  const statusMap = {
    APPROVED: {
      text: t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TEMPLATE_STATUS.APPROVED'),
      icon: 'i-lucide-circle-check',
      color: 'text-n-teal-11',
    },
    PENDING: {
      text: t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TEMPLATE_STATUS.PENDING'),
      icon: 'i-lucide-clock',
      color: 'text-n-amber-11',
    },
    REJECTED: {
      text: t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TEMPLATE_STATUS.REJECTED'),
      icon: 'i-lucide-circle-x',
      color: 'text-n-ruby-10',
    },
  };

  if (templateStatus.value?.error === 'TEMPLATE_NOT_FOUND') {
    return {
      text: t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TEMPLATE_STATUS.NOT_FOUND'),
      icon: 'i-lucide-alert-triangle',
      color: 'text-n-ruby-10',
    };
  }

  if (templateStatus.value?.template_exists && templateStatus.value.status) {
    const normalizedStatus = templateStatus.value.status.toUpperCase();
    return statusMap[normalizedStatus] || statusMap.PENDING;
  }

  return {
    text: t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TEMPLATE_STATUS.DEFAULT'),
    icon: 'i-lucide-stamp',
    color: 'text-n-slate-11',
  };
});

const hasExistingTemplate = () => {
  const { template_exists, error } = templateStatus.value || {};
  return template_exists && !error;
};

const hasTemplateChanges = () => {
  return (
    originalValues.value.message !== state.message ||
    originalValues.value.language !== state.language
  );
};

const shouldCreateTemplate = () => {
  if (!hasExistingTemplate()) return true;
  return hasTemplateChanges();
};

const initializeState = () => {
  if (!props.inbox) return;

  const config = props.inbox.reengagement_config || {};
  if (config.message) state.message = config.message;
  if (config.language) state.language = config.language;

  originalValues.value = { message: state.message, language: state.language };
};

const checkTemplateStatus = async () => {
  try {
    templateLoading.value = true;
    const response = await store.dispatch(
      'inboxes/getReengagementTemplateStatus',
      { inboxId: props.inbox.id }
    );

    if (!response.template_exists && response.error === 'Template not found') {
      templateStatus.value = { template_exists: false, error: 'TEMPLATE_NOT_FOUND' };
    } else {
      templateStatus.value = response;
    }
  } catch {
    templateStatus.value = { template_exists: false, error: 'API_ERROR' };
  } finally {
    templateLoading.value = false;
  }
};

onMounted(() => {
  initializeState();
  checkTemplateStatus();
});

watch(() => props.inbox, initializeState, { immediate: true });

const saveSettings = async () => {
  if (!shouldCreateTemplate()) {
    useAlert(t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.API.NO_CHANGES'));
    return;
  }

  try {
    isUpdating.value = true;

    await store.dispatch('inboxes/createReengagementTemplate', {
      inboxId: props.inbox.id,
      template: { message: state.message, language: state.language },
    });

    useAlert(t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TEMPLATE_CREATION.SUCCESS_MESSAGE'));
    originalValues.value = { message: state.message, language: state.language };
    await checkTemplateStatus();
  } catch (error) {
    const errorMessage =
      error.response?.data?.error ||
      t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TEMPLATE_CREATION.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    isUpdating.value = false;
  }
};
</script>

<template>
  <div class="mx-8">
    <SectionLayout
      :title="$t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.TITLE')"
      :description="$t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.DESCRIPTION')"
    >
      <div class="grid gap-5">
        <WithLabel
          :label="$t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.MESSAGE.LABEL')"
          name="reengagement_message"
        >
          <Editor
            v-model="state.message"
            :placeholder="$t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.MESSAGE.PLACEHOLDER')"
            :max-length="1024"
            channel-type="Context::Plain"
            class="w-full"
          />
        </WithLabel>

        <WithLabel
          :label="$t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.LANGUAGE.LABEL')"
          name="reengagement_language"
        >
          <ComboBox
            v-model="state.language"
            :options="languageOptions"
            :placeholder="$t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.LANGUAGE.PLACEHOLDER')"
          />
        </WithLabel>

        <div
          v-if="shouldShowTemplateStatus"
          class="flex gap-2 items-center"
        >
          <Icon
            :icon="templateApprovalStatus.icon"
            :class="templateApprovalStatus.color"
            class="size-4"
          />
          <span :class="templateApprovalStatus.color" class="text-sm font-medium">
            {{ templateApprovalStatus.text }}
          </span>
        </div>

        <p class="text-sm italic text-n-slate-11">
          {{ $t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.NOTE') }}
        </p>

        <div>
          <NextButton
            type="button"
            :label="hasExistingTemplate()
              ? $t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.UPDATE_BUTTON')
              : $t('INBOX_MGMT.REENGAGEMENT_TEMPLATE.CREATE_BUTTON')"
            :is-loading="isUpdating"
            @click="saveSettings"
          />
        </div>
      </div>
    </SectionLayout>
  </div>
</template>
