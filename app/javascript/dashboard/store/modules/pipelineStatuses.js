import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import PipelineStatusesAPI from '../../api/pipeline_statuses';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getPipelineStatuses: $state => {
    return $state.records;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_PIPELINE_STATUS_FETCHING_STATUS, true);

    try {
      const response = await PipelineStatusesAPI.get();
      commit(types.SET_PIPELINE_STATUS_FETCHING_STATUS, false);
      commit(types.SET_PIPELINE_STATUSES, response.data);
    } catch (error) {
      commit(types.SET_PIPELINE_STATUS_FETCHING_STATUS, false);
    }
  },
};

export const mutations = {
  [types.SET_PIPELINE_STATUS_FETCHING_STATUS]($state, status) {
    $state.uiFlags.isFetching = status;
  },
  [types.SET_PIPELINE_STATUSES]: MutationHelpers.set,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
