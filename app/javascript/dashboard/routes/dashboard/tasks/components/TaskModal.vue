<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { debounce } from '@chatwoot/utils';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import CaptainAssistantAPI from 'dashboard/api/captain/assistant';
import ContactAPI from 'dashboard/api/contacts';
import ConversationAPI from 'dashboard/api/conversations';
import InboxMembersAPI from 'dashboard/api/inboxMembers';

const props = defineProps({
  task: { type: Object, default: null },
  onClose: { type: Function, required: true },
});

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const isEditMode = computed(() => !!props.task);
const isSubmitting = ref(false);
const aiAgents = ref([]);

const getInitialAssignee = () => {
  if (props.task?.assignee_id) return `h:${props.task.assignee_id}`;
  if (props.task?.ai_agent_id) return `a:${props.task.ai_agent_id}`;
  return null;
};
const selectedAssignee = ref(getInitialAssignee());

const contacts = computed(() => {
  const list = getters['contacts/getContacts'].value || [];
  return (Array.isArray(list) ? list : Object.values(list)).filter(c => c && c.id);
});

const conversationSearchOptions = ref([]);
const isSearchingConversations = ref(false);
const conversationInboxMap = ref({});
const assignConversationAgentOptions = ref([]);
const isLoadingAssignAgents = ref(false);

const searchConversationsByContact = debounce(async query => {
  if (!query || query.length < 2) {
    conversationSearchOptions.value = [];
    return;
  }
  isSearchingConversations.value = true;
  try {
    const { data } = await ContactAPI.search(query, 1);
    const foundContacts = data?.payload || [];
    const results = await Promise.all(
      foundContacts.slice(0, 5).map(async contact => {
        const { data: convData } = await ContactAPI.getConversations(contact.id);
        return (convData?.payload || []).map(c => {
          conversationInboxMap.value[c.id] = c.inbox_id;
          return { value: c.id, label: `#${c.id} — ${contact.name}` };
        });
      })
    );
    conversationSearchOptions.value = results.flat();
  } finally {
    isSearchingConversations.value = false;
  }
}, 400);

const agents = computed(() => getters['agents/getAgents'].value || []);

const actionTypeOptions = [
  { value: 'general', label: t('TASKS.ACTION_TYPE.GENERAL') },
  { value: 'schedule_appointment', label: t('TASKS.ACTION_TYPE.SCHEDULE_APPOINTMENT') },
  { value: 'send_message', label: t('TASKS.ACTION_TYPE.SEND_MESSAGE') },
  { value: 'assign_conversation', label: t('TASKS.ACTION_TYPE.ASSIGN_CONVERSATION') },
];

const appointmentTypeOptions = [
  { value: 'phone_call', label: t('APPOINTMENTS.TYPE.PHONE_CALL') },
  { value: 'digital_meeting', label: t('APPOINTMENTS.TYPE.DIGITAL_MEETING') },
  { value: 'physical_visit', label: t('APPOINTMENTS.TYPE.PHYSICAL_VISIT') },
];

