<script setup>
import draggable from 'vuedraggable';
import ConversationCard from './ConversationCard.vue';
import { ref, nextTick, computed } from 'vue';
import { useStore } from 'vuex';
import Button from '../../../../components-next/button/Button.vue';

const props = defineProps({
  column: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['deleted']);
const store = useStore();

// =================== Initializing =================== //

const isEditing = ref(props.column.is_new);
const newName = ref(props.column.name);
const inputRef = ref(null);

const localConversations = computed({
  get: () => props.column.conversations || [],
  set: () => {
    // No necesitamos hacer nada aquí porque el drag & drop
    // se maneja en onDragEnd
  },
});

// =================== Events =================== //

const saveName = async () => {
  if (props.column.is_new && newName.value.trim() === '') {
    isEditing.value = false;
    emit('deleted', props.column);
    return;
  }

  if (newName.value.trim() === '' || newName.value === props.column.name) {
    isEditing.value = false;
    return;
  }

  if (props.column.id) {
    await store.dispatch('pipelineStatuses/update', {
      id: props.column.id,
      name: newName.value,
    });
  } else {
    await store.dispatch('pipelineStatuses/create', {
      id: props.column.id,
      name: newName.value,
    });
  }

  isEditing.value = false;
};

const deleteColumn = async () => {
  if (!props.column.id) {
    emit('deleted', props.column);
    return;
  }

  const confirmed = window.confirm('Estas seguro de eliminar la columna?');
  if (!confirmed) return;

  await store.dispatch('pipelineStatuses/delete', props.column.id);
  emit('deleted', props.column);
};

const startEditing = async () => {
  isEditing.value = true;
  newName.value = props.column.name;

  await nextTick();

  inputRef.value?.select();
};

const onDragEnd = async event => {
  const toColumnId = event.to.parentElement.dataset.columnId;
  const conversationId = event.item.dataset.conversationId;

  store.dispatch('togglePipelineStatus', {
    pipelineStatusId: toColumnId,
    conversationId: conversationId,
  });

  // console.log('Movimiento terminado:', event);
};
</script>

<template>
  <div class="flex flex-col flex-shrink-0 w-72" :data-column-id="column.id">
    <div
      class="flex items-center justify-between flex-shrink-0 h-10 px-2 bg-n-solid-2 outline outline-n-container outline-1 -outline-offset-1 rounded-xl pl-3"
    >
      <span
        v-if="!isEditing"
        class="block text-sm font-semibold capitalize"
        @click="startEditing"
      >
        {{ column.name }}
      </span>

      <input
        v-else
        ref="inputRef"
        v-model="newName"
        class="table text-sm font-semibold capitalize bg-transparent focus:outline-none"
        autoFocus
        @keyup.enter="saveName"
        @blur="saveName"
      />

      <Button slate icon="i-lucide-x" @click="deleteColumn" />
    </div>

    <draggable
      v-model="localConversations"
      group="tasks"
      item-key="id"
      @end="onDragEnd"
    >
      <template #item="{ element }">
        <ConversationCard
          :conversation="element"
          :data-conversation-id="element.id"
        />
      </template>
    </draggable>
  </div>
</template>
