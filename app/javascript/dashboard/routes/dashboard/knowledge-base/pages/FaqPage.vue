<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

import KnowledgeBaseLayout from 'dashboard/components-next/KnowledgeBase/KnowledgeBaseLayout.vue';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

// Sample data for empty state preview
const sampleCategories = [
  {
    id: 1,
    name: 'Envíos y Entregas',
    description: 'Preguntas sobre tiempos y costos de envío',
    faqs: [
      { id: 1, question: '¿Cuánto tiempo tarda en llegar mi pedido?' },
      { id: 2, question: '¿Cuál es el costo de envío?' },
    ],
  },
  {
    id: 2,
    name: 'Pagos y Facturación',
    description: 'Métodos de pago y facturas',
    faqs: [
      { id: 3, question: '¿Qué métodos de pago aceptan?' },
      { id: 4, question: '¿Cómo solicito mi factura?' },
    ],
  },
  {
    id: 3,
    name: 'Devoluciones',
    description: 'Políticas de devolución y cambios',
    faqs: [
      { id: 5, question: '¿Cómo puedo devolver un producto?' },
    ],
  },
];

const { t } = useI18n();
const store = useStore();

// UI State
const showCategoryForm = ref(false);
const showFaqForm = ref(false);
const showDeleteModal = ref(false);

const editingCategory = ref(null);
const editingFaq = ref(null);
const itemToDelete = ref(null);
const deleteType = ref(null);
const expandedCategories = ref(new Set());
const expandedFaqs = ref(new Set());
const activeLanguage = ref('es');

// Form data
const categoryForm = ref({ name: '', description: '', parent_id: null });
const faqForm = ref({
  faq_category_id: null,
  translations: {
    es: { question: '', answer: '' },
    en: { question: '', answer: '' },
  },
});

// Getters
const categories = computed(() => store.getters['faqCategories/getTree']);
const faqItems = computed(() => store.getters['faqItems/getFaqItems']);
const uiFlagsCategories = computed(() => store.getters['faqCategories/getUIFlags']);
const uiFlagsItems = computed(() => store.getters['faqItems/getUIFlags']);

const isLoading = computed(() => uiFlagsCategories.value.isFetchingTree);
const isSaving = computed(() =>
  uiFlagsCategories.value.isCreating ||
  uiFlagsCategories.value.isUpdating ||
  uiFlagsItems.value.isCreating ||
  uiFlagsItems.value.isUpdating
);
const isDeleting = computed(() =>
  uiFlagsCategories.value.isDeleting || uiFlagsItems.value.isDeleting
);

const isEmpty = computed(() => !isLoading.value && categories.value.length === 0);

// Flat list for dropdown
const flatCategories = computed(() => {
  const result = [];
  const flatten = (items, level = 0) => {
    items.forEach(item => {
      result.push({ ...item, level });
      if (item.children?.length) flatten(item.children, level + 1);
    });
  };
  flatten(categories.value);
  return result;
});

// Methods
const fetchData = async () => {
  await Promise.all([
    store.dispatch('faqCategories/get'),
    store.dispatch('faqCategories/getTree'),
    store.dispatch('faqItems/get'),
  ]);
};

const toggleExpand = (categoryId) => {
  if (expandedCategories.value.has(categoryId)) {
    expandedCategories.value.delete(categoryId);
  } else {
    expandedCategories.value.add(categoryId);
  }
};

const isExpanded = (categoryId) => expandedCategories.value.has(categoryId);

const toggleFaqExpand = (faqId) => {
  if (expandedFaqs.value.has(faqId)) {
    expandedFaqs.value.delete(faqId);
  } else {
    expandedFaqs.value.add(faqId);
  }
};

const isFaqExpanded = (faqId) => expandedFaqs.value.has(faqId);

const getFaqsForCategory = (categoryId) => {
  return faqItems.value.filter(faq => faq.faq_category_id === categoryId);
};

