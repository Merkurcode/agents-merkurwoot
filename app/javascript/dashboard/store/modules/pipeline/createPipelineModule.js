import PipelineStatusesAPI from 'dashboard/api/pipeline_statuses';

/**
 * Factory that creates a namespaced Vuex pipeline module for any entity type.
 *
 * @param {object} options
 * @param {string} options.entityType - 'contact' | 'conversation'
 * @param {function} [options.fetchAllColumns] - () => Promise — returns columns with items embedded (backend-driven)
 * @param {function} [options.fetchColumnItems] - (columnId) => Promise — fetches items for a single column
 * @param {function} options.moveItem - (itemId, targetColumnId) => Promise
 */
export const createPipelineModule = ({ entityType, fetchAllColumns, fetchColumnItems, moveItem }) => {
  const state = {
    columns: [],
    uiFlags: {
      isFetchingColumns: false,
      isCreating: false,
      isUpdating: false,
      isDeleting: false,
    },
    columnLoadingIds: [],
  };

  const getters = {
    getColumns: $state => $state.columns,
    getUiFlags: $state => $state.uiFlags,
    isColumnLoading: $state => columnId => $state.columnLoadingIds.includes(columnId),
  };

  const mutations = {
    SET_COLUMNS($state, columns) {
      $state.columns = columns;
    },
    ADD_COLUMN($state, column) {
      $state.columns.push(column);
    },
    UPDATE_COLUMN($state, updated) {
      const index = $state.columns.findIndex(c => c.id === updated.id);
      if (index !== -1) $state.columns[index] = { ...$state.columns[index], ...updated };
    },
    DELETE_COLUMN($state, columnId) {
      $state.columns = $state.columns.filter(c => c.id !== columnId);
    },
    REORDER_COLUMNS($state, orderedIds) {
      const map = Object.fromEntries($state.columns.map(c => [c.id, c]));
      $state.columns = orderedIds.map(id => map[id]).filter(Boolean);
    },
    SET_COLUMN_ITEMS($state, { columnId, items }) {
      const col = $state.columns.find(c => c.id === columnId);
      if (col) col.items = items;
    },
    ADD_COLUMN_LOADING($state, columnId) {
      if (!$state.columnLoadingIds.includes(columnId)) $state.columnLoadingIds.push(columnId);
    },
    REMOVE_COLUMN_LOADING($state, columnId) {
      $state.columnLoadingIds = $state.columnLoadingIds.filter(id => id !== columnId);
    },
    MOVE_ITEM($state, { itemId, fromColumnId, toColumnId }) {
      const fromCol = $state.columns.find(c => c.id === fromColumnId);
      const toCol = $state.columns.find(c => c.id === toColumnId);
      if (!fromCol || !toCol) return;

      const item = fromCol.items.find(i => i.id === itemId);
      if (!item) return;

      fromCol.items = fromCol.items.filter(i => i.id !== itemId);
      toCol.items = [...toCol.items, item];
    },
    ROLLBACK_MOVE($state, { item, fromColumnId, toColumnId }) {
      const toCol = $state.columns.find(c => c.id === toColumnId);
      const fromCol = $state.columns.find(c => c.id === fromColumnId);
      if (toCol) toCol.items = toCol.items.filter(i => i.id !== item.id);
      if (fromCol) fromCol.items = [...fromCol.items, item];
    },
    SET_UI_FLAG($state, flags) {
      $state.uiFlags = { ...$state.uiFlags, ...flags };
    },
  };

  const actions = {
    fetchColumns: async ({ commit }, params = {}) => {
      commit('SET_UI_FLAG', { isFetchingColumns: true });
      try {
        if (fetchAllColumns) {
          const response = await fetchAllColumns(params);
          const columns = response.data.columns;
          commit('SET_COLUMNS', columns.map(c => ({ id: c.id, name: c.name, position: c.position, items: c.items || [], itemsLoaded: true })));
        } else {
          const response = await PipelineStatusesAPI.getByType(entityType);
          const columns = response.data.pipeline_statuses;
          commit('SET_COLUMNS', columns.map(s => ({ id: s.id, name: s.name, position: s.position, items: [], itemsLoaded: false })));
        }
      } finally {
        commit('SET_UI_FLAG', { isFetchingColumns: false });
      }
    },

    fetchColumnItems: async ({ commit }, columnId) => {
      commit('ADD_COLUMN_LOADING', columnId);
      try {
        const response = await fetchColumnItems(columnId);
        const items = response.data.payload || response.data;
        commit('SET_COLUMN_ITEMS', { columnId, items });
      } finally {
        commit('REMOVE_COLUMN_LOADING', columnId);
      }
    },

    createColumn: async ({ commit, dispatch }, name) => {
      commit('SET_UI_FLAG', { isCreating: true });
      try {
        const response = await PipelineStatusesAPI.create({ name, pipeline_type: entityType });
        commit('ADD_COLUMN', { id: response.data.id, name: response.data.name, items: [], itemsLoaded: false });
        dispatch('fetchColumnItems', response.data.id);
      } finally {
        commit('SET_UI_FLAG', { isCreating: false });
      }
    },

    updateColumn: async ({ commit }, { id, name }) => {
      commit('SET_UI_FLAG', { isUpdating: true });
      try {
        const response = await PipelineStatusesAPI.update(id, { name });
        commit('UPDATE_COLUMN', { id, name: response.data.name });
      } finally {
        commit('SET_UI_FLAG', { isUpdating: false });
      }
    },

    deleteColumn: async ({ commit }, columnId) => {
      commit('SET_UI_FLAG', { isDeleting: true });
      try {
        await PipelineStatusesAPI.delete(columnId);
        commit('DELETE_COLUMN', columnId);
      } finally {
        commit('SET_UI_FLAG', { isDeleting: false });
      }
    },

    reorderColumns: async ({ commit, state }, orderedIds) => {
      const previousIds = state.columns.map(c => c.id);
      commit('REORDER_COLUMNS', orderedIds);
      try {
        await PipelineStatusesAPI.reorder(orderedIds);
      } catch {
        commit('REORDER_COLUMNS', previousIds);
      }
    },

    moveItem: async ({ commit, state }, { itemId, fromColumnId, toColumnId }) => {
      if (fromColumnId === toColumnId) return;

      const fromCol = state.columns.find(c => c.id === fromColumnId);
      const originalItem = fromCol?.items.find(i => i.id === itemId);

      commit('MOVE_ITEM', { itemId, fromColumnId, toColumnId });

      try {
        await moveItem(itemId, toColumnId);
      } catch {
        if (originalItem) {
          commit('ROLLBACK_MOVE', { item: originalItem, fromColumnId, toColumnId });
        }
      }
    },
  };

  return { namespaced: true, state, getters, mutations, actions };
};