const toLocalDatetime = utcString => {
  if (!utcString) return '';
  const d = new Date(utcString);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

const existingConfig = props.task?.execution_config || {};
const existingApptData = existingConfig.appointment_data || {};
const existingAssignData = existingConfig.assign_conversation_data || {};

const sendMessageConversationId = ref(
  props.task?.action_type === 'send_message' && props.task?.entity_type === 'Conversation'
    ? props.task.entity_id
    : null
);

const formData = ref({
  title: props.task?.title || '',
  description: props.task?.description || '',
  action_type: props.task?.action_type || 'general',
  scheduled_at: toLocalDatetime(props.task?.scheduled_at),
  execution_config: {
    assign_conversation_data: {
      conversation_id: existingAssignData.conversation_id || null,
      assignee_id: existingAssignData.assignee_id || null,
    },
    appointment_data: {
      contact_id: existingApptData.contact_id || null,
      appointment_type: existingApptData.appointment_type || 'phone_call',
      scheduled_at: existingApptData.scheduled_at || '',
      owner_id: existingApptData.owner_id || null,
      phone_number: existingApptData.phone_number || '',
      meeting_url: existingApptData.meeting_url || '',
      location: existingApptData.location || '',
    },
  },
});

const combinedAssigneeOptions = computed(() => [
  ...agents.value.map(a => ({ value: `h:${a.id}`, label: `${a.name} (Agent)` })),
  ...aiAgents.value.map(a => ({ value: `a:${a.id}`, label: `${a.name} (AI)` })),
]);

const contactOptions = computed(() =>
  contacts.value.map(c => ({
    value: c.id,
    label: [c.name, c.email || c.phone_number].filter(Boolean).join(' — '),
  }))
);

const agentOptions = computed(() =>
  agents.value.map(a => ({ value: a.id, label: a.name }))
);

const showScheduleAppointment = computed(() =>
  formData.value.action_type === 'schedule_appointment'
);

const showMessageContent = computed(() =>
  formData.value.action_type === 'send_message'
);

const showSendMessageConversation = computed(() =>
  formData.value.action_type === 'send_message'
);

const showAssignConversation = computed(() =>
  formData.value.action_type === 'assign_conversation'
);


const apptType = computed(
  () => formData.value.execution_config.appointment_data.appointment_type
);

store.dispatch('agents/get');
store.dispatch('contacts/get');
CaptainAssistantAPI.get().then(({ data }) => {
  aiAgents.value = data?.payload || [];
});



watch(
  () => formData.value.execution_config.assign_conversation_data.conversation_id,
  async (conversationId, oldConversationId) => {
    if (oldConversationId !== undefined) {
      formData.value.execution_config.assign_conversation_data.assignee_id = null;
    }
    assignConversationAgentOptions.value = [];
    if (!conversationId) return;
    isLoadingAssignAgents.value = true;
    try {
      let inboxId = conversationInboxMap.value[conversationId];
      if (!inboxId) {
        const { data } = await ConversationAPI.show(conversationId);
        inboxId = data?.inbox_id;
      }
      if (!inboxId) return;
      const { data } = await InboxMembersAPI.show(inboxId);
      assignConversationAgentOptions.value = (data?.payload || []).map(a => ({
        value: a.id,
        label: a.name,
      }));
    } finally {
      isLoadingAssignAgents.value = false;
    }
  },
  { immediate: true }
);

watch(apptType, newType => {
  const data = formData.value.execution_config.appointment_data;
  data.phone_number = '';
  data.meeting_url = '';
  data.location = '';
  if (newType === 'phone_call' && data.contact_id) {
    const contact = contacts.value.find(c => c.id === data.contact_id);
    if (contact?.phone_number) data.phone_number = contact.phone_number;
  }
});

const isValidForm = computed(
  () => !!formData.value.title.trim() && !!formData.value.scheduled_at
);

async function handleSubmit() {
  if (!isValidForm.value) {
    useAlert(t('TASKS.MODAL.VALIDATION_ERROR'));
    return;
  }

  isSubmitting.value = true;
  try {
    let assignee_id = null;
    let ai_agent_id = null;
    if (selectedAssignee.value) {
      const [type, id] = selectedAssignee.value.split(':');
      if (type === 'h') assignee_id = Number(id);
      else ai_agent_id = Number(id);
    }

    const payload = {
      task: {
        title: formData.value.title,
        description: formData.value.description,
        action_type: formData.value.action_type,
        scheduled_at: formData.value.scheduled_at
          ? new Date(formData.value.scheduled_at).toISOString()
          : null,
        assignee_id,
        ai_agent_id,
        execution_config: formData.value.execution_config,
        ...(formData.value.action_type === 'send_message' && sendMessageConversationId.value
          ? { entity_type: 'Conversation', entity_id: sendMessageConversationId.value }
          : {}),
      },
    };

    if (isEditMode.value) {
      await store.dispatch('tasks/update', {
        id: props.task.id,
        ...payload.task,
      });
      useAlert(t('TASKS.EDIT.SUCCESS'));
    } else {
      await store.dispatch('tasks/create', payload);
      useAlert(t('TASKS.CREATE.SUCCESS'));
    }

    props.onClose();
  } catch (error) {
    const message =
      error.response?.data?.message || error.response?.data?.error;
    useAlert(
      message ||
        (isEditMode.value ? t('TASKS.EDIT.ERROR') : t('TASKS.CREATE.ERROR'))
    );
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEditMode
          ? $t('TASKS.MODAL.EDIT_TITLE')
          : $t('TASKS.MODAL.CREATE_TITLE')
      "
    />

    <form class="w-full" @submit.prevent="handleSubmit">
      <div class="w-full flex flex-col gap-4 max-h-[60vh] overflow-y-auto">
        <!-- Title -->
        <div class="w-full">
          <label>
            {{ $t('TASKS.MODAL.TITLE') }}
            <span class="text-red-500">*</span>
            <input
              v-model="formData.title"
              type="text"
              :placeholder="$t('TASKS.MODAL.TITLE_PLACEHOLDER')"
            />
          </label>
        </div>

        <!-- Description -->
        <div class="w-full">
          <label>
            {{ $t('TASKS.MODAL.DESCRIPTION') }}
            <textarea
              v-model="formData.description"
              rows="3"
              :placeholder="$t('TASKS.MODAL.DESCRIPTION_PLACEHOLDER')"
            />
          </label>
        </div>

        <!-- Assignee -->
        <div class="w-full">
          <label>
            {{ $t('TASKS.MODAL.ASSIGNEE') }}
            <ComboBox
              v-model="selectedAssignee"
              :options="combinedAssigneeOptions"
              :placeholder="$t('TASKS.MODAL.SELECT_ASSIGNEE')"
            />
          </label>
        </div>


        <!-- Scheduled at -->
        <div class="w-full">
          <label>
            {{ $t('TASKS.MODAL.SCHEDULED_AT') }}
            <span class="text-red-500">*</span>
            <input
              v-model="formData.scheduled_at"
              type="datetime-local"
            />
          </label>
        </div>

        <!-- Action Type (at the end) -->
        <div class="w-full">
          <label>
            {{ $t('TASKS.MODAL.ACTION_TYPE') }}
            <select v-model="formData.action_type">
              <option
                v-for="opt in actionTypeOptions"
                :key="opt.value"
                :value="opt.value"
              >
                {{ opt.label }}
              </option>
            </select>
          </label>
        </div>

        <!-- Schedule Appointment sub-form -->
        <template v-if="showScheduleAppointment">
          <div class="w-full">
            <label>
              {{ $t('APPOINTMENTS.MODAL.CONTACT') }}
              <span class="text-red-500">*</span>
              <ComboBox
                v-model="formData.execution_config.appointment_data.contact_id"
                :options="contactOptions"
                :placeholder="$t('APPOINTMENTS.MODAL.SELECT_CONTACT')"
              />
            </label>
          </div>

          <div class="w-full">
            <label>
              {{ $t('APPOINTMENTS.MODAL.APPOINTMENT_TYPE') }}
              <span class="text-red-500">*</span>
              <select v-model="formData.execution_config.appointment_data.appointment_type">
                <option
                  v-for="opt in appointmentTypeOptions"
                  :key="opt.value"
                  :value="opt.value"
                >
                  {{ opt.label }}
                </option>
              </select>
            </label>
          </div>

          <div class="w-full">
            <label>
              {{ $t('APPOINTMENTS.MODAL.SCHEDULED_AT') }}
              <span class="text-red-500">*</span>
              <input
                v-model="formData.execution_config.appointment_data.scheduled_at"
                type="datetime-local"
              />
            </label>
          </div>

          <div class="w-full">
            <label>
              {{ $t('APPOINTMENTS.MODAL.OWNER') }}
              <span class="text-red-500">*</span>
              <ComboBox
                v-model="formData.execution_config.appointment_data.owner_id"
                :options="agentOptions"
                :placeholder="$t('APPOINTMENTS.MODAL.SELECT_OWNER')"
              />
            </label>
          </div>

          <div v-if="apptType === 'phone_call'" class="w-full">
            <label>
              {{ $t('APPOINTMENTS.MODAL.PHONE_NUMBER') }}
              <span class="text-red-500">*</span>
              <input
                v-model="formData.execution_config.appointment_data.phone_number"
                type="tel"
                :placeholder="$t('APPOINTMENTS.MODAL.PHONE_PLACEHOLDER')"
              />
            </label>
          </div>

          <div v-if="apptType === 'digital_meeting'" class="w-full">
            <label>
              {{ $t('APPOINTMENTS.MODAL.MEETING_URL') }}
              <span class="text-red-500">*</span>
              <input
                v-model="formData.execution_config.appointment_data.meeting_url"
                type="url"
                :placeholder="$t('APPOINTMENTS.MODAL.MEETING_URL_PLACEHOLDER')"
              />
            </label>
          </div>

          <div v-if="apptType === 'physical_visit'" class="w-full">
            <label>
              {{ $t('APPOINTMENTS.MODAL.LOCATION') }}
              <span class="text-red-500">*</span>
              <input
                v-model="formData.execution_config.appointment_data.location"
                type="text"
                :placeholder="$t('APPOINTMENTS.MODAL.LOCATION_PLACEHOLDER')"
              />
            </label>
          </div>
        </template>

        <!-- Assign Conversation sub-form -->
        <template v-if="showAssignConversation">
          <div class="w-full">
            <label>
              {{ $t('TASKS.MODAL.CONVERSATION') }}
              <span class="text-red-500">*</span>
              <ComboBox
                v-model="formData.execution_config.assign_conversation_data.conversation_id"
                :options="conversationSearchOptions"
                :placeholder="$t('TASKS.MODAL.SEARCH_CONVERSATION_BY_CONTACT')"
                use-api-results
                @search="searchConversationsByContact"
              />
            </label>
            <p v-if="isSearchingConversations" class="text-xs text-n-slate-9 mt-1">
              {{ $t('TASKS.MODAL.LOADING_ENTITIES') }}
            </p>
          </div>

          <div class="w-full">
            <label>
              {{ $t('TASKS.MODAL.ASSIGN_TO_AGENT') }}
              <span class="text-red-500">*</span>
              <ComboBox
                v-model="formData.execution_config.assign_conversation_data.assignee_id"
                :options="assignConversationAgentOptions"
                :placeholder="isLoadingAssignAgents ? $t('TASKS.MODAL.LOADING_ENTITIES') : $t('TASKS.MODAL.SELECT_ASSIGNEE')"
                :disabled="!formData.execution_config.assign_conversation_data.conversation_id || isLoadingAssignAgents"
              />
            </label>
          </div>
        </template>

        <!-- Send message: conversation selector -->
        <template v-if="showSendMessageConversation">
          <div class="w-full">
            <label>
              {{ $t('TASKS.MODAL.CONVERSATION') }}
              <span class="text-red-500">*</span>
              <ComboBox
                v-model="sendMessageConversationId"
                :options="conversationSearchOptions"
                :placeholder="$t('TASKS.MODAL.SEARCH_CONVERSATION_BY_CONTACT')"
                use-api-results
                @search="searchConversationsByContact"
              />
            </label>
            <p v-if="isSearchingConversations" class="text-xs text-n-slate-9 mt-1">
              {{ $t('TASKS.MODAL.LOADING_ENTITIES') }}
            </p>
          </div>
        </template>

        <!-- Send message -->
        <div v-if="showMessageContent" class="w-full">
          <label>
            {{ $t('TASKS.MODAL.MESSAGE_CONTENT') }}
            <textarea
              v-model="formData.execution_config.message_content"
              rows="3"
              :placeholder="$t('TASKS.MODAL.MESSAGE_CONTENT_PLACEHOLDER')"
            />
          </label>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="button"
          :label="$t('TASKS.MODAL.CANCEL')"
          @click="onClose"
        />
        <Button
          type="submit"
          :label="$t('TASKS.MODAL.SAVE')"
          :disabled="!isValidForm || isSubmitting"
          :is-loading="isSubmitting"
        />
      </div>
    </form>
  </div>
</template>