// Category actions
const openNewCategory = (parentId = null) => {
  editingCategory.value = null;
  categoryForm.value = { name: '', description: '', parent_id: parentId };
  showCategoryForm.value = true;
  showFaqForm.value = false;
};

const openEditCategory = (category) => {
  editingCategory.value = category;
  categoryForm.value = {
    name: category.name,
    description: category.description || '',
    parent_id: category.parent_id,
  };
  showCategoryForm.value = true;
  showFaqForm.value = false;
};

const saveCategory = async () => {
  try {
    if (editingCategory.value) {
      await store.dispatch('faqCategories/update', {
        id: editingCategory.value.id,
        ...categoryForm.value,
      });
      useAlert(t('KNOWLEDGE_BASE.FAQ.CATEGORIES.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('faqCategories/create', categoryForm.value);
      useAlert(t('KNOWLEDGE_BASE.FAQ.CATEGORIES.CREATE_SUCCESS'));
    }
    showCategoryForm.value = false;
    await fetchData();
  } catch (error) {
    useAlert(t('KNOWLEDGE_BASE.FAQ.CATEGORIES.ERROR'));
  }
};

// FAQ actions
const openNewFaq = (categoryId = null) => {
  editingFaq.value = null;
  faqForm.value = {
    faq_category_id: categoryId,
    translations: {
      es: { question: '', answer: '' },
      en: { question: '', answer: '' },
    },
  };
  activeLanguage.value = 'es';
  showFaqForm.value = true;
  showCategoryForm.value = false;
};

const openEditFaq = (faq) => {
  editingFaq.value = faq;
  faqForm.value = {
    faq_category_id: faq.faq_category_id,
    translations: faq.translations || {
      es: { question: '', answer: '' },
      en: { question: '', answer: '' },
    },
  };
  activeLanguage.value = 'es';
  showFaqForm.value = true;
  showCategoryForm.value = false;
};

const saveFaq = async () => {
  try {
    if (editingFaq.value) {
      await store.dispatch('faqItems/update', {
        id: editingFaq.value.id,
        ...faqForm.value,
      });
      useAlert(t('KNOWLEDGE_BASE.FAQ.ITEMS.UPDATE_SUCCESS'));
    } else {
      await store.dispatch('faqItems/create', faqForm.value);
      useAlert(t('KNOWLEDGE_BASE.FAQ.ITEMS.CREATE_SUCCESS'));
    }
    showFaqForm.value = false;
    await fetchData();
  } catch (error) {
    useAlert(t('KNOWLEDGE_BASE.FAQ.ITEMS.ERROR'));
  }
};

// Delete
const confirmDelete = (item, type) => {
  itemToDelete.value = item;
  deleteType.value = type;
  showDeleteModal.value = true;
};

const executeDelete = async () => {
  try {
    if (deleteType.value === 'category') {
      await store.dispatch('faqCategories/delete', itemToDelete.value.id);
      useAlert(t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DELETE_SUCCESS'));
    } else {
      await store.dispatch('faqItems/delete', itemToDelete.value.id);
      useAlert(t('KNOWLEDGE_BASE.FAQ.ITEMS.DELETE_SUCCESS'));
    }
    showDeleteModal.value = false;
    await fetchData();
  } catch (error) {
    useAlert(t('KNOWLEDGE_BASE.FAQ.CATEGORIES.ERROR'));
  }
};

const toggleFaqVisibility = async (faq) => {
  try {
    await store.dispatch('faqItems/toggleVisibility', faq.id);
    useAlert(faq.is_visible
      ? t('KNOWLEDGE_BASE.FAQ.VISIBILITY.HIDDEN')
      : t('KNOWLEDGE_BASE.FAQ.VISIBILITY.SHOWN')
    );
    await fetchData();
  } catch (error) {
    useAlert(t('KNOWLEDGE_BASE.FAQ.VISIBILITY.ERROR'));
  }
};

const moveFaq = async (faq, direction) => {
  try {
    await store.dispatch('faqItems/move', { itemId: faq.id, direction });
    useAlert(t('KNOWLEDGE_BASE.FAQ.ITEMS.MOVE_SUCCESS'));
    await fetchData();
  } catch (error) {
    useAlert(t('KNOWLEDGE_BASE.FAQ.ITEMS.MOVE_ERROR'));
  }
};

// Check if FAQ can move up (not first in its category)
const canMoveUp = (faq, categoryId) => {
  const faqs = getFaqsForCategory(categoryId);
  const index = faqs.findIndex(f => f.id === faq.id);
  return index > 0;
};

// Check if FAQ can move down (not last in its category)
const canMoveDown = (faq, categoryId) => {
  const faqs = getFaqsForCategory(categoryId);
  const index = faqs.findIndex(f => f.id === faq.id);
  return index < faqs.length - 1;
};

onMounted(fetchData);
</script>

<template>
  <div class="flex-1 overflow-auto bg-n-background">
    <KnowledgeBaseLayout
      :header-title="t('KNOWLEDGE_BASE.FAQ.HEADER_TITLE')"
      :button-label="t('KNOWLEDGE_BASE.FAQ.NEW_CATEGORY')"
      :show-button="!isLoading"
      @click="openNewCategory()"
      @close="showCategoryForm = false"
    >
      <!-- Category Form Dropdown (appears below New Category button) -->
      <template #action>
        <div
          v-if="showCategoryForm"
          class="w-96 z-50 absolute top-10 right-0 bg-n-alpha-3 backdrop-blur-[100px] p-6 rounded-xl border border-n-weak shadow-md flex flex-col gap-4"
        >
          <div class="flex items-start justify-between">
            <h3 class="text-base font-medium text-n-slate-12">
              {{ editingCategory ? t('KNOWLEDGE_BASE.FAQ.CATEGORIES.EDIT') : t('KNOWLEDGE_BASE.FAQ.CATEGORIES.NEW') }}
            </h3>
            <button class="text-n-slate-11 hover:text-n-slate-12" @click="showCategoryForm = false">
              <i class="i-lucide-x w-5 h-5" />
            </button>
          </div>
          <Input v-model="categoryForm.name" :label="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.NAME')" :placeholder="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.NAME_PLACEHOLDER')" />
          <Input v-model="categoryForm.description" :label="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DESCRIPTION')" :placeholder="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DESCRIPTION_PLACEHOLDER')" />
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-1">{{ t('KNOWLEDGE_BASE.FAQ.CATEGORIES.PARENT') }}</label>
            <select v-model="categoryForm.parent_id" class="w-full h-10 px-3 rounded-lg border border-n-weak bg-n-alpha-1 text-n-slate-12">
              <option :value="null">{{ t('KNOWLEDGE_BASE.FAQ.CATEGORIES.NO_PARENT') }}</option>
              <option v-for="cat in flatCategories.filter(c => c.level === 0 && c.id !== editingCategory?.id)" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
            </select>
          </div>
          <div class="flex gap-3">
            <Button variant="outline" :label="t('KNOWLEDGE_BASE.FAQ.CANCEL')" class="flex-1" @click="showCategoryForm = false" />
            <Button :label="t('KNOWLEDGE_BASE.FAQ.SAVE')" :is-loading="isSaving" :disabled="!categoryForm.name" class="flex-1" @click="saveCategory" />
          </div>
        </div>
      </template>

      <template #header-actions>
        <!-- New FAQ Button with Dropdown -->
        <div class="relative">
          <button
            class="h-8 px-3 bg-n-blue-9 text-white rounded-lg hover:bg-n-blue-10 transition-colors text-sm font-medium flex items-center gap-2"
            @click="openNewFaq()"
          >
            <i class="i-lucide-plus w-4 h-4" />
            {{ t('KNOWLEDGE_BASE.FAQ.NEW_FAQ') }}
          </button>
          <!-- FAQ Form Dropdown -->
          <div
            v-if="showFaqForm"
            class="w-[28rem] z-50 absolute top-10 right-0 bg-n-alpha-3 backdrop-blur-[100px] p-6 rounded-xl border border-n-weak shadow-md flex flex-col gap-4"
          >
            <div class="flex items-start justify-between">
              <h3 class="text-base font-medium text-n-slate-12">
                {{ editingFaq ? t('KNOWLEDGE_BASE.FAQ.ITEMS.EDIT') : t('KNOWLEDGE_BASE.FAQ.ITEMS.NEW') }}
              </h3>
              <button class="text-n-slate-11 hover:text-n-slate-12" @click="showFaqForm = false">
                <i class="i-lucide-x w-5 h-5" />
              </button>
            </div>
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-1">
                {{ t('KNOWLEDGE_BASE.FAQ.ITEMS.CATEGORY') }}
                <span class="text-n-ruby-11">*</span>
              </label>
              <select v-model="faqForm.faq_category_id" class="w-full h-10 px-3 rounded-lg border border-n-weak bg-n-alpha-1 text-n-slate-12" required>
                <option :value="null" disabled>{{ t('KNOWLEDGE_BASE.FAQ.ITEMS.SELECT_CATEGORY') }}</option>
                <option v-for="cat in flatCategories" :key="cat.id" :value="cat.id">{{ cat.level > 0 ? '— ' : '' }}{{ cat.name }}</option>
              </select>
            </div>
            <div class="flex gap-2 border-b border-n-weak">
              <button :class="['px-4 py-2 text-sm font-medium border-b-2 -mb-px', activeLanguage === 'es' ? 'border-n-blue-9 text-n-blue-11' : 'border-transparent text-n-slate-11']" @click="activeLanguage = 'es'">Español</button>
              <button :class="['px-4 py-2 text-sm font-medium border-b-2 -mb-px', activeLanguage === 'en' ? 'border-n-blue-9 text-n-blue-11' : 'border-transparent text-n-slate-11']" @click="activeLanguage = 'en'">English</button>
            </div>
            <Input v-model="faqForm.translations[activeLanguage].question" :label="t('KNOWLEDGE_BASE.FAQ.ITEMS.QUESTION')" :placeholder="t('KNOWLEDGE_BASE.FAQ.ITEMS.QUESTION_PLACEHOLDER')" />
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-1">{{ t('KNOWLEDGE_BASE.FAQ.ITEMS.ANSWER') }}</label>
              <textarea v-model="faqForm.translations[activeLanguage].answer" :placeholder="t('KNOWLEDGE_BASE.FAQ.ITEMS.ANSWER_PLACEHOLDER')" rows="4" class="w-full px-3 py-2 rounded-lg border border-n-weak bg-n-alpha-1 text-n-slate-12 resize-none" />
            </div>
            <div class="flex gap-3">
              <Button variant="outline" :label="t('KNOWLEDGE_BASE.FAQ.CANCEL')" class="flex-1" @click="showFaqForm = false" />
              <Button :label="t('KNOWLEDGE_BASE.FAQ.SAVE')" :is-loading="isSaving" :disabled="!faqForm.faq_category_id || (!faqForm.translations.es.question && !faqForm.translations.en.question)" class="flex-1" @click="saveFaq" />
            </div>
          </div>
        </div>
      </template>

      <!-- Loading -->
      <div v-if="isLoading" class="flex items-center justify-center py-10">
        <Spinner />
      </div>

      <!-- Empty State -->
      <EmptyStateLayout
        v-else-if="isEmpty"
        :title="t('KNOWLEDGE_BASE.FAQ.EMPTY_STATE.TITLE')"
        :subtitle="t('KNOWLEDGE_BASE.FAQ.EMPTY_STATE.SUBTITLE')"
      >
        <template #empty-state-item>
          <div class="flex flex-col gap-4 p-px opacity-50 pointer-events-none">
            <div
              v-for="category in sampleCategories"
              :key="category.id"
              class="relative bg-n-alpha-3 backdrop-blur-[100px] rounded-xl border border-n-weak overflow-hidden"
            >
              <!-- Category Header -->
              <div class="flex items-center justify-between p-4 border-b border-n-weak">
                <div class="flex items-center gap-3 flex-1 min-w-0">
                  <div class="p-1">
                    <i class="i-lucide-chevron-down w-4 h-4 text-n-slate-10" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="text-base font-medium text-n-slate-12 truncate">{{ category.name }}</div>
                    <div class="text-sm text-n-slate-10 truncate">{{ category.description }}</div>
                  </div>
                  <span class="text-xs text-n-slate-10 bg-n-alpha-2 px-2 py-1 rounded">
                    {{ category.faqs.length }} FAQs
                  </span>
                </div>
                <div class="flex items-center gap-2 ml-4">
                  <div class="p-2 text-n-slate-9 rounded-lg">
                    <i class="i-lucide-folder-plus w-4 h-4" />
                  </div>
                  <div class="p-2 text-n-slate-9 rounded-lg">
                    <i class="i-lucide-plus w-4 h-4" />
                  </div>
                  <div class="p-2 text-n-slate-9 rounded-lg">
                    <i class="i-lucide-pencil w-4 h-4" />
                  </div>
                </div>
              </div>
              <!-- FAQs -->
              <div class="bg-n-alpha-1 pl-10 py-2">
                <div
                  v-for="faq in category.faqs"
                  :key="faq.id"
                  class="flex items-center justify-between py-2 px-3"
                >
                  <div class="flex items-center gap-2 flex-1 min-w-0">
                    <i class="i-lucide-message-circle w-4 h-4 text-n-slate-10" />
                    <span class="text-sm text-n-slate-12 truncate">{{ faq.question }}</span>
                  </div>
                  <div class="flex items-center gap-1">
                    <div class="p-1.5 text-n-slate-9">
                      <i class="i-lucide-eye w-3.5 h-3.5" />
                    </div>
                    <div class="p-1.5 text-n-slate-9">
                      <i class="i-lucide-pencil w-3.5 h-3.5" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </template>
      </EmptyStateLayout>

      <!-- Categories List -->
      <div v-else class="flex flex-col gap-4">
        <template v-for="category in categories" :key="category.id">
          <CardLayout layout="col" class="!p-0">
            <!-- Category Header -->
            <div class="flex items-center justify-between p-4 border-b border-n-weak">
              <div class="flex items-center gap-3 flex-1 min-w-0">
                <button
                  class="p-1 hover:bg-n-alpha-2 rounded transition-colors"
                  :title="isExpanded(category.id) ? t('KNOWLEDGE_BASE.FAQ.CATEGORIES.COLLAPSE') : t('KNOWLEDGE_BASE.FAQ.CATEGORIES.EXPAND')"
                  @click="toggleExpand(category.id)"
                >
                  <i :class="['w-4 h-4', isExpanded(category.id) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right']" />
                </button>
                <div class="flex-1 min-w-0">
                  <h3 class="text-base font-medium text-n-slate-12 truncate">{{ category.name }}</h3>
                  <p v-if="category.description" class="text-sm text-n-slate-10 truncate">{{ category.description }}</p>
                </div>
                <span class="text-xs text-n-slate-10 bg-n-alpha-2 px-2 py-1 rounded">
                  {{ getFaqsForCategory(category.id).length }} FAQs
                </span>
              </div>
              <div class="flex items-center gap-2 ml-4">
                <Button variant="faded" size="sm" color="slate" icon="i-lucide-folder-plus" :title="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.ADD_SUBCATEGORY')" @click="openNewCategory(category.id)" />
                <Button variant="faded" size="sm" color="slate" icon="i-lucide-plus" :title="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.ADD_FAQ')" @click="openNewFaq(category.id)" />
                <Button variant="faded" size="sm" color="slate" icon="i-lucide-pencil" :title="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.EDIT_TOOLTIP')" @click="openEditCategory(category)" />
                <Button variant="faded" size="sm" color="ruby" icon="i-lucide-trash" :title="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DELETE_TOOLTIP')" @click="confirmDelete(category, 'category')" />
              </div>
            </div>

            <!-- Expanded Content -->
            <div v-if="isExpanded(category.id)" class="bg-n-alpha-1">
              <!-- Subcategories -->
              <template v-for="sub in category.children" :key="sub.id">
                <div class="border-b border-n-weak last:border-b-0">
                  <div class="flex items-center justify-between p-3 pl-10">
                    <div class="flex items-center gap-3 flex-1 min-w-0">
                      <button class="p-1 hover:bg-n-alpha-2 rounded" :title="isExpanded(sub.id) ? t('KNOWLEDGE_BASE.FAQ.CATEGORIES.COLLAPSE') : t('KNOWLEDGE_BASE.FAQ.CATEGORIES.EXPAND')" @click="toggleExpand(sub.id)">
                        <i :class="['w-4 h-4', isExpanded(sub.id) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right']" />
                      </button>
                      <span class="text-sm font-medium text-n-slate-12">{{ sub.name }}</span>
                      <span class="text-xs text-n-slate-10 bg-n-alpha-2 px-2 py-0.5 rounded">{{ getFaqsForCategory(sub.id).length }} FAQs</span>
                    </div>
                    <div class="flex items-center gap-2">
                      <Button variant="faded" size="xs" color="slate" icon="i-lucide-plus" :title="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.ADD_FAQ')" @click="openNewFaq(sub.id)" />
                      <Button variant="faded" size="xs" color="slate" icon="i-lucide-pencil" :title="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.EDIT_TOOLTIP')" @click="openEditCategory(sub)" />
                      <Button variant="faded" size="xs" color="ruby" icon="i-lucide-trash" :title="t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DELETE_TOOLTIP')" @click="confirmDelete(sub, 'category')" />
                    </div>
                  </div>
                  <!-- Sub FAQs -->
                  <div v-if="isExpanded(sub.id)" class="pl-16 pb-2">
                    <div v-for="faq in getFaqsForCategory(sub.id)" :key="faq.id" class="py-1 px-3">
                      <div class="flex items-center justify-between hover:bg-n-alpha-2 rounded py-1.5 px-2">
                        <div class="flex items-center gap-2 flex-1 min-w-0 cursor-pointer" @click="toggleFaqExpand(faq.id)">
                          <button class="p-0.5 hover:bg-n-alpha-3 rounded">
                            <i :class="['w-3.5 h-3.5 text-n-slate-10', isFaqExpanded(faq.id) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right']" />
                          </button>
                          <div class="flex-1 min-w-0">
                            <div class="flex items-center gap-2">
                              <span class="text-sm text-n-slate-12 truncate">{{ faq.primary_question }}</span>
                              <span v-if="!faq.is_visible" class="text-xs text-n-amber-11 bg-n-amber-3 px-1.5 py-0.5 rounded flex-shrink-0">{{ t('KNOWLEDGE_BASE.FAQ.ITEMS.HIDDEN') }}</span>
                            </div>
                            <div v-if="!isFaqExpanded(faq.id) && faq.primary_answer" class="marquee-container mt-0.5">
                              <span class="marquee-text text-xs text-n-slate-10">{{ faq.primary_answer }}</span>
                            </div>
                          </div>
                        </div>
                        <div class="flex items-center gap-1 flex-shrink-0">
                          <Button variant="faded" size="xs" color="slate" icon="i-lucide-chevron-up" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.MOVE_UP')" :disabled="!canMoveUp(faq, sub.id)" @click.stop="moveFaq(faq, 'up')" />
                          <Button variant="faded" size="xs" color="slate" icon="i-lucide-chevron-down" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.MOVE_DOWN')" :disabled="!canMoveDown(faq, sub.id)" @click.stop="moveFaq(faq, 'down')" />
                          <Button variant="faded" size="xs" color="slate" :icon="faq.is_visible ? 'i-lucide-eye-off' : 'i-lucide-eye'" :title="faq.is_visible ? t('KNOWLEDGE_BASE.FAQ.ITEMS.HIDE_TOOLTIP') : t('KNOWLEDGE_BASE.FAQ.ITEMS.SHOW_TOOLTIP')" @click.stop="toggleFaqVisibility(faq)" />
                          <Button variant="faded" size="xs" color="slate" icon="i-lucide-pencil" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.EDIT_TOOLTIP')" @click.stop="openEditFaq(faq)" />
                          <Button variant="faded" size="xs" color="ruby" icon="i-lucide-trash" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.DELETE_TOOLTIP')" @click.stop="confirmDelete(faq, 'faq')" />
                        </div>
                      </div>
                      <!-- Expanded FAQ Content -->
                      <div v-if="isFaqExpanded(faq.id)" class="ml-8 mt-2 p-3 bg-n-alpha-2 rounded-lg">
                        <p class="text-sm text-n-slate-11 whitespace-pre-wrap">{{ faq.primary_answer }}</p>
                      </div>
                    </div>
                    <div v-if="getFaqsForCategory(sub.id).length === 0" class="text-sm text-n-slate-10 py-2 px-3">{{ t('KNOWLEDGE_BASE.FAQ.ITEMS.EMPTY') }}</div>
                  </div>
                </div>
              </template>

              <!-- Category FAQs -->
              <div v-if="getFaqsForCategory(category.id).length > 0" class="pl-10 pb-2 pt-2">
                <div v-for="faq in getFaqsForCategory(category.id)" :key="faq.id" class="py-1 px-3">
                  <div class="flex items-center justify-between hover:bg-n-alpha-2 rounded py-1.5 px-2">
                    <div class="flex items-center gap-2 flex-1 min-w-0 cursor-pointer" @click="toggleFaqExpand(faq.id)">
                      <button class="p-0.5 hover:bg-n-alpha-3 rounded">
                        <i :class="['w-3.5 h-3.5 text-n-slate-10', isFaqExpanded(faq.id) ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right']" />
                      </button>
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2">
                          <span class="text-sm text-n-slate-12 truncate">{{ faq.primary_question }}</span>
                          <span v-if="!faq.is_visible" class="text-xs text-n-amber-11 bg-n-amber-3 px-1.5 py-0.5 rounded flex-shrink-0">{{ t('KNOWLEDGE_BASE.FAQ.ITEMS.HIDDEN') }}</span>
                        </div>
                        <div v-if="!isFaqExpanded(faq.id) && faq.primary_answer" class="marquee-container mt-0.5">
                          <span class="marquee-text text-xs text-n-slate-10">{{ faq.primary_answer }}</span>
                        </div>
                      </div>
                    </div>
                    <div class="flex items-center gap-1 flex-shrink-0">
                      <Button variant="faded" size="xs" color="slate" icon="i-lucide-chevron-up" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.MOVE_UP')" :disabled="!canMoveUp(faq, category.id)" @click.stop="moveFaq(faq, 'up')" />
                      <Button variant="faded" size="xs" color="slate" icon="i-lucide-chevron-down" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.MOVE_DOWN')" :disabled="!canMoveDown(faq, category.id)" @click.stop="moveFaq(faq, 'down')" />
                      <Button variant="faded" size="xs" color="slate" :icon="faq.is_visible ? 'i-lucide-eye-off' : 'i-lucide-eye'" :title="faq.is_visible ? t('KNOWLEDGE_BASE.FAQ.ITEMS.HIDE_TOOLTIP') : t('KNOWLEDGE_BASE.FAQ.ITEMS.SHOW_TOOLTIP')" @click.stop="toggleFaqVisibility(faq)" />
                      <Button variant="faded" size="xs" color="slate" icon="i-lucide-pencil" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.EDIT_TOOLTIP')" @click.stop="openEditFaq(faq)" />
                      <Button variant="faded" size="xs" color="ruby" icon="i-lucide-trash" :title="t('KNOWLEDGE_BASE.FAQ.ITEMS.DELETE_TOOLTIP')" @click.stop="confirmDelete(faq, 'faq')" />
                    </div>
                  </div>
                  <!-- Expanded FAQ Content -->
                  <div v-if="isFaqExpanded(faq.id)" class="ml-8 mt-2 p-3 bg-n-alpha-2 rounded-lg">
                    <p class="text-sm text-n-slate-11 whitespace-pre-wrap">{{ faq.primary_answer }}</p>
                  </div>
                </div>
              </div>

              <div v-if="getFaqsForCategory(category.id).length === 0 && (!category.children || category.children.length === 0)" class="text-sm text-n-slate-10 py-4 px-10">
                {{ t('KNOWLEDGE_BASE.FAQ.ITEMS.EMPTY') }}
              </div>
            </div>
          </CardLayout>
        </template>
      </div>
    </KnowledgeBaseLayout>

    <!-- Delete Modal (stays as centered modal) -->
    <div v-if="showDeleteModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="showDeleteModal = false">
      <div class="bg-n-solid-1 rounded-xl shadow-xl w-full max-w-md mx-4">
        <div class="flex items-center gap-3 px-6 py-4 border-b border-n-weak">
          <div class="p-2 rounded-full bg-n-ruby-3">
            <i class="i-lucide-trash-2 w-5 h-5 text-n-ruby-11" />
          </div>
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ deleteType === 'category' ? t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DELETE') : t('KNOWLEDGE_BASE.FAQ.ITEMS.DELETE') }}
          </h2>
        </div>
        <div class="px-6 py-4">
          <p class="text-sm text-n-slate-11 mb-3">
            {{ deleteType === 'category' ? t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DELETE_CONFIRM') : t('KNOWLEDGE_BASE.FAQ.ITEMS.DELETE_CONFIRM') }}
          </p>
          <div class="p-3 bg-n-alpha-2 rounded-lg">
            <p class="text-sm font-medium text-n-slate-12 truncate">
              {{ deleteType === 'category' ? itemToDelete?.name : itemToDelete?.primary_question }}
            </p>
          </div>
          <p v-if="deleteType === 'category'" class="mt-3 text-xs text-n-ruby-11">{{ t('KNOWLEDGE_BASE.FAQ.CATEGORIES.DELETE_WARNING') }}</p>
        </div>
        <div class="flex justify-end gap-2 px-6 py-4 border-t border-n-weak">
          <Button variant="faded" color="slate" :label="t('KNOWLEDGE_BASE.FAQ.CANCEL')" @click="showDeleteModal = false" />
          <Button color="ruby" :label="t('KNOWLEDGE_BASE.FAQ.DELETE')" :loading="isDeleting" @click="executeDelete" />
        </div>
      </div>
    </div>
  </div>
</template>

<style>
.marquee-container {
  overflow: hidden;
  position: relative;
  width: 100%;
  height: 1.25rem;
  line-height: 1.25rem;
}

.marquee-text {
  display: inline-block;
  white-space: nowrap;
  position: relative;
}

/* Only animate on hover when text overflows */
.marquee-container:hover .marquee-text {
  animation: marquee-scroll 8s linear infinite;
  animation-delay: 0.5s;
}

@keyframes marquee-scroll {
  0%, 15% {
    transform: translateX(0);
  }
  85%, 100% {
    transform: translateX(calc(-100% + 200px));
  }
}
</style>
