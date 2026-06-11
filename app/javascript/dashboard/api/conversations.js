/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  getCopilotEvents(conversationId) {
    return axios.get(`${this.url}/${conversationId}/copilot_events`);
  }

  getAiUsage(conversationId) {
    return axios.get(`${this.url}/${conversationId}/ai_usage`);
  }
}

export default new ConversationApi();
