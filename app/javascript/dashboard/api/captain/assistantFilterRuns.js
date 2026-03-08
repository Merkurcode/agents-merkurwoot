/* global axios */
import ApiClient from '../ApiClient';

class CaptainAssistantFilterRuns extends ApiClient {
  constructor() {
    super('captain/assistant_filter_runs', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  show(id, params = {}) {
    return axios.get(`${this.url}/${id}`, { params });
  }

  create(params = {}) {
    return axios.post(this.url, { filter_run: params });
  }

  updateConversation(id, params = {}) {
    const base = this.url.replace(
      'assistant_filter_runs',
      'assistant_filter_run_conversations'
    );
    return axios.patch(`${base}/${id}`, params);
  }
}

export default new CaptainAssistantFilterRuns();
